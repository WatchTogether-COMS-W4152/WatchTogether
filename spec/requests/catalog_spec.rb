require "rails_helper"

RSpec.describe "Group movie catalog", type: :request do
  let(:owner) { create_user }
  let(:outsider) { create_user }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Films") }
  let(:client) { instance_double(TmdbClient) }
  let(:title) { { tmdb_id: 11, media_type: "movie", title: "Star Wars", overview: "A space adventure", release_year: 1977,
    tmdb_rating: 8.2, age_rating: "PG", poster_path: "/poster.jpg" } }

  before { allow(TmdbClient).to receive(:new).and_return(client) }

  it "returns authenticated search results and selected details with public poster URLs only" do
    sign_in(owner)
    allow(client).to receive(:search).with("Star").and_return([ title ])
    allow(client).to receive(:details).with("movie", "11").and_return(title)

    get group_catalog_search_path(group), params: { q: "Star" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["results"].sole).to include("title" => "Star Wars", "poster_url" => "https://image.tmdb.org/t/p/w342/poster.jpg")
    expect(response.parsed_body["results"].sole).not_to have_key("poster_path")
    expect(response.headers["Cache-Control"]).to include("no-store")

    get group_catalog_title_path(group, media_type: "movie", tmdb_id: 11)
    expect(response.parsed_body["title"]).to include("age_rating" => "PG")
  end

  it "requires sign-in and group membership before contacting TMDB" do
    expect(client).not_to receive(:search)
    expect(client).not_to receive(:details)
    get group_catalog_search_path(group), params: { q: "Star" }
    expect(response).to redirect_to(sign_in_path)
    sign_in(outsider)
    get group_catalog_search_path(group), params: { q: "Star" }
    expect(response).to have_http_status(:not_found)
    get group_catalog_title_path(group, media_type: "movie", tmdb_id: 11)
    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to eq("error" => "That group could not be found.")
  end

  it "returns useful errors without leaking upstream exceptions" do
    sign_in(owner)
    allow(client).to receive(:search).and_raise(TmdbClient::Unavailable, "secret upstream detail")
    get group_catalog_search_path(group), params: { q: "Star" }
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq("error" => TmdbClient::UNAVAILABLE_MESSAGE)
    allow(client).to receive(:details).and_raise(TmdbClient::InvalidSelection, "Choose a valid movie or TV show.")
    get group_catalog_title_path(group, media_type: "person", tmdb_id: 11)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "revokes catalog access immediately when a signed-in member is removed" do
    group.memberships.create!(user: outsider)
    sign_in(outsider)
    group.memberships.find_by!(user: outsider).destroy!
    expect(TmdbClient).not_to receive(:new)

    get group_catalog_search_path(group), params: { q: "Star" }
    expect(response).to have_http_status(:not_found)
    get group_catalog_title_path(group, media_type: "movie", tmdb_id: 11)
    expect(response).to have_http_status(:not_found)
  end

  it "limits searches per member" do
    sign_in(owner)
    allow(client).to receive(:search).and_return([])
    60.times { get group_catalog_search_path(group), params: { q: "Star" } }
    get group_catalog_search_path(group), params: { q: "Star" }
    expect(response).to have_http_status(:too_many_requests)
    expect(client).to have_received(:search).exactly(60).times
  end
end
