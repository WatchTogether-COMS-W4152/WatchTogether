class WatchlistItem < ApplicationRecord
  include CatalogMetadata

  belongs_to :group
  belongs_to :source_suggestion, class_name: "Suggestion", optional: true
  has_many :episode_progresses, dependent: :delete_all
  has_many :episode_comments, dependent: :delete_all

  validates :title, presence: true, length: { maximum: 120 }, unless: :tmdb_id?
  validates :title, presence: true, length: { maximum: 500 }, if: :tmdb_id?
  validate :catalog_title_unique_in_group

  SEASON_LENGTHS_TTL = 1.day

  def episodic?
    media_type != "movie"
  end

  def season_lengths
    refresh_season_lengths if season_lengths_stale?
    self[:season_lengths]
  end

  def position_after(position)
    season, episode = position.values_at(:season, :episode)
    lengths = season_lengths
    return { season: season, episode: episode + 1 } unless lengths

    if episode < lengths.fetch(season - 1, 0)
      { season: season, episode: episode + 1 }
    elsif season < lengths.size
      { season: season + 1, episode: 1 }
    end
  end

  def group_progress(members: group.members.to_a)
    GroupProgress.new(self, members: members)
  end

  def next_group_episode(members: group.members.to_a)
    return unless episodic?

    progress = group_progress(members: members)
    progress.next_episode if progress.started?
  end

  private

  def season_lengths_stale?
    return false unless media_type == "tv" && tmdb_id && persisted? && !@season_lengths_refreshed

    season_lengths_checked_at.nil? || season_lengths_checked_at < SEASON_LENGTHS_TTL.ago
  end

  def refresh_season_lengths
    @season_lengths_refreshed = true
    update_columns(season_lengths: TmdbClient.new.season_lengths(tmdb_id), season_lengths_checked_at: Time.current)
  rescue TmdbClient::Error
    nil
  end

  def catalog_title_unique_in_group
    return unless tmdb_id && group_id
    return unless self.class.where(group_id: group_id, tmdb_id: tmdb_id, media_type: media_type).where.not(id: id).exists?

    errors.add(:title, "is already on this group's watchlist")
  end
end
