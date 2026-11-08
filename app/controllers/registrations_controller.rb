class RegistrationsController < InertiaController
  skip_before_action :require_authentication
  rate_limit to: 10, within: 1.minute, only: :create, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many registration attempts. Please try again in a minute.") }

  def new
    return redirect_to groups_path if current_user

    render inertia: "auth/sign-up"
  end

  def create
    user = User.new(params.permit(:display_name, :email, :password, :password_confirmation))
    if user.save
      start_session(user)
      redirect_to groups_path, notice: "Welcome to WatchTogether!", status: :see_other
    else
      redirect_to sign_up_path, inertia: { errors: user.errors }, status: :see_other
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to sign_up_path, inertia: { errors: { email: [ "has already been taken" ] } }, status: :see_other
  end
end
