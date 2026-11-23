class WatchlistItemsController < InertiaController
  include CatalogSelection
  include WatchlistItems::ProgressProps
  include WatchlistItems::DiscussionProps

  before_action :set_group
  rate_limit to: 30, within: 1.minute, only: :create, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many additions. Please try again in a minute.") }

  def index
    watchlist_items = @group.watchlist_items.order(created_at: :desc)

    render inertia: "watchlist_items/index", props: {
      group: @group.as_json(only: [ :id, :name ]),
      watchlist_items: watchlist_items.map { |item| item.as_json(only: [ :id, :title, :watched ]).merge(item.catalog_json) }
    }
  end

  def show
    item = @group.watchlist_items.find(params[:id])

    render inertia: "watchlist_items/show", props: {
      group: @group.as_json(only: [ :id, :name ]),
      item: item.as_json(only: [ :id, :title, :watched ]).merge(item.catalog_json, "episodic" => item.episodic?),
      **progress_props(item),
      **discussion_props(item)
    }
  end

  def create
    item = @group.watchlist_items.new(selected_title_attributes)

    if item.save
      redirect_to group_watchlist_items_path(@group),
        notice: "Added to watchlist!",
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

    item.update!(watched: !item.watched)

    redirect_to group_watchlist_items_path(@group),
      notice: "Watchlist updated!",
      status: :see_other
  end

  def destroy
    item = @group.watchlist_items.find(params[:id])

    item.destroy!

    redirect_to group_watchlist_items_path(@group),
      notice: "Removed from watchlist!",
      status: :see_other
  end

  private

  def redirect_with_title_errors(messages)
    redirect_to group_watchlist_items_path(@group),
      inertia: { errors: { title: messages } }, status: :see_other
  end

  def set_group
    @group = current_user.groups.find(params[:group_id])
  end
end
