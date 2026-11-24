require "rails_helper"

RSpec.describe WatchlistItem, type: :model do
  let(:owner) { create_user }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Movie night") }

  it "requires a nonblank title on an otherwise valid item" do
    [ nil, "", "   " ].each do |title|
      item = WatchlistItem.new(group: group, title: title)

      expect(item).not_to be_valid
      expect(item.errors[:title]).to include("can't be blank")
      expect(item.errors[:group]).to be_empty
    end
  end

  it "accepts 120 characters and rejects 121 specifically because the title is too long" do
    item = WatchlistItem.new(group: group, title: "A" * 120)

    expect(item).to be_valid
    item.save!
    expect(item.reload.title.length).to eq(120)

    item.title = "A" * 121

    expect(item).not_to be_valid
    expect(item.errors[:title]).to include("is too long (maximum is 120 characters)")
    expect(item.errors[:group]).to be_empty
  end

  it "requires an existing group even when the title is valid" do
    item = WatchlistItem.new(title: "Titanic")

    expect(item).not_to be_valid
    expect(item.errors[:group]).to include("must exist")
    expect(item.errors[:title]).to be_empty

    item.group = group
    expect(item).to be_valid
  end

  it "persists new items as unwatched by default" do
    item = group.watchlist_items.create!(title: "Titanic")

    expect(item.reload).to have_attributes(group_id: group.id, title: "Titanic", watched: false)
  end

  it "enforces the required group and its foreign key in the database" do
    group
    missing_group = WatchlistItem.new(title: "Titanic")
    invalid_group = WatchlistItem.new(title: "Titanic", group_id: Group.maximum(:id) + 1)

    expect {
      WatchlistItem.transaction(requires_new: true) { missing_group.save!(validate: false) }
    }.to raise_error(ActiveRecord::NotNullViolation)
    expect {
      WatchlistItem.transaction(requires_new: true) { invalid_group.save!(validate: false) }
    }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  [ :title, :watched ].each do |attribute|
    it "rejects a null #{attribute} in the database when validations are bypassed" do
      item = WatchlistItem.new(group: group, title: "Titanic")
      item[attribute] = nil

      expect {
        WatchlistItem.transaction(requires_new: true) { item.save!(validate: false) }
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "season lengths" do
    let(:client) { instance_double(TmdbClient) }

    before { allow(TmdbClient).to receive(:new).and_return(client) }

    it "fetches season lengths for a TMDB show once and stores them" do
      allow(client).to receive(:season_lengths).with(66_732).and_return([ 8, 9 ])
      show = group.watchlist_items.create!(title: "Stranger Things", tmdb_id: 66_732, media_type: "tv")

      expect(show.season_lengths).to eq([ 8, 9 ])
      expect(show.reload.season_lengths).to eq([ 8, 9 ])
      expect(client).to have_received(:season_lengths).once
    end

    it "refreshes stored lengths after a day and keeps them when TMDB is down" do
      allow(client).to receive(:season_lengths).and_raise(TmdbClient::Unavailable)
      show = group.watchlist_items.create!(title: "Stranger Things", tmdb_id: 66_732, media_type: "tv",
        season_lengths: [ 8 ], season_lengths_checked_at: 2.days.ago)

      expect(show.season_lengths).to eq([ 8 ])
      expect(show.season_lengths).to eq([ 8 ])
      expect(client).to have_received(:season_lengths).once
    end

    it "never asks TMDB about custom titles" do
      allow(client).to receive(:season_lengths)
      show = group.watchlist_items.create!(title: "Home videos")

      expect(show.season_lengths).to be_nil
      expect(client).not_to have_received(:season_lengths)
    end

    it "steps through episodes, rolls over to the next season, and stops at the end" do
      show = group.watchlist_items.create!(title: "Stranger Things", tmdb_id: 66_732, media_type: "tv",
        season_lengths: [ 8, 9 ], season_lengths_checked_at: Time.current)

      expect(show.position_after(season: 1, episode: 7)).to eq(season: 1, episode: 8)
      expect(show.position_after(season: 1, episode: 8)).to eq(season: 2, episode: 1)
      expect(show.position_after(season: 2, episode: 9)).to be_nil
    end

    it "counts up without limit when the lengths are unknown" do
      show = group.watchlist_items.create!(title: "Home videos")

      expect(show.position_after(season: 1, episode: 60)).to eq(season: 1, episode: 61)
    end
  end
end
