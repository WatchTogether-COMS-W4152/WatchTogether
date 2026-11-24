class SuggestionsController < InertiaController
  include CatalogSelection

  rate_limit to: 30, within: 1.minute, only: :create, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many suggestions. Try again in a minute.") }

  before_action :set_group

  def index
    is_owner = @group.owner?(current_user)
    watchlist = @group.watchlist_items.pluck(:source_suggestion_id, :media_type, :tmdb_id)
    source_ids = watchlist.map(&:first).compact.to_set
    catalog_ids = watchlist.filter_map { |_, type, id| [ type, id ] if id }.to_set
    suggestions = Suggestion.ranked_for(@group, viewer: current_user).map do |suggestion|
      suggestion.as_json(only: [ :id, :title ]).merge(suggestion.catalog_json).merge(
        score: suggestion.score.to_i,
        votes_count: suggestion.votes_count.to_i,
        my_rating: suggestion.viewer_rating,
        suggested_by: suggestion.suggested_by&.display_name,
        can_remove: is_owner || suggestion.suggested_by_id == current_user.id,
        in_watchlist: source_ids.include?(suggestion.id) || catalog_ids.include?([ suggestion.media_type, suggestion.tmdb_id ])
      )
    end
    render inertia: "suggestions/index", props: {
      group: @group.as_json(only: [ :id, :name ]).merge(is_owner: is_owner),
      member_count: @group.memberships.count,
      suggestions: suggestions
    }
  end

  def create
    suggestion = Suggestion.new(**selected_title_attributes, group: @group, suggested_by: current_user)
    if suggestion.save
      redirect_to group_suggestions_path(@group), notice: "“#{suggestion.title}” was added.", status: :see_other
    else
      redirect_with_title_errors(suggestion.errors[:title])
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_with_title_errors([ "has already been suggested in this group" ])
  rescue TmdbClient::Error => error
    redirect_with_title_errors([ error.message ])
  end

  def watchlist
    suggestion = Suggestion.for_group(@group).find(params[:id])
    identity = suggestion.tmdb_id ? { tmdb_id: suggestion.tmdb_id, media_type: suggestion.media_type } : { source_suggestion_id: suggestion.id }
    @group.with_lock do
      unless @group.watchlist_items.exists?(identity)
        @group.watchlist_items.create!(suggestion.catalog_attributes.merge(source_suggestion: suggestion))
      end
    end
    redirect_to group_suggestions_path(@group), notice: "“#{suggestion.title}” is on your watchlist.", status: :see_other
  rescue ActiveRecord::RecordNotUnique
    redirect_to group_suggestions_path(@group), notice: "That title is already on your watchlist.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    # A direct watchlist addition may finish between our existence check and
    # model validation. Treat only that duplicate as a successful transfer.
    raise unless @group.watchlist_items.exists?(identity)

    redirect_to group_suggestions_path(@group), notice: "That title is already on your watchlist.", status: :see_other
  end

  def destroy
    suggestion = Suggestion.for_group(@group).find_by(id: params[:id])
    return render_error(404, "That suggestion could not be found.") unless suggestion

    unless suggestion.suggested_by_id == current_user.id || @group.owner?(current_user)
      return render_error(403, "Only the person who suggested a title or a group owner can remove it.")
    end

    suggestion.destroy!
    redirect_to group_suggestions_path(@group), notice: "“#{suggestion.title}” was removed.", status: :see_other
  end

  private

  def set_group
    @group = current_user.groups.find(params[:group_id])
  end

  def redirect_with_title_errors(messages)
    redirect_to group_suggestions_path(@group), inertia: { errors: { title: messages } }, status: :see_other
  end
end
