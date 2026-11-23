module WatchlistItems
  module DiscussionProps
    private

    def discussion_props(item)
      return {} unless item.episodic?

      is_owner = item.group.owner?(current_user)
      progress = EpisodeComment.progress_for(current_user, item)
      visible = EpisodeComment.visible_to(current_user, item).includes(:user)
      episodes = Hash.new { |hash, position| hash[position] = { comments: [], hidden_count: 0 } }

      visible.each { |comment| episodes[[ comment.season, comment.episode ]][:comments] << comment_json(comment, is_owner) }
      EpisodeComment.hidden_counts_for(current_user, item).each do |hidden|
        episodes[[ hidden[:season], hidden[:episode] ]][:hidden_count] = hidden[:count]
      end

      {
        discussion: {
          viewer_position: progress&.position,
          max_body_length: EpisodeComment::MAX_BODY_LENGTH,
          episodes: episodes.sort.map { |(season, episode), entry| { season: season, episode: episode, **entry } }
        }
      }
    end

    def comment_json(comment, is_owner)
      {
        id: comment.id,
        body: comment.body,
        author: comment.user && { id: comment.user.id, display_name: comment.user.display_name },
        created_at: comment.created_at.iso8601,
        mine: comment.user_id == current_user.id,
        can_delete: comment.deletable_by?(current_user, group_owner: is_owner)
      }
    end
  end
end
