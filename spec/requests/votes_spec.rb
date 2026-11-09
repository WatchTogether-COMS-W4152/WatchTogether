require "rails_helper"

RSpec.describe "Rating suggestions", type: :request do
  let(:owner) { create_user(display_name: "Alice") }
  let(:member) { create_user(display_name: "Bob") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Friday films") }
  let(:suggestion) { Suggestion.create!(group: group, suggested_by: owner, title: "Heat") }

  before { group.memberships.create!(user: member) }

  def my_votes
    Vote.where(suggestion: suggestion, user: member)
  end

  it "records a rating and lets the member change it without creating another" do
    sign_in(member)

    expect {
      put group_suggestion_vote_path(group, suggestion), params: { rating: "love" }
    }.to change(Vote, :count).by(1)
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(group_suggestions_path(group))
    follow_redirect!
    expect(page_props.dig("flash", "notice")).to eq("Your rating for “Heat” was saved.")
    expect(page_props["suggestions"].sole).to include("my_rating" => "love", "score" => 2)

    %w[maybe not_interested].each do |rating|
      expect {
        put group_suggestion_vote_path(group, suggestion), params: { rating: rating }
      }.not_to change(Vote, :count)
      expect(my_votes.sole.rating).to eq(rating)
    end
  end

  it "rejects anything other than the three ratings and keeps the previous rating" do
    Vote.create!(suggestion: suggestion, user: member, rating: "maybe")
    sign_in(member)

    [ "veto", "", "LOVE", nil ].each do |rating|
      put group_suggestion_vote_path(group, suggestion), params: { rating: rating }.compact
      expect(response).to redirect_to(group_suggestions_path(group))
      follow_redirect!
      expect(page_props.dig("errors", "rating")).to eq([ "Choose Love it, Maybe, or Not interested." ])
      expect(my_votes.sole.rating).to eq("maybe")
    end
  end

  it "always records the vote for the signed-in member" do
    sign_in(member)

    put group_suggestion_vote_path(group, suggestion), params: { rating: "love", user_id: owner.id }

    expect(Vote.sole.user).to eq(member)
  end

  it "only rates suggestions in the selected group" do
    other_group = Group.create_with_owner!(owner: member, name: "Other films")
    elsewhere = Suggestion.create!(group: other_group, suggested_by: member, title: "Up")
    sign_in(member)

    [ elsewhere.id, Suggestion.maximum(:id) + 1 ].each do |id|
      put group_suggestion_vote_path(group, id), params: { rating: "love" }
      expect(response).to have_http_status(:not_found)
      expect(page_props["message"]).to eq("That suggestion could not be found.")
    end
    expect(Vote.count).to eq(0)
  end

  it "does not let outsiders or signed-out visitors rate" do
    put group_suggestion_vote_path(group, suggestion), params: { rating: "love" }
    expect(response).to redirect_to(sign_in_path)

    sign_in(create_user)
    put group_suggestion_vote_path(group, suggestion), params: { rating: "love" }
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("Heat", group.name)
    expect(Vote.count).to eq(0)
  end

  it "updates the existing rating if a concurrent first rating won the insert" do
    sign_in(member)
    attempts = 0
    allow_any_instance_of(Vote).to receive(:save).and_wrap_original do |original, *args|
      attempts += 1
      if attempts == 1
        Vote.create!(suggestion: suggestion, user: member, rating: "maybe")
        raise ActiveRecord::RecordNotUnique
      end
      original.call(*args)
    end

    put group_suggestion_vote_path(group, suggestion), params: { rating: "love" }

    expect(response).to redirect_to(group_suggestions_path(group))
    expect(my_votes.sole.rating).to eq("love")
  end

  it "gives up after a second uniqueness conflict" do
    sign_in(member)
    allow_any_instance_of(Vote).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    expect {
      put group_suggestion_vote_path(group, suggestion), params: { rating: "love" }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "limits how quickly one member can submit ratings" do
    sign_in(member)
    60.times { |index| put group_suggestion_vote_path(group, suggestion), params: { rating: index.even? ? "love" : "maybe" } }

    put group_suggestion_vote_path(group, suggestion), params: { rating: "not_interested" }

    expect(response).to have_http_status(:too_many_requests)
    expect(page_props["message"]).to eq("Too many ratings. Please try again in a minute.")
    expect(my_votes.sole.rating).to eq("maybe")
  end

  it "enforces CSRF protection" do
    sign_in(member)
    previous = ApplicationController.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true

    put group_suggestion_vote_path(group, suggestion), params: { rating: "love" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Vote.count).to eq(0)
  ensure
    ApplicationController.allow_forgery_protection = previous
  end
end
