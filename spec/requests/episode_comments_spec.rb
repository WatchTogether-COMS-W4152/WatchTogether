require "rails_helper"

RSpec.describe "Episode discussion", type: :request do
  let(:david) { create_user(display_name: "David") }
  let(:larissa) { create_user(display_name: "Larissa") }
  let(:sam) { create_user(display_name: "Sam") }
  let(:outsider) { create_user(display_name: "Carol") }
  let(:group) { Group.create_with_owner!(owner: david, name: "Roommates") }
  let(:show) { group.watchlist_items.create!(title: "Severance") }

  before do
    group.memberships.create!(user: larissa)
    group.memberships.create!(user: sam)
  end

  def watched(user, season, episode, item: show)
    progress = item.episode_progresses.find_or_initialize_by(user: user)
    progress.update!(season: season, episode: episode)
  end

  def post_comment(season:, episode:, body:, item: show)
    post group_watchlist_item_comments_path(group, item), params: { season: season, episode: episode, body: body }
  end

  def discussion
    page_props.fetch("discussion")
  end

  describe "GET the watchlist item page" do
    it "sends readable comments and only counts for episodes beyond the viewer's progress" do
      watched(david, 1, 8)
      early = show.episode_comments.create!(user: david, season: 1, episode: 2, body: "The goats!")
      show.episode_comments.create!(user: david, season: 1, episode: 8, body: "Helly is the founder's daughter")
      show.episode_comments.create!(user: david, season: 1, episode: 8, body: "That cliffhanger")
      watched(larissa, 1, 4)
      sign_in(larissa)

      get group_watchlist_item_path(group, show)

      expect(response).to have_http_status(:ok)
      expect(discussion).to eq(
        "viewer_position" => { "season" => 1, "episode" => 4 },
        "max_body_length" => 1000,
        "episodes" => [
          { "season" => 1, "episode" => 2, "hidden_count" => 0, "comments" => [
            { "id" => early.id, "body" => "The goats!", "author" => { "id" => david.id, "display_name" => "David" },
              "created_at" => early.created_at.iso8601, "mine" => false, "can_delete" => false }
          ] },
          { "season" => 1, "episode" => 8, "hidden_count" => 2, "comments" => [] }
        ]
      )
      expect(response.body).not_to include("founder", "cliffhanger")
      expect(response.body).not_to include(david.email)
    end

    it "never includes hidden text in the HTML page or in Inertia's JSON visits" do
      watched(david, 2, 1)
      show.episode_comments.create!(user: david, season: 2, episode: 1, body: "Secret season two twist")
      sign_in(larissa)

      get group_watchlist_item_path(group, show)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("hidden_count")
      expect(response.body).not_to include("Secret season two twist")

      get group_watchlist_item_path(group, show),
        headers: { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s }
      expect(response.media_type).to eq("application/json")
      expect(response.body).not_to include("Secret season two twist")
      expect(response.parsed_body.dig("props", "discussion").to_json).not_to include("David")
      expect(response.parsed_body.dig("props", "discussion", "episodes")).to eq([
        { "season" => 2, "episode" => 1, "hidden_count" => 1, "comments" => [] }
      ])
    end

    it "lets owners delete anyone's visible comment and shows former members' comments without an author" do
      watched(larissa, 1, 1)
      watched(david, 1, 1)
      show.episode_comments.create!(user: larissa, season: 1, episode: 1, body: "Hi")
      gone = create_user(display_name: "Gone")
      group.memberships.create!(user: gone)
      watched(gone, 1, 1)
      show.episode_comments.create!(user: gone, season: 1, episode: 1, body: "Bye")
      gone.memberships.destroy_all
      gone.destroy!
      sign_in(david)

      get group_watchlist_item_path(group, show)

      comments = discussion["episodes"].first["comments"]
      expect(comments.map { |c| [ c["body"], c["author"]&.fetch("display_name"), c["can_delete"] ] })
        .to eq([ [ "Hi", "Larissa", true ], [ "Bye", nil, true ] ])
    end

    it "sends no discussion for movies" do
      movie = group.watchlist_items.create!(title: "Up", tmdb_id: 14_160, media_type: "movie")
      sign_in(david)

      get group_watchlist_item_path(group, movie)

      expect(page_props).not_to have_key("discussion")
    end
  end

  describe "POST create" do
    it "posts a comment on an episode the member has watched" do
      watched(larissa, 1, 4)
      sign_in(larissa)

      expect { post_comment(season: 1, episode: 3, body: "  Mark's office!  ") }.to change(EpisodeComment, :count).by(1)

      expect(response).to redirect_to(group_watchlist_item_path(group, show))
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Comment posted.")
      expect(EpisodeComment.last).to have_attributes(user: larissa, season: 1, episode: 3, body: "Mark's office!")
    end

    it "refuses comments beyond the member's own progress with a friendly error" do
      watched(larissa, 1, 4)
      sign_in(larissa)

      expect { post_comment(season: 1, episode: 5, body: "Spoiler") }.not_to change(EpisodeComment, :count)

      expect(response).to redirect_to(group_watchlist_item_path(group, show))
      follow_redirect!
      expect(page_props.dig("errors", "episode").first).to include("You're on S1 E4", "can't comment on S1 E5")
    end

    it "refuses comments from a member who has not watched anything" do
      sign_in(sam)

      expect { post_comment(season: 1, episode: 1, body: "Hi") }.not_to change(EpisodeComment, :count)
      follow_redirect!
      expect(page_props.dig("errors", "episode").first).to include("haven't marked any episodes")
    end

    it "explains blank, overly long, and invalid input" do
      watched(larissa, 1, 4)
      sign_in(larissa)

      post_comment(season: 1, episode: 1, body: "   ")
      follow_redirect!
      expect(page_props.dig("errors", "body")).to eq([ "Write something before posting." ])

      post_comment(season: 1, episode: 1, body: "a" * 1001)
      follow_redirect!
      expect(page_props.dig("errors", "body")).to eq([ "Keep comments to 1000 characters or fewer." ])

      post_comment(season: "", episode: "0", body: "Hi")
      follow_redirect!
      expect(page_props["errors"]).to include("season" => [ "Season must be a whole number of at least 1." ])
      expect(page_props.dig("errors", "episode")).to include("Episode must be a whole number of at least 1.")
      expect(EpisodeComment.count).to eq(0)
    end

    it "refuses discussion on movies" do
      movie = group.watchlist_items.create!(title: "Up", tmdb_id: 14_160, media_type: "movie")
      sign_in(larissa)

      expect { post_comment(item: movie, season: 1, episode: 1, body: "Hi") }.not_to change(EpisodeComment, :count)
      follow_redirect!
      expect(page_props.dig("errors", "base")).to eq([ "Discussion is only available for TV shows" ])
    end

    it "hides the show from outsiders" do
      sign_in(outsider)

      expect { post_comment(season: 1, episode: 1, body: "Hi") }.not_to change(EpisodeComment, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not find another group's show through this group" do
      other = Group.create_with_owner!(owner: larissa, name: "Other")
      other_show = other.watchlist_items.create!(title: "Andor")
      watched(larissa, 1, 1, item: other_show)
      sign_in(larissa)

      post group_watchlist_item_comments_path(group, other_show), params: { season: 1, episode: 1, body: "Hi" }

      expect(response).to have_http_status(:not_found)
      expect(EpisodeComment.count).to eq(0)
    end

    it "asks signed-out visitors to sign in" do
      post_comment(season: 1, episode: 1, body: "Hi")

      expect(response).to redirect_to(sign_in_path)
      expect(EpisodeComment.count).to eq(0)
    end

    it "limits how quickly one member can post" do
      watched(larissa, 1, 1)
      sign_in(larissa)

      31.times { post_comment(season: 1, episode: 1, body: "Spam") }

      expect(response).to have_http_status(:too_many_requests)
      expect(EpisodeComment.count).to eq(30)
    end
  end

  describe "DELETE destroy" do
    let!(:comment) do
      watched(larissa, 1, 1)
      show.episode_comments.create!(user: larissa, season: 1, episode: 1, body: "Mine")
    end

    it "lets the author delete their comment" do
      sign_in(larissa)

      expect { delete group_watchlist_item_comment_path(group, show, comment) }.to change(EpisodeComment, :count).by(-1)
      expect(response).to redirect_to(group_watchlist_item_path(group, show))
      expect(flash[:notice]).to eq("Comment deleted.")
    end

    it "lets a group owner delete any comment" do
      sign_in(david)

      expect { delete group_watchlist_item_comment_path(group, show, comment) }.to change(EpisodeComment, :count).by(-1)
    end

    it "stops other members from deleting someone else's comment" do
      sign_in(sam)

      expect { delete group_watchlist_item_comment_path(group, show, comment) }.not_to change(EpisodeComment, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "stops outsiders and signed-out visitors" do
      delete group_watchlist_item_comment_path(group, show, comment)
      expect(response).to redirect_to(sign_in_path)

      sign_in(outsider)
      delete group_watchlist_item_comment_path(group, show, comment)
      expect(response).to have_http_status(:not_found)
      expect(EpisodeComment.exists?(comment.id)).to be(true)
    end

    it "does not find a comment through another show" do
      other_show = group.watchlist_items.create!(title: "Andor")
      sign_in(larissa)

      delete group_watchlist_item_comment_path(group, other_show, comment)

      expect(response).to have_http_status(:not_found)
      expect(EpisodeComment.exists?(comment.id)).to be(true)
    end
  end
end
