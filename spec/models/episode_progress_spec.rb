require "rails_helper"

RSpec.describe EpisodeProgress do
  let(:owner) { create_user(display_name: "Alice") }
  let(:outsider) { create_user(display_name: "Carol") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Roommates") }
  let(:show) { group.watchlist_items.create!(title: "Severance") }

  it "compares positions by season, then episode" do
    expect(described_class.compare({ season: 1, episode: 10 }, { season: 2, episode: 1 })).to eq(-1)
    expect(described_class.compare({ season: 2, episode: 3 }, { season: 2, episode: 3 })).to eq(0)
    expect(described_class.compare({ season: 2, episode: 4 }, { season: 2, episode: 3 })).to eq(1)
  end

  it "knows which episodes a member has reached" do
    progress = show.episode_progresses.create!(user: owner, season: 2, episode: 3)

    expect(progress.reached?(season: 2, episode: 3)).to be(true)
    expect(progress.reached?(season: 1, episode: 9)).to be(true)
    expect(progress.reached?(season: 2, episode: 4)).to be(false)
    expect(progress.reached?(season: 3, episode: 1)).to be(false)
  end

  it "requires positive whole season and episode numbers" do
    progress = show.episode_progresses.new(user: owner, season: 0, episode: 1.5)

    expect(progress).not_to be_valid
    expect(progress.errors[:season]).to be_present
    expect(progress.errors[:episode]).to be_present
  end

  it "keeps one progress record per member per show" do
    show.episode_progresses.create!(user: owner, season: 1, episode: 1)

    expect(show.episode_progresses.new(user: owner, season: 1, episode: 2)).not_to be_valid
  end

  it "only tracks members of the show's group" do
    expect(show.episode_progresses.new(user: outsider, season: 1, episode: 1)).not_to be_valid
  end

  it "does not track progress for movies" do
    movie = group.watchlist_items.create!(title: "Up", tmdb_id: 14_160, media_type: "movie")

    expect(movie.episodic?).to be(false)
    expect(movie.episode_progresses.new(user: owner, season: 1, episode: 1)).not_to be_valid
  end

  it "is deleted with its watchlist item" do
    show.episode_progresses.create!(user: owner, season: 1, episode: 1)

    expect { show.destroy! }.to change(described_class, :count).by(-1)
  end
end
