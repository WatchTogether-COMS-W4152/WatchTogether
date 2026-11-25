class ProfilesController < InertiaController
  def show
    render inertia: "profile/show", props: profile_props
  end

  def update
    if ActiveModel::Type::Boolean.new.cast(params[:streaming_services])
      current_user.replace_streaming_services!(params[:provider_ids])
      redirect_to profile_path, notice: "Streaming services updated.", status: :see_other
    elsif current_user.update(display_name: params.fetch(:display_name))
      redirect_to profile_path, notice: "Display name updated.", status: :see_other
    else
      redirect_to profile_path, inertia: { errors: current_user.errors }, status: :see_other
    end
  end

  private

  def profile_props
    selected = current_user.streaming_subscriptions.pluck(:provider_id)
    {
      services: StreamingService::CATALOG.map { |service| { id: service.fetch(:id), name: service.fetch(:name) } },
      selected_service_ids: StreamingService::CATALOG.filter_map { |service| service.fetch(:id) if selected.include?(service.fetch(:id)) }
    }
  end
end
