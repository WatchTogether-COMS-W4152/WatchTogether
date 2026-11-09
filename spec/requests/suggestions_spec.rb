require "rails_helper"

RSpec.describe "Group suggestions", type: :request do
  let(:owner) { create_user(display_name: "Alice") }
  let(:member) { create_user(display_name: "Bob") }
  let(:outsider) { create_user(display_name: "Carol") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Friday films") }

  before { group.memberships.create!(user: member) }

  def suggest(title, by: owner)
    Suggestion.create!(group: group, suggested_by: by, title: title)
  end

  describe "GET index" do
    it "shows members the ranked list with their own rating and totals only" do
      heat = suggest("Heat")
      up = suggest("Up", by: member)
      Vote.create!(suggestion: heat, user: owner, rating: "love")
      Vote.create!(suggestion: heat, user: member, rating: "not_interested")
      Vote.create!(suggestion: up, user: owner, rating: "maybe")
      sign_in(member)

      get group_suggestions_path(group)

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component("suggestions/index")
      expect(page_props["group"]).to eq("id" => group.id, "name" => "Friday films", "is_owner" => false)
      expect(page_props["member_count"]).to eq(2)
      expect(page_props["suggestions"]).to eq([
        { "id" => up.id, "title" => "Up", "score" => 1, "votes_count" => 1, "my_rating" => nil,
          "suggested_by" => "Bob", "can_remove" => true },
        { "id" => heat.id, "title" => "Heat", "score" => 0, "votes_count" => 2, "my_rating" => "not_interested",
          "suggested_by" => "Alice", "can_remove" => false }
      ])
      expect(response.body).not_to include(owner.email, member.password_digest, group.invite_code)
    end

    it "lets owners remove any suggestion and shows suggestions whose suggester was deleted" do
      suggest("Up", by: member)
      suggest("Heat", by: nil)
      sign_in(owner)

      get group_suggestions_path(group)

      expect(page_props.dig("group", "is_owner")).to be(true)
      expect(page_props["suggestions"].map { |item| [ item["title"], item["suggested_by"], item["can_remove"] ] })
        .to eq([ [ "Up", "Bob", true ], [ "Heat", nil, true ] ])
    end

    it "shows an empty list for a new group" do
      sign_in(owner)
      get group_suggestions_path(group)

      expect(page_props["suggestions"]).to eq([])
    end

    it "hides the group from outsiders and requires sign-in" do
      suggest("Heat")
      get group_suggestions_path(group)
      expect(response).to redirect_to(sign_in_path)

      sign_in(outsider)
      get group_suggestions_path(group)
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Heat", group.name)
    end
  end

  describe "POST create" do
    it "adds a normalized suggestion for the current member, ignoring forged attributes" do
      other_group = Group.create_with_owner!(owner: outsider, name: "Other films")
      sign_in(member)

      expect {
        post group_suggestions_path(group), params: {
          title: "  Spirited   Away ", group_id: other_group.id, suggested_by_id: owner.id, title_key: "x"
        }
      }.to change(Suggestion, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(group_suggestions_path(group))
      suggestion = Suggestion.last
      expect(suggestion).to have_attributes(group_id: group.id, suggested_by_id: member.id,
        title: "Spirited Away", title_key: "spirited away")
      follow_redirect!
      expect(page_props.dig("flash", "notice")).to eq("“Spirited Away” was added. Rate it below.")
    end

    it "returns field errors for blank, too long, and duplicate titles" do
      suggest("Spirited Away")
      sign_in(member)

      [ "   ", "x" * 121, "spirited AWAY" ].each do |title|
        expect {
          post group_suggestions_path(group), params: { title: title }
        }.not_to change(Suggestion, :count)
        expect(response).to redirect_to(group_suggestions_path(group))
        follow_redirect!
        expect(page_props.dig("errors", "title")).to be_present
      end
      post group_suggestions_path(group)
      follow_redirect!
      expect(page_props.dig("errors", "title")).to include("can't be blank")
    end

    it "reports a duplicate created concurrently as a title error" do
      sign_in(member)
      allow_any_instance_of(Suggestion).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      post group_suggestions_path(group), params: { title: "Heat" }

      expect(response).to redirect_to(group_suggestions_path(group))
      follow_redirect!
      expect(page_props.dig("errors", "title")).to eq([ "has already been suggested in this group" ])
    end

    it "does not let outsiders or signed-out visitors suggest titles" do
      post group_suggestions_path(group), params: { title: "Heat" }
      expect(response).to redirect_to(sign_in_path)

      sign_in(outsider)
      post group_suggestions_path(group), params: { title: "Heat" }
      expect(response).to have_http_status(:not_found)
      expect(Suggestion.count).to eq(0)
    end

    it "limits how quickly one member can add suggestions" do
      sign_in(member)
      30.times { |index| post group_suggestions_path(group), params: { title: "Film #{index}" } }

      post group_suggestions_path(group), params: { title: "One too many" }

      expect(response).to have_http_status(:too_many_requests)
      expect(page_props["message"]).to eq("Too many suggestions. Please try again in a minute.")
      expect(Suggestion.for_group(group).count).to eq(30)
    end

    it "enforces CSRF protection" do
      sign_in(member)
      previous = ApplicationController.allow_forgery_protection
      ApplicationController.allow_forgery_protection = true

      post group_suggestions_path(group), params: { title: "Heat" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Suggestion.count).to eq(0)
    ensure
      ApplicationController.allow_forgery_protection = previous
    end
  end

  describe "DELETE destroy" do
    it "lets the suggester remove their title along with everyone's ratings" do
      suggestion = suggest("Heat", by: member)
      Vote.create!(suggestion: suggestion, user: owner, rating: "love")
      sign_in(member)

      expect {
        delete group_suggestion_path(group, suggestion)
      }.to change(Suggestion, :count).by(-1).and change(Vote, :count).by(-1)

      expect(response).to redirect_to(group_suggestions_path(group))
      follow_redirect!
      expect(page_props.dig("flash", "notice")).to eq("“Heat” was removed.")
    end

    it "lets any owner remove another member's suggestion" do
      suggestion = suggest("Heat", by: member)
      sign_in(owner)

      delete group_suggestion_path(group, suggestion)

      expect(response).to redirect_to(group_suggestions_path(group))
      expect(Suggestion.exists?(suggestion.id)).to be(false)
    end

    it "forbids ordinary members from removing someone else's suggestion" do
      suggestion = suggest("Heat")
      sign_in(member)

      delete group_suggestion_path(group, suggestion)

      expect(response).to have_http_status(:forbidden)
      expect(page_props["message"]).to eq("Only the person who suggested a title or a group owner can remove it.")
      expect(Suggestion.exists?(suggestion.id)).to be(true)
    end

    it "only removes suggestions from the selected group" do
      other_group = Group.create_with_owner!(owner: owner, name: "Other films")
      elsewhere = Suggestion.create!(group: other_group, suggested_by: owner, title: "Heat")
      sign_in(owner)

      [ elsewhere.id, Suggestion.maximum(:id) + 1 ].each do |id|
        delete group_suggestion_path(group, id)
        expect(response).to have_http_status(:not_found)
        expect(page_props["message"]).to eq("That suggestion could not be found.")
      end
      expect(Suggestion.exists?(elsewhere.id)).to be(true)
    end

    it "does not let outsiders or signed-out visitors remove suggestions" do
      suggestion = suggest("Heat")
      delete group_suggestion_path(group, suggestion)
      expect(response).to redirect_to(sign_in_path)

      sign_in(outsider)
      delete group_suggestion_path(group, suggestion)
      expect(response).to have_http_status(:not_found)
      expect(Suggestion.exists?(suggestion.id)).to be(true)
    end
  end
end
