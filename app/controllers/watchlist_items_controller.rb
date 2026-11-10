class WatchlistItemsController < InertiaController
  before_action :set_group

  def index
    watchlist_items = @group.watchlist_items.order(created_at: :desc)

    render inertia: "watchlist_items/index", props: {
      group: @group.as_json(only: [ :id, :name ]),
      watchlist_items: watchlist_items.as_json(only: [ :id, :title, :watched ])
    }
  end

  def create
    item = @group.watchlist_items.new(
      title: params.permit(:title)[:title].to_s
    )

    if item.save
      redirect_to group_watchlist_items_path(@group),
        notice: "Added to watchlist!",
        status: :see_other
    else
      redirect_to group_watchlist_items_path(@group),
        inertia: { errors: { title: item.errors[:title] } },
        status: :see_other
    end
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

  def set_group
    @group = current_user.groups.find(params[:group_id])
  end
end

