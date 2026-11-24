module WatchlistItems
  module ProgressProps
    private

    def progress_props(item)
      return {} unless item.episodic?

      progress = item.group_progress
      mine = progress.entries.find { |entry| entry.user.id == current_user.id }

      {
        episode_progress: {
          members: progress.entries.map do |entry|
            {
              id: entry.user.id,
              display_name: entry.user.display_name,
              position: entry.position,
              caught_up: entry.caught_up
            }
          end,
          my_position: mine&.position,
          my_next_episode: mine&.position ? item.position_after(mine.position) : GroupProgress::FIRST_EPISODE,
          next_episode: progress.next_episode,
          finished: progress.finished?,
          season_lengths: item.season_lengths,
          everyone_caught_up: progress.everyone_caught_up?
        }
      }
    end
  end
end
