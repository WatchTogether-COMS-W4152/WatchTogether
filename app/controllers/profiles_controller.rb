class ProfilesController < InertiaController
  def show
    render inertia: "profile/show"
  end

  def update
    if current_user.update(params.permit(:display_name))
      redirect_to profile_path, notice: "Your display name was updated.", status: :see_other
    else
      redirect_to profile_path, inertia: { errors: current_user.errors }, status: :see_other
    end
  end
end
