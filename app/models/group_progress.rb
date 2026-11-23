class GroupProgress
  FIRST_EPISODE = { season: 1, episode: 1 }.freeze

  Entry = Data.define(:user, :position, :caught_up) do
    def started?
      !position.nil?
    end
  end

  def initialize(watchlist_item, members: watchlist_item.group.members.to_a)
    @members = members
    member_ids = members.to_set(&:id)
    @positions = watchlist_item.episode_progresses
      .select { |progress| member_ids.include?(progress.user_id) }
      .to_h { |progress| [ progress.user_id, progress.position ] }
  end

  def entries
    @entries ||= @members
      .map { |user| Entry.new(user: user, position: @positions[user.id], caught_up: caught_up?(@positions[user.id])) }
      .sort { |a, b| compare_entries(a, b) }
  end

  def furthest
    @positions.values.max { |a, b| EpisodeProgress.compare(a, b) }
  end

  def next_episode
    return FIRST_EPISODE if @members.empty? || @positions.size < @members.size

    behind = @positions.values.min { |a, b| EpisodeProgress.compare(a, b) }
    { season: behind[:season], episode: behind[:episode] + 1 }
  end

  def started?
    @positions.any?
  end

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
