class EpisodeProgressesController < InertiaController
  ERROR_MESSAGES = {
    season: "Enter a season number from 1 to 9999.",
    episode: "Enter an episode number from 1 to 9999."
  }.freeze

  rate_limit to: 60, within: 1.minute, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many progress updates. Try again in a minute.") }

  before_action :set_item

  def update
    attempts = 0
    begin
      progress = @item.episode_progresses.find_or_initialize_by(user: current_user)
      position = next_position(progress)
      unless position
        return redirect_to group_watchlist_item_path(@group, @item),
          notice: "You've watched every episode.", status: :see_other
      end

      progress.assign_attributes(position)
      saved = progress.save
    rescue ActiveRecord::RecordNotUnique
      retry if (attempts += 1) < 2
      raise
    end

    if saved
      redirect_to group_watchlist_item_path(@group, @item),
        notice: "Watched up to #{format_position(progress.position)}.", status: :see_other
    else
      redirect_to group_watchlist_item_path(@group, @item),
        inertia: { errors: friendly_errors(progress) }, status: :see_other
    end
  end

  def destroy
    @item.episode_progresses.where(user: current_user).delete_all

    redirect_to group_watchlist_item_path(@group, @item), notice: "Progress cleared.", status: :see_other
  end

  private

  def set_item
    @group = current_user.groups.find(params[:group_id])
    @item = @group.watchlist_items.find(params[:watchlist_item_id])
    render_error(404, "Episode progress is only available for TV shows.") unless @item.episodic?
  end

  def next_position(progress)
    return { season: params[:season], episode: params[:episode] } unless params[:next].present?
    return GroupProgress::FIRST_EPISODE if progress.new_record?

    @item.position_after(progress.position)
  end

  def friendly_errors(progress)
    ERROR_MESSAGES.filter_map do |field, message|
      next unless progress.errors[field].any?

      [ field, [ progress.errors.where(field, :out_of_range).first&.message || message ] ]
    end.to_h
  end

  def format_position(position)
    "S#{position[:season]} E#{position[:episode]}"
  end
end
