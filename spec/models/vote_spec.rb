require "rails_helper"

RSpec.describe Vote, type: :model do
  let(:owner) { create_user }
  let(:member) { create_user }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Friday films") }
  let(:suggestion) { Suggestion.create!(group: group, suggested_by: owner, title: "Heat") }

  before { group.memberships.create!(user: member) }

  it "scores exactly three ratings" do
    expect(Vote::SCORES).to eq("love" => 2, "maybe" => 1, "not_interested" => -2)
    expect(Vote.ratings.keys).to eq(Vote::SCORES.keys)
  end

  it "requires a suggestion and a user" do
    vote = Vote.new(rating: "love")

    expect(vote).not_to be_valid
    expect(vote.errors).to include(:suggestion, :user)
  end

  it "accepts only Love it, Maybe, and Not interested" do
    vote = Vote.new(suggestion: suggestion, user: member)

    [ nil, "", "veto", "LOVE", "abstain" ].each do |rating|
      vote.rating = rating
      expect(vote).not_to be_valid
      expect(vote.errors[:rating]).not_to be_empty
    end
    %w[love maybe not_interested].each do |rating|
      vote.rating = rating
      expect(vote).to be_valid
    end
  end

  it "enforces supported, non-null ratings in the database" do
    vote = Vote.new(suggestion: suggestion, user: member, rating: "veto")
    expect {
      Vote.transaction(requires_new: true) { vote.save!(validate: false) }
    }.to raise_error(ActiveRecord::StatementInvalid)

    vote.rating = nil
    expect {
      Vote.transaction(requires_new: true) { vote.save!(validate: false) }
    }.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "allows one rating per person per suggestion" do
    Vote.create!(suggestion: suggestion, user: member, rating: "love")
    duplicate = Vote.new(suggestion: suggestion, user: member, rating: "maybe")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to include("has already been taken")
    expect {
      Vote.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(Vote.new(suggestion: suggestion, user: owner, rating: "maybe")).to be_valid
  end

  it "only lets members of the suggestion's group rate it" do
    outsider = create_user
    vote = Vote.new(suggestion: suggestion, user: outsider, rating: "love")

    expect(vote).not_to be_valid
    expect(vote.errors[:user]).to include("must be a member of this group")
  end

  it "enforces suggestion and user foreign keys in the database" do
    suggestion
    invalid_suggestion = Vote.new(user: member, rating: "love", suggestion_id: Suggestion.maximum(:id) + 1)
    invalid_user = Vote.new(suggestion: suggestion, rating: "love", user_id: User.maximum(:id) + 1)

    [ invalid_suggestion, invalid_user ].each do |vote|
      expect {
        Vote.transaction(requires_new: true) { vote.save!(validate: false) }
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
