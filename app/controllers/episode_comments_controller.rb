class EpisodeCommentsController < InertiaController
  rate_limit to: 30, within: 1.minute, only: :create, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many comments. Please try again in a minute.") }

  before_action :set_item

  def create
    comment = @item.episode_comments.new(comment_params.merge(user: current_user))

    if comment.save
      redirect_to item_path, notice: "Comment posted on #{EpisodeComment.label(comment.position)}.", status: :see_other
    else
      errors = comment.errors.to_hash.slice(:season, :episode, :body, :base)
      redirect_to item_path, inertia: { errors: errors }, status: :see_other
    end
  end

  def destroy
    comment = @item.episode_comments.find_by(id: params[:id])
    return render_error(404, "That comment could not be found.") unless comment

    unless comment.deletable_by?(current_user, group_owner: @group.owner?(current_user))
      return render_error(403, "Only the person who wrote a comment or a group owner can delete it.")
    end

    comment.destroy!
    redirect_to item_path, notice: "Comment deleted.", status: :see_other
  end

  private

  def set_item
    @group = current_user.groups.find(params[:group_id])
    @item = @group.watchlist_items.find(params[:watchlist_item_id])
  end

  def item_path
    group_watchlist_item_path(@group, @item)
  end

  def comment_params
    params.permit(:season, :episode, :body)
  end
end
