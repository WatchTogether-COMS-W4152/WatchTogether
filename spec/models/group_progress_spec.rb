require "rails_helper"

RSpec.describe GroupProgress do
  let(:alice) { create_user(display_name: "Alice") }
  let(:bob) { create_user(display_name: "Bob") }
  let(:carol) { create_user(display_name: "carol") }
  let(:group) { Group.create_with_owner!(owner: alice, name: "Roommates") }
  let(:show) { group.watchlist_items.create!(title: "Severance") }

  before do
    group.memberships.create!(user: bob)
    group.memberships.create!(user: carol)
  end

  def watched(user, season, episode)
    show.episode_progresses.create!(user: user, season: season, episode: episode)
  end

  def summary(progress = show.group_progress)
    progress.entries.map { |entry| [ entry.user.display_name, entry.position, entry.caught_up ] }
  end

  it "starts everyone at S1 E1 when nobody has watched anything" do
    progress = show.group_progress

    expect(summary(progress)).to eq([ [ "Alice", nil, false ], [ "Bob", nil, false ], [ "carol", nil, false ] ])
    expect(progress.started?).to be(false)
    expect(progress.furthest).to be_nil
    expect(progress.next_episode).to eq(season: 1, episode: 1)
    expect(progress.everyone_caught_up?).to be(false)
    expect(show.next_group_episode).to be_nil
  end

  it "orders members furthest ahead first, comparing seasons before episodes" do
    watched(alice, 1, 10)
    watched(bob, 2, 1)
    watched(carol, 1, 9)

    expect(summary).to eq([
      [ "Bob", { season: 2, episode: 1 }, true ],
      [ "Alice", { season: 1, episode: 10 }, false ],
      [ "carol", { season: 1, episode: 9 }, false ]
    ])
  end

  it "plans the episode after the member who is furthest behind" do
    watched(alice, 2, 4)
    watched(bob, 1, 8)
    watched(carol, 2, 1)

    expect(show.group_progress.next_episode).to eq(season: 1, episode: 9)
    expect(show.next_group_episode).to eq(season: 1, episode: 9)
  end

  it "keeps the group at S1 E1 while anyone has not started, listing them last" do
    watched(alice, 3, 2)
    watched(carol, 3, 2)
    progress = show.group_progress

    expect(summary(progress)).to eq([
      [ "Alice", { season: 3, episode: 2 }, true ],
      [ "carol", { season: 3, episode: 2 }, true ],
      [ "Bob", nil, false ]
    ])
    expect(progress.started?).to be(true)
    expect(progress.next_episode).to eq(season: 1, episode: 1)
    expect(progress.everyone_caught_up?).to be(false)
  end

  it "recognizes when everyone is caught up and plans the following episode" do
    [ alice, bob, carol ].each { |user| watched(user, 1, 5) }
    progress = show.group_progress

    expect(progress.entries.map(&:caught_up)).to all(be(true))
    expect(progress.everyone_caught_up?).to be(true)
    expect(progress.furthest).to eq(season: 1, episode: 5)
    expect(progress.next_episode).to eq(season: 1, episode: 6)
  end

  it "stops counting a member's progress once they leave the group" do
    watched(alice, 2, 3)
    watched(bob, 2, 3)
    watched(carol, 1, 1)
    group.memberships.find_by!(user: carol).destroy!
    progress = show.reload.group_progress

    expect(summary(progress).map(&:first)).to eq(%w[Alice Bob])
    expect(progress.everyone_caught_up?).to be(true)
    expect(progress.next_episode).to eq(season: 2, episode: 4)
  end

  it "has no next episode for movies" do
    movie = group.watchlist_items.create!(title: "Up", tmdb_id: 14_160, media_type: "movie")

    expect(movie.next_group_episode).to be_nil
  end

  it "accepts a preloaded member list" do
    watched(alice, 1, 2)

    expect(show.next_group_episode(members: [ alice ])).to eq(season: 1, episode: 3)
    expect(described_class.new(show, members: []).next_episode).to eq(season: 1, episode: 1)
    expect(described_class.new(show, members: []).everyone_caught_up?).to be(false)
  end
end
