require "rails_helper"

RSpec.describe EpisodeComment do
  let(:larissa) { create_user(display_name: "Larissa") }
  let(:david) { create_user(display_name: "David") }
  let(:outsider) { create_user(display_name: "Carol") }
  let(:group) { Group.create_with_owner!(owner: david, name: "Roommates") }
  let(:show) { group.watchlist_items.create!(title: "Severance") }

  before { group.memberships.create!(user: larissa) }

  def watched(user, season, episode)
    progress = show.episode_progresses.find_or_initialize_by(user: user)
    progress.update!(season: season, episode: episode)
  end

  def comment(user, season, episode, body = "S#{season}E#{episode} by #{user.display_name}")
    watched(user, season, episode) unless show.episode_progresses.find_by(user: user)&.reached?(season: season, episode: episode)
    show.episode_comments.create!(user: user, season: season, episode: episode, body: body)
  end

  def errors_for(record, attribute)
    record.validate
    record.errors[attribute]
  end

  def visible_bodies(user)
    described_class.visible_to(user, show).map(&:body)
  end

  describe ".visible_to and .hidden_counts_for" do
    it "shows nothing but a count to a member who has not watched any episode" do
      comment(david, 1, 1)
      comment(david, 1, 2)

      expect(visible_bodies(larissa)).to be_empty
      expect(described_class.hidden_counts_for(larissa, show)).to eq([
        { season: 1, episode: 1, count: 1 },
        { season: 1, episode: 2, count: 1 }
      ])
    end

    it "includes the exact episode the member has reached" do
      comment(david, 1, 4, "Episode four")
      comment(david, 1, 5, "Episode five")
      watched(larissa, 1, 4)

      expect(visible_bodies(larissa)).to eq([ "Episode four" ])
      expect(described_class.hidden_counts_for(larissa, show)).to eq([ { season: 1, episode: 5, count: 1 } ])
    end

    it "orders by season before episode, so S1 E10 comes before S2 E1" do
      comment(david, 2, 1, "Season two premiere")
      comment(david, 1, 10, "Season one finale")
      comment(david, 1, 2, "Early on")
      watched(larissa, 1, 10)

      expect(visible_bodies(larissa)).to eq([ "Early on", "Season one finale" ])
      expect(described_class.hidden_counts_for(larissa, show)).to eq([ { season: 2, episode: 1, count: 1 } ])
      expect(visible_bodies(david)).to eq([ "Early on", "Season one finale", "Season two premiere" ])
    end

    it "shows a later season's earlier episode numbers only once that season is reached" do
      comment(david, 2, 3, "Big twist")
      watched(larissa, 1, 12)

      expect(visible_bodies(larissa)).to be_empty
      watched(larissa, 2, 3)
      expect(visible_bodies(larissa)).to eq([ "Big twist" ])
    end

    it "keeps comments newest-last within an episode" do
      first = comment(david, 1, 1, "First")
      second = comment(larissa, 1, 1, "Second")
      first.update_columns(created_at: 1.hour.ago)
      second.update_columns(created_at: 1.minute.ago)

      expect(visible_bodies(david)).to eq([ "First", "Second" ])
    end

    it "counts several hidden comments per episode" do
      3.times { |n| comment(david, 1, 8, "Reaction #{n}") }
      watched(larissa, 1, 4)

      expect(described_class.hidden_counts_for(larissa, show)).to eq([ { season: 1, episode: 8, count: 3 } ])
    end

    it "unlocks comments as the member's progress moves forward" do
      comment(david, 1, 8, "Can't believe it")
      watched(larissa, 1, 4)
      expect(visible_bodies(larissa)).to be_empty

      watched(larissa, 1, 8)

      expect(visible_bodies(larissa)).to eq([ "Can't believe it" ])
      expect(described_class.hidden_counts_for(larissa, show)).to be_empty
    end

    it "always shows a member their own comments, even if they later move their progress back" do
      comment(larissa, 1, 6, "My take")
      watched(larissa, 1, 2)

      expect(visible_bodies(larissa)).to eq([ "My take" ])
      expect(described_class.hidden_counts_for(larissa, show)).to be_empty
      show.episode_progresses.find_by(user: larissa).destroy!
      expect(visible_bodies(larissa)).to eq([ "My take" ])
    end

    it "only includes comments for the given show" do
      other = group.watchlist_items.create!(title: "Andor")
      other.episode_progresses.create!(user: david, season: 1, episode: 1)
      other.episode_comments.create!(user: david, season: 1, episode: 1, body: "Other show")
      comment(david, 1, 1, "This show")
      watched(larissa, 5, 5)

      expect(visible_bodies(larissa)).to eq([ "This show" ])
      expect(described_class.hidden_counts_for(larissa, other)).to eq([ { season: 1, episode: 1, count: 1 } ])
    end
  end

  describe "validations" do
    it "requires an episode the author has reached" do
      watched(larissa, 1, 4)

      beyond = show.episode_comments.new(user: larissa, season: 1, episode: 5, body: "Spoiler")
      next_season = show.episode_comments.new(user: larissa, season: 2, episode: 1, body: "Spoiler")

      expect(beyond).not_to be_valid
      expect(beyond.errors[:episode].first).to include("You're on S1 E4", "can't comment on S1 E5")
      expect(next_season).not_to be_valid
      expect(show.episode_comments.new(user: larissa, season: 1, episode: 4, body: "Fine")).to be_valid
    end

    it "explains that a member without progress must watch first" do
      comment = show.episode_comments.new(user: larissa, season: 1, episode: 1, body: "Hi")

      expect(comment).not_to be_valid
      expect(comment.errors[:episode].first).to include("haven't marked any episodes as watched")
    end

    it "requires a nonblank body of at most 1000 characters and trims spaces" do
      watched(larissa, 1, 1)

      expect(errors_for(show.episode_comments.new(user: larissa, season: 1, episode: 1, body: "   "), :body))
        .to eq([ "Write something before posting." ])
      expect(show.episode_comments.new(user: larissa, season: 1, episode: 1, body: "a" * 1001)).not_to be_valid
      expect(show.episode_comments.create!(user: larissa, season: 1, episode: 1, body: "  #{"a" * 1000}  ").body.length).to eq(1000)
    end

    it "requires positive whole season and episode numbers" do
      comment = show.episode_comments.new(user: larissa, season: 0, episode: nil, body: "Hi")

      expect(comment).not_to be_valid
      expect(comment.errors[:season]).to eq([ "Season must be a whole number from 1 to 9999." ])
      expect(comment.errors[:episode]).to eq([ "Episode must be a whole number from 1 to 9999." ])
    end

    it "requires an author who belongs to the group" do
      expect(show.episode_comments.new(season: 1, episode: 1, body: "Hi")).not_to be_valid
      expect(errors_for(show.episode_comments.new(user: outsider, season: 1, episode: 1, body: "Hi"), :user))
        .to eq([ "must be a member of the group" ])
    end

    it "is not available for movies" do
      movie = group.watchlist_items.create!(title: "Up", tmdb_id: 14_160, media_type: "movie")
      comment = movie.episode_comments.new(user: larissa, season: 1, episode: 1, body: "Hi")

      expect(comment).not_to be_valid
      expect(comment.errors[:base]).to eq([ "Discussion is only available for TV shows" ])
    end
  end

  describe "deletion and lifecycle" do
    it "can be deleted by its author or a group owner only" do
      by_larissa = comment(larissa, 1, 1)

      expect(by_larissa.deletable_by?(larissa)).to be(true)
      expect(by_larissa.deletable_by?(david)).to be(false)
      expect(by_larissa.deletable_by?(david, group_owner: true)).to be(true)
      expect(by_larissa.deletable_by?(nil)).to be(false)
    end

    it "is deleted with its watchlist item" do
      comment(david, 1, 1)

      expect { show.destroy! }.to change(described_class, :count).by(-1)
    end

    it "keeps the comment without an author when the account is deleted" do
      kept = comment(larissa, 1, 1, "Still here")
      larissa.memberships.destroy_all
      larissa.destroy!

      expect(kept.reload.user).to be_nil
      expect(kept.body).to eq("Still here")
      expect(kept.deletable_by?(david)).to be(false)
      expect(kept).to be_valid
    end

    it "enforces positions and body length in the database" do
      kept = comment(david, 1, 1)

      expect { kept.update_columns(episode: 0) }.to raise_error(ActiveRecord::StatementInvalid)
      expect { kept.update_columns(body: "a" * 1001) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  it "labels positions like the rest of the app" do
    expect(described_class.label(season: 2, episode: 10)).to eq("S2 E10")
  end
end
