# Lets a member record, advance, or clear the last episode they watched of a show.
class EpisodeProgressesController < InertiaController
  ERROR_MESSAGES = {
    season: "Enter a season number of 1 or more.",
    episode: "Enter an episode number of 1 or more."
  }.freeze

  rate_limit to: 60, within: 1.minute, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many progress updates. Please try again in a minute.") }

  before_action :set_item

  # PUT with season and episode sets the position; PUT with next=1 advances one episode.
  def update
    attempts = 0
    begin
      progress = @item.episode_progresses.find_or_initialize_by(user: current_user)
      progress.assign_attributes(next_position(progress))
      saved = progress.save
    rescue ActiveRecord::RecordNotUnique
      # A concurrent first save from the same member won the insert; update that row instead.
      retry if (attempts += 1) < 2
      raise
    end

    if saved
      redirect_to group_watchlist_item_path(@group, @item),
        notice: "Saved. You've watched up to #{format_position(progress.position)}.", status: :see_other
    else
      redirect_to group_watchlist_item_path(@group, @item),
        inertia: { errors: friendly_errors(progress) }, status: :see_other
    end
  end

  def destroy
    @item.episode_progresses.where(user: current_user).delete_all

    redirect_to group_watchlist_item_path(@group, @item), notice: "Your progress was cleared.", status: :see_other
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

    { season: progress.season, episode: progress.episode + 1 }
  end

  def friendly_errors(progress)
    ERROR_MESSAGES.filter_map { |field, message| [ field, [ message ] ] if progress.errors[field].any? }.to_h
  end

  def format_position(position)
    "S#{position[:season]} E#{position[:episode]}"
  end
end
