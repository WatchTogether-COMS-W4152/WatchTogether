require "rails_helper"

RSpec.describe "Episode progress", type: :request do
  let(:owner) { create_user(display_name: "Alice") }
  let(:member) { create_user(display_name: "Bob") }
  let(:outsider) { create_user(display_name: "Carol") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Roommates") }
  let(:show) { group.watchlist_items.create!(title: "Severance") }
  let(:path) { group_watchlist_item_progress_path(group, show) }

  before { group.memberships.create!(user: member) }

  def my_progress(user = member)
    show.episode_progresses.find_by(user: user)
  end

  describe "showing progress on the title page" do
    it "lists every member, who is caught up, and the group's next episode" do
      show.episode_progresses.create!(user: owner, season: 2, episode: 4)
      show.episode_progresses.create!(user: member, season: 2, episode: 1)
      sign_in(member)

      get group_watchlist_item_path(group, show)

      expect(page_props["episode_progress"]).to eq(
        "members" => [
          { "id" => owner.id, "display_name" => "Alice", "position" => { "season" => 2, "episode" => 4 }, "caught_up" => true },
          { "id" => member.id, "display_name" => "Bob", "position" => { "season" => 2, "episode" => 1 }, "caught_up" => false }
        ],
        "my_position" => { "season" => 2, "episode" => 1 },
        "my_next_episode" => { "season" => 2, "episode" => 2 },
        "next_episode" => { "season" => 2, "episode" => 2 },
        "finished" => false,
        "everyone_caught_up" => false
      )
      expect(response.body).not_to include(owner.email, group.invite_code)
    end

    it "shows members who have not started" do
      sign_in(member)

      get group_watchlist_item_path(group, show)

      expect(page_props["episode_progress"]).to include(
        "my_position" => nil, "next_episode" => { "season" => 1, "episode" => 1 }, "everyone_caught_up" => false
      )
      expect(page_props["episode_progress"]["members"].map { |entry| entry["position"] }).to eq([ nil, nil ])
    end

    it "has no progress section for movies" do
      movie = group.watchlist_items.create!(title: "Up", tmdb_id: 14_160, media_type: "movie")
      sign_in(member)

      get group_watchlist_item_path(group, movie)

      expect(page_props).not_to have_key("episode_progress")
    end

    it "hints at the next episode on the watchlist once someone has started" do
      unstarted = group.watchlist_items.create!(title: "Dark")
      show.episode_progresses.create!(user: owner, season: 1, episode: 3)
      show.episode_progresses.create!(user: member, season: 1, episode: 2)
      sign_in(member)

      get group_watchlist_items_path(group)

      hints = page_props["watchlist_items"].to_h { |item| [ item["id"], item["next_episode"] ] }
      expect(hints).to eq(show.id => { "season" => 1, "episode" => 3 }, unstarted.id => nil)
    end
  end

  describe "setting progress" do
    it "records and then updates a member's position" do
      sign_in(member)

      expect { put path, params: { season: 2, episode: 3 } }.to change(EpisodeProgress, :count).by(1)
      expect(response).to redirect_to(group_watchlist_item_path(group, show))
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(page_props.dig("flash", "notice")).to eq("Saved. You've watched up to S2 E3.")
      expect(page_props.dig("episode_progress", "my_position")).to eq("season" => 2, "episode" => 3)

      expect { put path, params: { season: 1, episode: 7 } }.not_to change(EpisodeProgress, :count)
      expect(my_progress.position).to eq(season: 1, episode: 7)
    end

    it "advances to the next episode, starting from S1 E1" do
      sign_in(member)

      put path, params: { next: "1" }
      expect(my_progress.position).to eq(season: 1, episode: 1)

      put path, params: { next: "1" }
      put path, params: { next: "1" }
      expect(my_progress.position).to eq(season: 1, episode: 3)
    end

    it "explains invalid numbers and keeps the previous position" do
      show.episode_progresses.create!(user: member, season: 1, episode: 4)
      sign_in(member)

      [ { season: 0, episode: 1 }, { season: 1, episode: "" }, { season: "two", episode: 2.5 }, {} ].each do |params|
        put path, params: params
        expect(response).to redirect_to(group_watchlist_item_path(group, show))
        follow_redirect!
        expected = {}
        expected["season"] = [ "Enter a season number of 1 or more." ] unless params[:season] == 1
        expected["episode"] = [ "Enter an episode number of 1 or more." ] unless params[:episode] == 1 || params[:episode] == 2
        expect(page_props["errors"]).to eq(expected)
      end
      expect(my_progress.position).to eq(season: 1, episode: 4)
    end

    it "retries once when a concurrent first save wins the insert" do
      sign_in(member)
      calls = 0
      allow_any_instance_of(EpisodeProgress).to receive(:save).and_wrap_original do |original|
        calls += 1
        raise ActiveRecord::RecordNotUnique, "duplicate" if calls == 1

        original.call
      end

      put path, params: { season: 1, episode: 2 }

      expect(calls).to eq(2)
      expect(my_progress.position).to eq(season: 1, episode: 2)
    end

    it "gives up after a second conflicting insert" do
      sign_in(member)
      allow_any_instance_of(EpisodeProgress).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      expect { put path, params: { season: 1, episode: 2 } }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "throttles rapid updates" do
      sign_in(member)
      ApplicationController::RATE_LIMIT_STORE.clear

      60.times { put path, params: { next: "1" } }
      put path, params: { next: "1" }

      expect(response).to have_http_status(:too_many_requests)
      expect(page_props["message"]).to eq("Too many progress updates. Please try again in a minute.")
    ensure
      ApplicationController::RATE_LIMIT_STORE.clear
    end
  end

  describe "clearing progress" do
    it "removes only my own progress" do
      show.episode_progresses.create!(user: owner, season: 1, episode: 2)
      show.episode_progresses.create!(user: member, season: 1, episode: 5)
      sign_in(member)

      delete path

      expect(response).to redirect_to(group_watchlist_item_path(group, show))
      follow_redirect!
      expect(page_props.dig("flash", "notice")).to eq("Your progress was cleared.")
      expect(my_progress).to be_nil
      expect(my_progress(owner).position).to eq(season: 1, episode: 2)
    end

    it "is harmless when I have no progress" do
      sign_in(member)

      expect { delete path }.not_to change(EpisodeProgress, :count)
      expect(response).to redirect_to(group_watchlist_item_path(group, show))
    end
  end

  describe "access" do
    it "hides progress from outsiders" do
      show.episode_progresses.create!(user: owner, season: 1, episode: 2)
      sign_in(outsider)

      put path, params: { season: 1, episode: 1 }
      expect(response).to have_http_status(:not_found)
      delete path
      expect(response).to have_http_status(:not_found)
      expect(EpisodeProgress.pluck(:user_id)).to eq([ owner.id ])
    end

    it "does not reach another group's title through this group" do
      other = Group.create_with_owner!(owner: outsider, name: "Other")
      other_show = other.watchlist_items.create!(title: "Private")
      sign_in(member)

      put group_watchlist_item_progress_path(group, other_show), params: { season: 1, episode: 1 }

      expect(response).to have_http_status(:not_found)
      expect(other_show.episode_progresses).to be_empty
    end

    it "does not track movies" do
      movie = group.watchlist_items.create!(title: "Up", tmdb_id: 14_160, media_type: "movie")
      sign_in(member)

      put group_watchlist_item_progress_path(group, movie), params: { season: 1, episode: 1 }

      expect(response).to have_http_status(:not_found)
      expect(page_props["message"]).to eq("Episode progress is only available for TV shows.")
      expect(movie.episode_progresses).to be_empty
    end

    it "asks signed-out visitors to sign in" do
      put path, params: { season: 1, episode: 1 }
      expect(response).to redirect_to(sign_in_path)
      delete path
      expect(response).to redirect_to(sign_in_path)
      expect(EpisodeProgress.count).to eq(0)
    end
  end

  describe "with season lengths from TMDB" do
    let(:show) do
      group.watchlist_items.create!(title: "Stranger Things", tmdb_id: 66_732, media_type: "tv",
        season_lengths: [ 3, 2 ], season_lengths_checked_at: Time.current)
    end

    it "moves to the next season after the last episode of a season" do
      show.episode_progresses.create!(user: member, season: 1, episode: 3)
      sign_in(member)

      put path, params: { next: "1" }

      expect(my_progress.position).to eq(season: 2, episode: 1)
    end

    it "stops after the last episode of the show" do
      show.episode_progresses.create!(user: owner, season: 2, episode: 2)
      show.episode_progresses.create!(user: member, season: 2, episode: 2)
      sign_in(member)

      put path, params: { next: "1" }
      expect(my_progress.position).to eq(season: 2, episode: 2)
      expect(flash[:notice]).to eq("You've watched every episode.")

      get group_watchlist_item_path(group, show)
      expect(page_props["episode_progress"]).to include(
        "my_next_episode" => nil, "next_episode" => nil, "finished" => true
      )
    end

    it "rejects seasons and episodes the show doesn't have" do
      sign_in(member)

      put path, params: { season: "3", episode: "1" }
      follow_redirect!
      expect(page_props["errors"]).to eq("season" => [ "This show has 2 seasons." ])

      put path, params: { season: "1", episode: "61" }
      follow_redirect!
      expect(page_props["errors"]).to eq("episode" => [ "Season 1 has 3 episodes." ])
      expect(my_progress).to be_nil
    end
  end
end
