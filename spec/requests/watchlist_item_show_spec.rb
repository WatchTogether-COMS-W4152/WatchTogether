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
end
