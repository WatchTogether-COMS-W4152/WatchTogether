# The last episode a member has watched of a show on their group's watchlist.
class EpisodeProgress < ApplicationRecord
  belongs_to :watchlist_item
  belongs_to :user

  validates :season, :episode, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :user_id, uniqueness: { scope: :watchlist_item_id }
  validate :user_belongs_to_group
  validate :watchlist_item_is_episodic

  # Positions compare season first, then episode: S1E10 is before S2E1.
  def self.compare(a, b)
    [ a.fetch(:season), a.fetch(:episode) ] <=> [ b.fetch(:season), b.fetch(:episode) ]
  end

  def position
    { season: season, episode: episode }
  end

  # True when this member has watched up to (and including) the given episode.
  def reached?(season:, episode:)
    self.class.compare(position, { season: season, episode: episode }) >= 0
  end

  private

  def user_belongs_to_group
    return unless watchlist_item && user
    return if watchlist_item.group.memberships.exists?(user_id: user_id)

    errors.add(:user, "must be a member of the group")
  end

  def watchlist_item_is_episodic
    return unless watchlist_item
    return if watchlist_item.episodic?

    errors.add(:watchlist_item, "must be a TV show")
  end
end
