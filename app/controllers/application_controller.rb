class ApplicationController < ActionController::Base
  # The MVP runs one web process. Counters are shared by its request threads.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  protect_from_forgery with: :exception
  before_action :prevent_private_page_caching
  before_action :require_authentication
  before_action :extend_session

  rescue_from ActiveRecord::RecordNotFound do
    render_error(404, "That group could not be found.")
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    render_error(422, "This page has expired. Refresh the page and try again.")
  end

  private

  def current_session
    return @current_session if defined?(@current_session)

    @current_session = Session.authenticate(cookies.signed[:session_token])
  end

  def current_user
    current_session&.user
  end

  def require_authentication
    return if current_user

    message = cookies[:session_token].present? ? "Your session expired. Sign in again." : "Sign in to continue."
    cookies.delete(:session_token)
    session[:return_to] = request.fullpath if request.get? && request.format.html?
    redirect_to sign_in_path, alert: message, status: :see_other, inertia: { clear_history: true }
  end

  def extend_session
    return unless current_session && current_session.expires_at < (Session::LIFETIME / 2).from_now

    current_session.update!(expires_at: Session::LIFETIME.from_now)
    write_session_cookie(cookies.signed[:session_token])
  end

  def take_return_to
    path = session.delete(:return_to).to_s
    path.start_with?("/") && !path.start_with?("//") ? path : groups_path
  end

  def start_session(user)
    current_session&.destroy!
    reset_session
    @current_session, token = Session.issue!(user)
    write_session_cookie(token)
  end

  def write_session_cookie(token)
    cookies.signed[:session_token] = {
      value: token, expires: @current_session.expires_at,
      httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end

  def end_session
    current_session&.destroy!
    @current_session = nil
    reset_session
    cookies.delete(:session_token)
  end

  def prevent_private_page_caching
    response.headers["Cache-Control"] = "no-store"
  end

  def render_error(status, message)
    render inertia: "errors/show", props: { status: status, message: message }, status: status
  end
end
