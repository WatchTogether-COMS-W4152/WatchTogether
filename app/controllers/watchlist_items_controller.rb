class WatchlistItemsController < InertiaController
  include CatalogSelection
  include WatchlistItems::ProgressProps
  include WatchlistItems::DiscussionProps

  before_action :set_group
  rate_limit to: 30, within: 1.minute, only: :create, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many additions. Try again in a minute.") }

  def index
    watchlist_items = @group.watchlist_items.includes(:episode_progresses).order(created_at: :desc)
    members = @group.members.includes(:streaming_subscriptions).to_a
    client = TmdbClient.new
    filtering = params[:where] == "everyone"
    items = watchlist_items.map do |item|
      item.as_json(only: [ :id, :title, :watched ])
        .merge(item.catalog_json, "next_episode" => (item.next_group_episode(members: members) unless item.watched))
        .merge("watchability" => GroupWatchability.for(item, members: members, client: client))
    end
    items.select! { |item| item["watchability"]["included"] } if filtering

    render inertia: "watchlist_items/index", props: {
      group: @group.as_json(only: [ :id, :name ]),
      filtering: filtering,
      watchlist_items: items
    }
  end

  def show
    item = @group.watchlist_items.find(params[:id])

    render inertia: "watchlist_items/show", props: {
      group: @group.as_json(only: [ :id, :name ]),
      item: item.as_json(only: [ :id, :title, :watched ]).merge(item.catalog_json, "episodic" => item.episodic?),
      watch_providers: watch_provider_props(item),
      **progress_props(item),
      **discussion_props(item)
    }
  end

  def create
    item = @group.watchlist_items.new(selected_title_attributes)

    if item.save
      redirect_to group_watchlist_items_path(@group),
        notice: "Added to watchlist.",
        status: :see_other
    else
      redirect_with_title_errors(item.errors[:title])
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_with_title_errors([ "is already on this group's watchlist" ])
  rescue TmdbClient::Error => error
    redirect_with_title_errors([ error.message ])
  end

  def update
    item = @group.watchlist_items.find(params[:id])

    item.update!(watched: ActiveModel::Type::Boolean.new.cast(params.fetch(:watched)))

    redirect_to group_watchlist_items_path(@group),
      notice: "Watchlist updated.",
      status: :see_other
  end

  def destroy
    item = @group.watchlist_items.find(params[:id])

    item.destroy!

    redirect_to group_watchlist_items_path(@group),
      notice: "Removed from watchlist.",
      status: :see_other
  end

  private

    def watch_provider_props(item)
    return { status: "not_linked" } unless item.tmdb_id.present? && item.media_type.present?

    TmdbClient.new.watch_providers(item.media_type, item.tmdb_id).merge(status: "available")
  rescue TmdbClient::Error
    { status: "unavailable" }
  end

  def redirect_with_title_errors(messages)
    redirect_to group_watchlist_items_path(@group),
      inertia: { errors: { title: messages } }, status: :see_other
  end

  def set_group
    @group = current_user.groups.find(params[:group_id])
  end
end
