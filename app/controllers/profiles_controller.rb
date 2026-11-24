class ProfilesController < InertiaController
  def show
    render inertia: "profile/show"
  end

  def update
    if current_user.update(display_name: params.fetch(:display_name))
      redirect_to profile_path, notice: "Display name updated.", status: :see_other
    else
      redirect_to profile_path, inertia: { errors: current_user.errors }, status: :see_other
    end
  end
end
