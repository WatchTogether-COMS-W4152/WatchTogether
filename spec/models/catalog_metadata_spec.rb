require "rails_helper"

RSpec.describe "Catalog identity" do
  let(:group) { Group.create_with_owner!(owner: create_user, name: "Films") }

  [ Suggestion, WatchlistItem ].each do |model|
    it "allows #{model} remakes and TV namesakes while rejecting a duplicate TMDB identity" do
      model.create!(group: group, title: "Dune", tmdb_id: 1, media_type: "movie")
      expect(model.create!(group: group, title: "Dune", tmdb_id: 2, media_type: "movie")).to be_persisted
      expect(model.create!(group: group, title: "Dune", tmdb_id: 1, media_type: "tv")).to be_persisted
      duplicate = model.new(group: group, title: "A changed title", tmdb_id: 1, media_type: "movie")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:title]).to be_present
      expect {
        model.transaction(requires_new: true) { duplicate.save!(validate: false) }
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "requires a complete valid #{model} catalog identity while allowing manual titles" do
      expect(model.new(group: group, title: "Local movie")).to be_valid
      [ { tmdb_id: 1 }, { media_type: "tv" }, { tmdb_id: -1, media_type: "movie" }, { tmdb_id: 1, media_type: "person" } ].each do |identity|
        expect(model.new(group: group, title: "Bad identity", **identity)).not_to be_valid
      end
    end

    it "allows long canonical #{model} titles but keeps manual titles limited to 120 characters" do
      expect(model.new(group: group, title: "a" * 121, tmdb_id: 1, media_type: "movie")).to be_valid
      expect(model.new(group: group, title: "a" * 121)).not_to be_valid
    end

    it "enforces #{model} identity integrity in the database even when validation is bypassed" do
      [ { tmdb_id: 1 }, { media_type: "tv" }, { tmdb_id: 0, media_type: "movie" }, { tmdb_id: 1, media_type: "person" } ].each do |identity|
        invalid = model.new(group: group, title: "Invalid catalog record", **identity)
        expect {
          model.transaction(requires_new: true) { invalid.save!(validate: false) }
        }.to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint|check constraint/)
      end
      expect(model.where(group: group)).to be_empty
    end

    it "allows the same #{model} catalog entry in independent groups" do
      other_group = Group.create_with_owner!(owner: create_user, name: "Other films")
      model.create!(group: group, title: "Dune", tmdb_id: 1, media_type: "movie")

      expect(model.create!(group: other_group, title: "Dune", tmdb_id: 1, media_type: "movie")).to be_persisted
    end
  end

  it "enforces one watchlist copy per source suggestion independently of catalog metadata" do
    source = Suggestion.create!(group: group, title: "Local screening")
    WatchlistItem.create!(group: group, title: source.title, source_suggestion: source)
    duplicate = WatchlistItem.new(group: group, title: "Another label", source_suggestion: source)

    expect {
      WatchlistItem.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "nullifies only the source link when a suggestion is deleted directly in the database" do
    source = Suggestion.create!(group: group, title: "Local screening")
    item = WatchlistItem.create!(group: group, title: source.title, source_suggestion: source, watched: true)

    source.delete

    expect(item.reload).to have_attributes(title: "Local screening", source_suggestion_id: nil, watched: true)
  end
end
