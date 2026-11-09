require "rails_helper"

RSpec.describe Suggestion, type: :model do
  let(:owner) { create_user(display_name: "Alice") }
  let(:member) { create_user(display_name: "Bob") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Friday films") }

  before { group.memberships.create!(user: member) }

  def suggest(title, by: owner, in_group: group)
    Suggestion.create!(group: in_group, suggested_by: by, title: title)
  end

  def rate(suggestion, user, rating)
    Vote.create!(suggestion: suggestion, user: user, rating: rating)
  end

  describe "validations" do
    it "squishes the title and stores a case-insensitive key" do
      suggestion = suggest("  Spirited \n  AWAY  ")

      expect(suggestion.title).to eq("Spirited AWAY")
      expect(suggestion.title_key).to eq("spirited away")
    end

    it "requires a group and a title of at most 120 characters" do
      suggestion = Suggestion.new(title: "   ")

      expect(suggestion).not_to be_valid
      expect(suggestion.errors).to include(:group, :title)
      suggestion = Suggestion.new(group: group, title: "x" * 121)
      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:title]).to include("is too long (maximum is 120 characters)")
      suggestion.title = "x" * 120
      expect(suggestion).to be_valid
    end

    it "does not require a suggester" do
      expect(Suggestion.new(group: group, title: "Heat")).to be_valid
    end

    it "rejects a differently cased or spaced duplicate in the same group only" do
      suggest("Spirited Away")
      duplicate = Suggestion.new(group: group, title: " spirited   AWAY ")
      other_group = Group.create_with_owner!(owner: owner, name: "Other films")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:title]).to include("has already been suggested in this group")
      expect(Suggestion.new(group: other_group, title: "Spirited Away")).to be_valid
    end

    it "lets a suggestion keep its own title when updated" do
      suggestion = suggest("Heat")

      expect(suggestion.update(title: "HEAT")).to be(true)
      expect(suggestion.reload.title_key).to eq("heat")
    end

    it "enforces unique titles per group in the database" do
      suggest("Heat")
      duplicate = Suggestion.new(group: group, title: "heat")

      expect {
        Suggestion.transaction(requires_new: true) { duplicate.save!(validate: false) }
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces the group foreign key and required columns in the database" do
      missing_group = Suggestion.new(title: "Heat")
      invalid_group = Suggestion.new(title: "Heat", group_id: Group.maximum(:id) + 1)

      expect {
        Suggestion.transaction(requires_new: true) { missing_group.save!(validate: false) }
      }.to raise_error(ActiveRecord::NotNullViolation)
      expect {
        Suggestion.transaction(requires_new: true) { invalid_group.save!(validate: false) }
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "deletion" do
    it "removes a group's suggestions and their votes when the group is deleted" do
      suggestion = suggest("Heat")
      rate(suggestion, member, "love")
      other = suggest("Up", in_group: Group.create_with_owner!(owner: owner, name: "Other films"))

      group.destroy!

      expect(Suggestion.exists?(suggestion.id)).to be(false)
      expect(Vote.where(suggestion_id: suggestion.id)).to be_empty
      expect(Suggestion.exists?(other.id)).to be(true)
    end

    it "removes its votes when a suggestion is destroyed" do
      suggestion = suggest("Heat")
      rate(suggestion, owner, "love")
      rate(suggestion, member, "maybe")

      expect { suggestion.destroy! }.to change(Vote, :count).by(-2)
    end

    it "keeps suggestions but forgets the suggester and their votes when an account is deleted" do
      theirs = suggest("Heat", by: member)
      mine = suggest("Up")
      rate(mine, member, "love")
      rate(theirs, owner, "maybe")

      member.destroy!

      expect(theirs.reload.suggested_by).to be_nil
      expect(Vote.where(user_id: member.id)).to be_empty
      expect(Vote.where(suggestion: theirs, user: owner)).to exist
    end
  end

  describe ".ranked_for" do
    let(:carol) { create_user(display_name: "Carol") }

    before { group.memberships.create!(user: carol) }

    def ranking(viewer: owner)
      Suggestion.ranked_for(group, viewer: viewer).map { |suggestion| [ suggestion.title, suggestion.score ] }
    end

    it "sums Love it as +2, Maybe as +1, and Not interested as -2" do
      love = suggest("Love")
      maybe = suggest("Maybe")
      not_interested = suggest("Not interested")
      rate(love, member, "love")
      rate(maybe, member, "maybe")
      rate(not_interested, member, "not_interested")

      expect(ranking).to eq([ [ "Love", 2 ], [ "Maybe", 1 ], [ "Not interested", -2 ] ])
    end

    it "ranks a title one person dislikes below one the whole group is mildly happy with" do
      divisive = suggest("Inception")
      safe = suggest("Paddington")
      rate(divisive, owner, "love")
      rate(divisive, member, "love")
      rate(divisive, carol, "not_interested")
      [ owner, member, carol ].each { |user| rate(safe, user, "maybe") }

      expect(ranking).to eq([ [ "Paddington", 3 ], [ "Inception", 2 ] ])
    end

    it "is not a veto: enough Loves outweigh one Not interested" do
      loved = suggest("Arrival")
      safe = suggest("Paddington")
      rate(loved, owner, "love")
      rate(loved, member, "love")
      rate(loved, carol, "not_interested")
      rate(safe, owner, "maybe")

      expect(ranking).to eq([ [ "Arrival", 2 ], [ "Paddington", 1 ] ])
    end

    it "places unrated titles at 0, between liked and disliked titles" do
      liked = suggest("Liked")
      suggest("Unrated")
      disliked = suggest("Disliked")
      rate(liked, member, "maybe")
      rate(disliked, member, "not_interested")

      expect(ranking).to eq([ [ "Liked", 1 ], [ "Unrated", 0 ], [ "Disliked", -2 ] ])
    end

    it "breaks score ties by Love count, then the oldest suggestion, then id" do
      now = Time.current
      newest = travel_to(now + 2.minutes) { suggest("Newest maybes") }
      older = travel_to(now + 1.minute) { suggest("Older maybes") }
      one_love = travel_to(now + 3.minutes) { suggest("One love") }
      same_time = travel_to(now) { [ suggest("Same time A"), suggest("Same time B") ] }
      rate(one_love, owner, "love")
      [ newest, older ].each do |suggestion|
        rate(suggestion, owner, "maybe")
        rate(suggestion, member, "maybe")
      end
      same_time.each { |suggestion| rate(suggestion, owner, "maybe") }
      Suggestion.where(id: same_time.map(&:id)).update_all(created_at: now)

      expect(ranking.map(&:first)).to eq([ "One love", "Older maybes", "Newest maybes", "Same time A", "Same time B" ])
    end

    it "counts only current members' votes and reports totals for the page" do
      suggestion = suggest("Cats")
      rate(suggestion, owner, "maybe")
      rate(suggestion, carol, "love")
      group.memberships.find_by!(user: carol).destroy!

      ranked = Suggestion.ranked_for(group, viewer: owner).sole

      expect(ranked.score).to eq(1)
      expect(ranked.votes_count).to eq(1)
      expect(ranked.love_count).to eq(0)
      expect(Vote.where(user: carol)).to exist
    end

    it "includes only the viewer's own rating and only this group's suggestions" do
      mine = suggest("Heat")
      unrated = suggest("Up")
      rate(mine, member, "not_interested")
      rate(mine, owner, "love")
      other_group = Group.create_with_owner!(owner: owner, name: "Other films")
      suggest("Elsewhere", in_group: other_group)

      ranked = Suggestion.ranked_for(group, viewer: member).index_by(&:title)

      expect(ranked.keys).to contain_exactly("Heat", "Up")
      expect(ranked["Heat"].viewer_rating).to eq("not_interested")
      expect(ranked["Up"].viewer_rating).to be_nil
      expect(Suggestion.ranked_for(group, viewer: owner).find { |s| s.id == mine.id }.viewer_rating).to eq("love")
      expect(unrated.votes).to be_empty
    end

    it "preloads the suggester for display" do
      suggest("Heat", by: member)

      ranked = Suggestion.ranked_for(group, viewer: owner).to_a

      expect(ranked.first.association(:suggested_by)).to be_loaded
      expect(ranked.first.suggested_by).to eq(member)
    end
  end
end
