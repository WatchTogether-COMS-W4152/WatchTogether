class WatchlistItem < ApplicationRecord
  include CatalogMetadata

  belongs_to :group
  belongs_to :source_suggestion, class_name: "Suggestion", optional: true
  has_many :episode_progresses, dependent: :delete_all
  has_many :episode_comments, dependent: :delete_all

  validates :title, presence: true, length: { maximum: 120 }, unless: :tmdb_id?
  validates :title, presence: true, length: { maximum: 500 }, if: :tmdb_id?
  validate :catalog_title_unique_in_group

  def episodic?
    media_type != "movie"
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

  def catalog_title_unique_in_group
    return unless tmdb_id && group_id
    return unless self.class.where(group_id: group_id, tmdb_id: tmdb_id, media_type: media_type).where.not(id: id).exists?

    errors.add(:title, "is already on this group's watchlist")
  end
end
