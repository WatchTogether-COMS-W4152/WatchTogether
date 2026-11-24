require "rails_helper"

RSpec.describe "Watchlist item page", type: :request do
  let(:owner) { create_user(display_name: "Alice") }
  let(:outsider) { create_user(display_name: "Carol") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Roommates") }
  let(:show) { group.watchlist_items.create!(title: "Severance") }

  it "shows a member the title and whether it has episodes" do
    sign_in(owner)

    get group_watchlist_item_path(group, show)

    expect(response).to have_http_status(:ok)
    expect(inertia).to render_component("watchlist_items/show")
    expect(page_props["group"]).to eq("id" => group.id, "name" => "Roommates")
    expect(page_props["item"]).to include("id" => show.id, "title" => "Severance", "episodic" => true)
  end

  it "hides the page from people outside the group" do
    sign_in(outsider)

    get group_watchlist_item_path(group, show)

    expect(response).to have_http_status(:not_found)
  end

  it "does not find another group's item through this group" do
    other = Group.create_with_owner!(owner: owner, name: "Other")
    other_item = other.watchlist_items.create!(title: "Private")
    sign_in(owner)

    get group_watchlist_item_path(group, other_item)

    expect(response).to have_http_status(:not_found)
  end

    describe "streaming availability" do
      let(:catalog_item) do
        group.watchlist_items.create!(
          title: "Fight Club",
          tmdb_id: 550,
          media_type: "movie"
        )
      end

    let(:client) { instance_double(TmdbClient) }

    let(:providers) do
      {
        region: "US",
        streaming: [ "Netflix" ],
        rent: [ "Amazon Video" ],
        buy: [ "Apple TV Store" ],
        free: [],
        ads: []
      }
    end

    it "includes watch providers for a catalog-linked title" do
      sign_in(owner)

      allow(TmdbClient).to receive(:new).and_return(client)
      expect(client).to receive(:watch_providers).with("movie", 550).and_return(providers)

      get group_watchlist_item_path(group, catalog_item)

      expect(response).to have_http_status(:ok)
      expect(page_props["watch_providers"]).to eq(
        providers.stringify_keys.merge("status" => "available")
      )
    end

    it "supports titles with no listed US providers" do
      sign_in(owner)

      empty_providers = {
        region: "US",
        streaming: [],
        rent: [],
        buy: [],
        free: [],
        ads: []
      }

      allow(TmdbClient).to receive(:new).and_return(client)
      allow(client).to receive(:watch_providers).with("movie", 550).and_return(empty_providers)

      get group_watchlist_item_path(group, catalog_item)

      expect(response).to have_http_status(:ok)
      expect(page_props["watch_providers"]).to eq(
        empty_providers.stringify_keys.merge("status" => "available")
      )
    end

    it "does not contact TMDB for manually added titles" do
      sign_in(owner)

      expect(TmdbClient).not_to receive(:new)

      get group_watchlist_item_path(group, show)

      expect(response).to have_http_status(:ok)
      expect(page_props["watch_providers"]).to eq("status" => "not_linked")
    end

    it "keeps the item page accessible when TMDB is unavailable" do
      sign_in(owner)

      allow(TmdbClient).to receive(:new).and_return(client)
      allow(client).to receive(:watch_providers).with("movie", 550).and_raise(TmdbClient::Unavailable)

      get group_watchlist_item_path(group, catalog_item)

      expect(response).to have_http_status(:ok)
      expect(page_props["watch_providers"]).to eq("status" => "unavailable")
      expect(page_props["item"]).to include("title" => "Fight Club")
    end

    it "does not fetch providers for unauthorized users" do
      sign_in(outsider)

      expect(TmdbClient).not_to receive(:new)

      get group_watchlist_item_path(group, catalog_item)

      expect(response).to have_http_status(:not_found)
    end
  end
end
