class SessionsController < InertiaController
  skip_before_action :require_authentication, only: [ :new, :create ]
  rate_limit to: 10, within: 1.minute, only: :create, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many sign-in attempts. Please try again in a minute.") }

  def new
    return redirect_to groups_path if current_user

    render inertia: "auth/sign-in"
  end

  def create
    credentials = params.permit(:email, :password)
    user = User.find_by(email: credentials[:email].to_s.strip.downcase)
    if user&.authenticate(credentials[:password].to_s)
      start_session(user)
      redirect_to groups_path, notice: "Welcome back!", status: :see_other
    else
      redirect_to sign_in_path, inertia: { errors: { email: [ "Email or password is incorrect." ] } }, status: :see_other
    end
  end

  def destroy
    end_session
    redirect_to sign_in_path, notice: "You have signed out.", status: :see_other, inertia: { clear_history: true }
  end
end
