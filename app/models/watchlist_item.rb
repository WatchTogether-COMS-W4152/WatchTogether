class WatchlistItem < ApplicationRecord
  include CatalogMetadata

  belongs_to :group
  belongs_to :source_suggestion, class_name: "Suggestion", optional: true
  has_many :episode_progresses, dependent: :delete_all
  has_many :episode_comments, dependent: :delete_all

  normalizes :title, with: ->(title) { title.squish }

  validates :title, presence: true, length: { maximum: 120 }, unless: :tmdb_id?
  validates :title, presence: true, length: { maximum: 500 }, if: :tmdb_id?
  validate :catalog_title_unique_in_group

  SEASON_LENGTHS_TTL = 1.day

  scope :manual_titled, ->(title) { where(tmdb_id: nil).where("LOWER(title) = ?", title.to_s.squish.downcase) }
  scope :episodic, -> { where("COALESCE(media_type, manual_media_type, 'tv') != 'movie'") }

  def episodic?
    (media_type || manual_media_type) != "movie"
  end

  def season_lengths
    refresh_season_lengths if season_lengths_stale?
    self[:season_lengths]
  end

  def position_error(season:, episode:)
    lengths = season_lengths
    return unless lengths && season >= 1 && episode >= 1

    if season > lengths.size
      [ :season, "This show has #{ActionController::Base.helpers.pluralize(lengths.size, "season")}." ]
    elsif episode > lengths[season - 1]
      [ :episode, "Season #{season} has #{ActionController::Base.helpers.pluralize(lengths[season - 1], "episode")}." ]
    end
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
    return unless group_id

    others = self.class.where(group_id: group_id).where.not(id: id)
    others = tmdb_id ? others.where(tmdb_id: tmdb_id, media_type: media_type) : others.manual_titled(title)
    return unless others.exists?

    errors.add(:title, "is already on this group's watchlist")
  end
end
