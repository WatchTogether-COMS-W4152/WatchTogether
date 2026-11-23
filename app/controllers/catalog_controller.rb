class CatalogController < ApplicationController
  before_action :set_group
  rate_limit to: 60, within: 1.minute, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render json: { error: "Too many searches. Please try again in a minute." }, status: :too_many_requests }

  rescue_from TmdbClient::InvalidSelection do |error|
    render json: { error: error.message }, status: :unprocessable_content
  end
  rescue_from TmdbClient::Unavailable do
    render json: { error: TmdbClient::UNAVAILABLE_MESSAGE }, status: :service_unavailable
  end
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "That group could not be found." }, status: :not_found
  end

  def search
    render json: { results: TmdbClient.new.search(params[:q]).map { |title| public_title(title) } }
  end

  def show
    render json: { title: public_title(TmdbClient.new.details(params[:media_type], params[:tmdb_id])) }
  end

  private

  def set_group
    @group = current_user.groups.find(params[:group_id])
  end

  def public_title(title)
    title.except(:poster_path).merge(poster_url: TmdbClient.poster_url(title[:poster_path]))
  end
end
