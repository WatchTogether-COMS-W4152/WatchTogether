require "rails_helper"

RSpec.describe "Watchlist items", type: :request do
  let(:owner) { create_user(display_name: "Alice") }
  let(:member) { create_user(display_name: "Bob") }
  let(:outsider) { create_user(display_name: "Carol") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Movie night") }

  before { group.memberships.create!(user: member) }

  describe "GET index" do
    it "shows members only their group's items, newest first, without private group details" do
      older = group.watchlist_items.create!(title: "Titanic", watched: true, created_at: 1.minute.ago)
      newer = group.watchlist_items.create!(title: "Barbie")
      other_group = Group.create_with_owner!(owner: member, name: "Other films")
      other_group.watchlist_items.create!(title: "Private film")
      sign_in(member)

      get group_watchlist_items_path(group)

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component("watchlist_items/index")
      expect(page_props["group"]).to eq("id" => group.id, "name" => "Movie night")
      expect(page_props["watchlist_items"]).to eq([
        { "id" => newer.id, "title" => "Barbie", "watched" => false },
        { "id" => older.id, "title" => "Titanic", "watched" => true }
      ])
      expect(response.body).not_to include("Private film", owner.email, group.invite_code)
    end

    it "shows an empty watchlist to the owner of a new group" do
      sign_in(owner)

      get group_watchlist_items_path(group)

      expect(response).to have_http_status(:ok)
      expect(page_props["watchlist_items"]).to eq([])
    end
  end

  describe "POST create" do
    it "lets an owner add an unwatched title" do
      sign_in(owner)

      expect {
        post group_watchlist_items_path(group), params: { title: "Titanic" }
      }.to change(WatchlistItem, :count).by(1)

      expect(WatchlistItem.last).to have_attributes(group_id: group.id, title: "Titanic", watched: false)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(group_watchlist_items_path(group))
      follow_redirect!
      expect(page_props.dig("flash", "notice")).to eq("Added to watchlist!")
      expect(page_props["watchlist_items"].map { |item| item["title"] }).to eq([ "Titanic" ])
    end

    it "lets ordinary members add titles while ignoring forged group and watched attributes" do
      other_group = Group.create_with_owner!(owner: outsider, name: "Other films")
      sign_in(member)

      expect {
        post group_watchlist_items_path(group), params: {
          title: "Barbie", group_id: other_group.id, watched: true, id: 999
        }
      }.to change(WatchlistItem, :count).by(1)

      expect(WatchlistItem.last).to have_attributes(group_id: group.id, title: "Barbie", watched: false)
      expect(other_group.watchlist_items).to be_empty
      expect(response).to redirect_to(group_watchlist_items_path(group))
    end

    it "returns title-specific errors without creating items for missing, blank, or overlong titles" do
      sign_in(member)

      [ {}, { title: "" }, { title: "   " }, { title: "A" * 121 } ].each do |params|
        expect {
          post group_watchlist_items_path(group), params: params
        }.not_to change(WatchlistItem, :count)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(group_watchlist_items_path(group))
        follow_redirect!
        error = params[:title].to_s.length > 120 ? "is too long (maximum is 120 characters)" : "can't be blank"
        expect(page_props.dig("errors", "title")).to include(error)
        expect(page_props["watchlist_items"]).to eq([])
      end
    end
  end

  describe "PATCH update" do
    it "lets an ordinary member mark a shared title watched and then unwatched, persisting both changes" do
      item = group.watchlist_items.create!(title: "Titanic")
      sign_in(member)

      [ true, false ].each do |watched|
        patch group_watchlist_item_path(group, item)

        expect(item.reload.watched).to be(watched)
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(group_watchlist_items_path(group))
        follow_redirect!
        expect(page_props.dig("flash", "notice")).to eq("Watchlist updated!")
        expect(page_props["watchlist_items"].sole).to include("id" => item.id, "watched" => watched)
      end
    end

    it "lets owners toggle the selected item without renaming, moving, or changing other items" do
      item = group.watchlist_items.create!(title: "Titanic")
      untouched = group.watchlist_items.create!(title: "Barbie")
      other_group = Group.create_with_owner!(owner: owner, name: "Other films")
      sign_in(owner)

      patch group_watchlist_item_path(group, item), params: {
        title: "Changed", group_id: other_group.id, watched: false
      }

      expect(item.reload).to have_attributes(group_id: group.id, title: "Titanic", watched: true)
      expect(untouched.reload).to have_attributes(title: "Barbie", watched: false)
      expect(other_group.watchlist_items).to be_empty
    end
  end

  describe "DELETE destroy" do
    [ :owner, :member ].each do |viewer|
      it "lets the #{viewer} remove a shared title while retaining the group and other titles" do
        item = group.watchlist_items.create!(title: "Titanic")
        retained = group.watchlist_items.create!(title: "Barbie")
        sign_in(public_send(viewer))

        expect {
          delete group_watchlist_item_path(group, item)
        }.to change(WatchlistItem, :count).by(-1)

        expect(WatchlistItem.exists?(item.id)).to be(false)
        expect(retained.reload.title).to eq("Barbie")
        expect(Group.exists?(group.id)).to be(true)
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(group_watchlist_items_path(group))
        follow_redirect!
        expect(page_props.dig("flash", "notice")).to eq("Removed from watchlist!")
        expect(page_props["watchlist_items"].map { |entry| entry["id"] }).to eq([ retained.id ])
      end
    end
  end

  shared_examples "denied watchlist access" do |status|
    [ :get, :post, :patch, :delete ].each do |method|
      it "rejects #{method.to_s.upcase} without exposing or changing the watchlist" do
        item = group.watchlist_items.create!(title: "Private film")
        path = [ :get, :post ].include?(method) ? group_watchlist_items_path(group) : group_watchlist_item_path(group, item)
        before_items = WatchlistItem.order(:id).pluck(:id, :group_id, :title, :watched)

        public_send(method, path, params: { title: "Unwanted film" })

        expect(response).to have_http_status(status)
        expect(response).to redirect_to(sign_in_path) if status == :see_other
        expect(response.body).not_to include("Private film", group.name, group.invite_code)
        expect(WatchlistItem.order(:id).pluck(:id, :group_id, :title, :watched)).to eq(before_items)
      end
    end
  end

  context "when signed out" do
    include_examples "denied watchlist access", :see_other
  end

  context "when signed in as an outsider" do
    before { sign_in(outsider) }

    include_examples "denied watchlist access", :not_found
  end

  context "when membership is removed after signing in" do
    before do
      sign_in(member)
      group.memberships.find_by!(user: member).destroy!
    end

    include_examples "denied watchlist access", :not_found
  end

  [ :patch, :delete ].each do |method|
    it "scopes #{method.to_s.upcase} to this group and rejects missing item IDs" do
      item = group.watchlist_items.create!(title: "Titanic")
      other_group = Group.create_with_owner!(owner: member, name: "Other films")
      elsewhere = other_group.watchlist_items.create!(title: "Private film")
      sign_in(member)

      [ elsewhere.id, WatchlistItem.maximum(:id) + 1 ].each do |id|
        public_send(method, group_watchlist_item_path(group, id))

        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include("Private film")
        expect(item.reload).to have_attributes(title: "Titanic", watched: false)
        expect(elsewhere.reload).to have_attributes(group_id: other_group.id, title: "Private film", watched: false)
      end
    end
  end

  [ :post, :patch, :delete ].each do |method|
    it "enforces CSRF protection for #{method.to_s.upcase}" do
      item = group.watchlist_items.create!(title: "Titanic")
      sign_in(member)
      previous = ApplicationController.allow_forgery_protection
      ApplicationController.allow_forgery_protection = true
      path = method == :post ? group_watchlist_items_path(group) : group_watchlist_item_path(group, item)

      public_send(method, path, params: { title: "Unwanted film" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(group.watchlist_items.reload).to contain_exactly(item)
      expect(item.reload).to have_attributes(title: "Titanic", watched: false)
    ensure
      ApplicationController.allow_forgery_protection = previous
    end
  end

  it "deletes a group's watchlist with the group while preserving other groups and accounts" do
    item = group.watchlist_items.create!(title: "Titanic")
    group.watchlist_items.create!(title: "Barbie", watched: true)
    other_group = Group.create_with_owner!(owner: owner, name: "Other films")
    elsewhere = other_group.watchlist_items.create!(title: "Up")
    sign_in(owner)

    expect {
      delete group_path(group)
    }.to change(WatchlistItem, :count).by(-2)

    expect(response).to redirect_to(groups_path)
    expect(WatchlistItem.exists?(item.id)).to be(false)
    expect(WatchlistItem.where(group_id: group.id)).to be_empty
    expect(elsewhere.reload).to have_attributes(group_id: other_group.id, title: "Up", watched: false)
    expect(User.exists?(owner.id)).to be(true)
    expect(User.exists?(member.id)).to be(true)
  end
end
