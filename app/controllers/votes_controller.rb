class VotesController < InertiaController
  rate_limit to: 60, within: 1.minute, only: [ :update, :destroy ], by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many ratings. Try again in a minute.") }

  before_action :set_suggestion

  def update
    vote = save_vote(@suggestion, params.permit(:rating)[:rating].to_s)
    if vote.errors.any?
      redirect_to group_suggestions_path(@group), inertia: { errors: { rating: [ "Choose Love it, Maybe, or Not interested." ] } }, status: :see_other
    else
      redirect_to group_suggestions_path(@group), notice: "Rating saved.", status: :see_other
    end
  end

  def destroy
    Vote.where(suggestion: @suggestion, user: current_user).delete_all
    redirect_to group_suggestions_path(@group), notice: "Rating removed.", status: :see_other
  end

  private

  def set_suggestion
    @group = current_user.groups.find(params[:group_id])
    @suggestion = Suggestion.for_group(@group).find_by(id: params[:suggestion_id])
    render_error(404, "That suggestion could not be found.") unless @suggestion
  end

  def save_vote(suggestion, rating)
    attempts = 0
    begin
      vote = Vote.find_or_initialize_by(suggestion: suggestion, user: current_user)
      vote.rating = rating
      vote.save
      vote
    rescue ActiveRecord::RecordNotUnique
      # A concurrent first vote from the same viewer won the insert; update that row instead.
      retry if (attempts += 1) < 2
      raise
    end
  end
end
