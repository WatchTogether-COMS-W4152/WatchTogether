
require "rails_helper"

RSpec.describe "Watchlist items", type: :request do
  let(:owner) { create_user(display_name: "Alice") }
  let(:outsider) { create_user(display_name: "Bob") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Movie night") }

  describe "GET index" do
    it "shows the group's watchlist" do
      item = group.watchlist_items.create!(title: "Titanic")
      sign_in(owner)

      get group_watchlist_items_path(group)

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component("watchlist_items/index")
      expect(page_props["watchlist_items"]).to eq([
        { "id" => item.id, "title" => "Titanic", "watched" => false }
      ])
    end

    it "does not allow outsiders to view the watchlist" do
      sign_in(outsider)

      get group_watchlist_items_path(group)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST create" do
    it "adds a movie to the watchlist" do
      sign_in(owner)

      expect {
        post group_watchlist_items_path(group), params: { title: "Barbie" }
      }.to change(WatchlistItem, :count).by(1)

      expect(WatchlistItem.last.title).to eq("Barbie")
      expect(response).to redirect_to(group_watchlist_items_path(group))
    end

    it "does not add a movie with an empty title" do
      sign_in(owner)

      expect {
        post group_watchlist_items_path(group), params: { title: "" }
      }.not_to change(WatchlistItem, :count)
    end
  end

  describe "PATCH update" do
    it "marks a movie as watched" do
      item = group.watchlist_items.create!(title: "Titanic")
      sign_in(owner)

      patch group_watchlist_item_path(group, item)

      expect(item.reload.watched).to be(true)
    end
  end

  describe "DELETE destroy" do
    it "removes a movie from the watchlist" do
      item = group.watchlist_items.create!(title: "Titanic")
      sign_in(owner)

      expect {
        delete group_watchlist_item_path(group, item)
      }.to change(WatchlistItem, :count).by(-1)
    end
  end
end
