require "rails_helper"

RSpec.describe "Catalog voting and watchlist integration", type: :request do
  let(:owner) { create_user }
  let(:member) { create_user }
  let(:outsider) { create_user }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Films") }
  let(:client) { instance_double(TmdbClient) }
  let(:title) { { tmdb_id: 11, media_type: "movie", title: "Star Wars", overview: "A space adventure", release_year: 1977,
    tmdb_rating: 8.2, age_rating: "PG", poster_path: "/poster.jpg" } }

  before do
    group.memberships.create!(user: member)
    allow(TmdbClient).to receive(:new).and_return(client)
  end

  [ :suggestions, :watchlist_items ].each do |destination|
    it "saves canonical TMDB metadata to #{destination}, ignoring browser-supplied metadata" do
      sign_in(member)
      allow(client).to receive(:details).with("movie", "11").and_return(title)
      path = public_send("group_#{destination}_path", group)
      post path, params: { title: "Forged", tmdb_id: 11, media_type: "movie", overview: "Forged", age_rating: "G", watched: true }
      expect(response).to redirect_to(path)
      record = destination == :suggestions ? Suggestion.last : WatchlistItem.last
      expect(record).to have_attributes(**title, group_id: group.id)
      follow_redirect!
      expect(page_props[destination.to_s].sole).to include("overview" => "A space adventure", "age_rating" => "PG",
        "poster_url" => "https://image.tmdb.org/t/p/w342/poster.jpg")
    end

    it "keeps #{destination} unchanged on lookup failure and reports it at the title field" do
      sign_in(member)
      allow(client).to receive(:details).and_raise(TmdbClient::Unavailable, TmdbClient::UNAVAILABLE_MESSAGE)
      path = public_send("group_#{destination}_path", group)
      post path, params: { title: "Forged", tmdb_id: 11, media_type: "movie" }
      expect(Suggestion.count + WatchlistItem.count).to eq(0)
      follow_redirect!
      expect(page_props.dig("errors", "title")).to include(TmdbClient::UNAVAILABLE_MESSAGE)
    end

    it "rejects unauthorized catalog additions to #{destination} before consuming upstream quota" do
      path = public_send("group_#{destination}_path", group)
      selection = { tmdb_id: 11, media_type: "movie" }
      expect(TmdbClient).not_to receive(:new)

      post path, params: selection
      expect(response).to redirect_to(sign_in_path)
      sign_in(outsider)
      post path, params: selection
      expect(response).to have_http_status(:not_found)
      sign_in(member)
      group.memberships.find_by!(user: member).destroy!
      post path, params: selection
      expect(response).to have_http_status(:not_found)
      expect(Suggestion.count + WatchlistItem.count).to eq(0)
    end
  end

  it "reports duplicate catalog watchlist titles, including database races" do
    sign_in(member)
    allow(client).to receive(:details).and_return(title)
    2.times { post group_watchlist_items_path(group), params: { tmdb_id: 11, media_type: "movie" } }
    expect(WatchlistItem.count).to eq(1)
    follow_redirect!
    expect(page_props.dig("errors", "title")).to include("is already on this group's watchlist")
    allow_any_instance_of(WatchlistItem).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
    post group_watchlist_items_path(group), params: { title: "A title" }
    follow_redirect!
    expect(page_props.dig("errors", "title")).to include("is already on this group's watchlist")
  end

  it "copies a member's suggestion to watchlist once, preserving ratings and stored metadata without a lookup" do
    suggestion = Suggestion.create!(title.merge(group: group, suggested_by: owner))
    vote = Vote.create!(suggestion: suggestion, user: member, rating: "love")
    sign_in(member)
    expect(client).not_to receive(:details)
    2.times { post watchlist_group_suggestion_path(group, suggestion) }
    expect(response).to redirect_to(group_suggestions_path(group))
    expect(WatchlistItem.count).to eq(1)
    expect(WatchlistItem.last).to have_attributes(**title, watched: false, source_suggestion_id: suggestion.id)
    expect(vote.reload.rating).to eq("love")
    follow_redirect!
    expect(page_props["suggestions"].sole["in_watchlist"]).to be(true)
    delete group_watchlist_item_path(group, WatchlistItem.last)
    get group_suggestions_path(group)
    expect(page_props["suggestions"].sole["in_watchlist"]).to be(false)
  end

  it "recognizes catalog titles already independently added to the watchlist" do
    suggestion = Suggestion.create!(title.merge(group: group))
    item = WatchlistItem.create!(title.merge(group: group, watched: true))
    sign_in(member)
    post watchlist_group_suggestion_path(group, suggestion)
    expect(WatchlistItem.count).to eq(1)
    expect(item.reload.watched).to be(true)
    follow_redirect!
    expect(page_props["suggestions"].sole["in_watchlist"]).to be(true)
  end

  it "copies manual suggestions idempotently and preserves the watchlist after suggestion removal" do
    suggestion = Suggestion.create!(group: group, suggested_by: member, title: "Local movie")
    sign_in(member)
    2.times { post watchlist_group_suggestion_path(group, suggestion) }
    expect(WatchlistItem.count).to eq(1)
    get group_suggestions_path(group)
    expect(page_props["suggestions"].sole["in_watchlist"]).to be(true)
    delete group_suggestion_path(group, suggestion)
    expect(WatchlistItem.last).to have_attributes(title: "Local movie", source_suggestion_id: nil)
  end

  it "treats a direct addition that wins the validation race as a successful transfer" do
    suggestion = Suggestion.create!(title.merge(group: group))
    existing = WatchlistItem.create!(title.merge(group: group, watched: true))
    sign_in(member)
    # Simulate the transfer's earlier read missing a just-committed direct add.
    allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:exists?).and_call_original
    allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:exists?)
      .with(tmdb_id: 11, media_type: "movie").and_return(false, true)

    post watchlist_group_suggestion_path(group, suggestion)

    expect(response).to redirect_to(group_suggestions_path(group))
    expect(WatchlistItem.count).to eq(1)
    expect(existing.reload.watched).to be(true)
    follow_redirect!
    expect(page_props["suggestions"].sole["in_watchlist"]).to be(true)
  end

  it "handles an insert-time uniqueness conflict without changing an existing watchlist item or votes" do
    suggestion = Suggestion.create!(title.merge(group: group))
    existing = WatchlistItem.create!(title.merge(group: group, watched: true))
    vote = Vote.create!(suggestion: suggestion, user: member, rating: "love")
    sign_in(member)
    # Both the earlier read and model validation precede the competing commit.
    # Leave the real unique database index as the final concurrency safeguard.
    allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:exists?).and_call_original
    allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:exists?)
      .with(tmdb_id: 11, media_type: "movie").and_return(false)
    allow_any_instance_of(WatchlistItem).to receive(:valid?).and_return(true)

    post watchlist_group_suggestion_path(group, suggestion)

    expect(response).to redirect_to(group_suggestions_path(group))
    expect(WatchlistItem.count).to eq(1)
    expect(existing.reload.watched).to be(true)
    expect(vote.reload.rating).to eq("love")
    follow_redirect!
    expect(page_props["suggestions"].sole["in_watchlist"]).to be(true)
  end

  it "does not report a successful transfer when validation fails for a reason other than a duplicate" do
    suggestion = Suggestion.create!(group: group, title: "Local screening")
    sign_in(member)
    # Simulate legacy invalid data; no duplicate exists to justify success.
    suggestion.update_columns(title: "")

    post watchlist_group_suggestion_path(group, suggestion)

    expect(response).to have_http_status(:unprocessable_content)
    expect(WatchlistItem.count).to eq(0)
  end

  it "restricts transfers to current members and the selected group's suggestions" do
    suggestion = Suggestion.create!(group: group, title: "Local movie")
    path = watchlist_group_suggestion_path(group, suggestion)
    post path
    expect(response).to redirect_to(sign_in_path)
    sign_in(outsider)
    post path
    expect(response).to have_http_status(:not_found)
    sign_in(member)
    other_group = Group.create_with_owner!(owner: member, name: "Other films")
    post watchlist_group_suggestion_path(other_group, suggestion)
    expect(response).to have_http_status(:not_found)
    group.memberships.find_by!(user: member).destroy!
    post path
    expect(response).to have_http_status(:not_found)
    expect(WatchlistItem.count).to eq(0)
  end

  it "enforces CSRF protection for transfers" do
    suggestion = Suggestion.create!(group: group, title: "Local movie")
    sign_in(member)
    previous = ApplicationController.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true
    post watchlist_group_suggestion_path(group, suggestion)
    expect(response).to have_http_status(:unprocessable_content)
    expect(WatchlistItem.count).to eq(0)
  ensure
    ApplicationController.allow_forgery_protection = previous
  end
end
