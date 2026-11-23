# Where each current member of a group is in a show, and the next episode the
# whole group can watch together. Progress saved by people who have since left
# the group is ignored.
class GroupProgress
  FIRST_EPISODE = { season: 1, episode: 1 }.freeze

  Entry = Data.define(:user, :position, :caught_up) do
    def started?
      !position.nil?
    end
  end

  # Pass `members:` to reuse an already loaded member list across several items.
  def initialize(watchlist_item, members: watchlist_item.group.members.to_a)
    @members = members
    member_ids = members.to_set(&:id)
    @positions = watchlist_item.episode_progresses
      .select { |progress| member_ids.include?(progress.user_id) }
      .to_h { |progress| [ progress.user_id, progress.position ] }
  end

  # Members ordered furthest ahead first; members who have not started come last.
  # Ties are ordered by display name.
  def entries
    @entries ||= @members
      .map { |user| Entry.new(user: user, position: @positions[user.id], caught_up: caught_up?(@positions[user.id])) }
      .sort { |a, b| compare_entries(a, b) }
  end

  # The furthest position any member has reached, or nil if nobody has started.
  def furthest
    @positions.values.max { |a, b| EpisodeProgress.compare(a, b) }
  end

  # The episode after the one the member furthest behind has watched. If anyone
  # has not started, the group starts at the beginning. Season lengths are not
  # known, so the next episode always stays within the same season.
  def next_episode
    return FIRST_EPISODE if @members.empty? || @positions.size < @members.size

    behind = @positions.values.min { |a, b| EpisodeProgress.compare(a, b) }
    { season: behind[:season], episode: behind[:episode] + 1 }
  end

  def started?
    @positions.any?
  end

  # True when every member has started and they are all at the same episode.
  def everyone_caught_up?
    @members.any? && entries.all?(&:caught_up)
  end

  private

  def caught_up?(position)
    !position.nil? && EpisodeProgress.compare(position, furthest).zero?
  end

  def compare_entries(a, b)
    if a.started? != b.started?
      a.started? ? -1 : 1
    elsif a.started? && (order = EpisodeProgress.compare(b.position, a.position)).nonzero?
      order
    else
      a.user.display_name.casecmp(b.user.display_name)
    end
  end
end
