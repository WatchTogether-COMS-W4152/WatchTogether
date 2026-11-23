module DiscussionHelpers
  def watchlist_item_path(title, group_name)
    "#{watchlist_path(group_name)}/#{watchlist_item_id(title, group_name)}"
  end

  def comments_path(title, group_name)
    "#{watchlist_item_path(title, group_name)}/comments"
  end

  def episode_label(season, episode)
    "S#{season} E#{episode}"
  end

  def discussion_episodes
    expect(@page.fetch("component")).to eq("watchlist_items/show")
    props.fetch("discussion").fetch("episodes")
  end

  def discussion_entry(label)
    discussion_episodes.find { |entry| episode_label(entry.fetch("season"), entry.fetch("episode")) == label }
  end

  def comment_id(body, title, group_name)
    EpisodeComment.find_by!(watchlist_item_id: watchlist_item_id(title, group_name), body: body).id
  end
end

World(DiscussionHelpers)
