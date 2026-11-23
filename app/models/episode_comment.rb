class EpisodeComment < ApplicationRecord
  MAX_BODY_LENGTH = 1000

  belongs_to :watchlist_item
  belongs_to :user, optional: true

  normalizes :body, with: ->(body) { body.strip }

  validates :user, presence: true, on: :create
  validates :season, :episode, numericality: { only_integer: true, greater_than_or_equal_to: 1,
    message: ->(_comment, data) { "#{data[:attribute]} must be a whole number of at least 1." } }
  validates :body, presence: { message: "Write something before posting." },
    length: { maximum: MAX_BODY_LENGTH, message: "Keep comments to #{MAX_BODY_LENGTH} characters or fewer." }
  validate :author_belongs_to_group, on: :create
  validate :watchlist_item_is_episodic, on: :create
  validate :author_has_reached_episode, on: :create

  scope :in_episode_order, -> { order(:season, :episode, :created_at, :id) }

  scope :up_to, ->(position) {
    where("season < :season OR (season = :season AND episode <= :episode)", position.slice(:season, :episode))
  }

  def self.visible_to(user, item)
    comments = item.episode_comments.where(user: user)
    progress = progress_for(user, item)
    comments = comments.or(item.episode_comments.up_to(progress.position)) if progress
    comments.in_episode_order
  end

  def self.hidden_counts_for(user, item)
    item.episode_comments
      .where.not(id: visible_to(user, item).select(:id))
      .group(:season, :episode)
      .order(:season, :episode)
      .count
      .map { |(season, episode), count| { season: season, episode: episode, count: count } }
  end

  def self.progress_for(user, item)
    item.episode_progresses.find_by(user: user)
  end

  def self.label(position)
    "S#{position.fetch(:season)} E#{position.fetch(:episode)}"
  end

  def position
    { season: season, episode: episode }
  end

  def deletable_by?(user, group_owner: false)
    group_owner || (user_id.present? && user_id == user&.id)
  end

  private

  def author_belongs_to_group
    return unless watchlist_item && user
    return if watchlist_item.group.memberships.exists?(user_id: user_id)

    errors.add(:user, "must be a member of the group")
  end

  def watchlist_item_is_episodic
    return unless watchlist_item
    return if watchlist_item.episodic?

    errors.add(:base, "Discussion is only available for TV shows")
  end

  def author_has_reached_episode
    return unless watchlist_item && user && season.is_a?(Integer) && episode.is_a?(Integer)

    progress = self.class.progress_for(user, watchlist_item)
    return if progress&.reached?(season: season, episode: episode)

    where_you_are = progress ? "You're on #{self.class.label(progress.position)}, so" : "You haven't marked any episodes as watched yet, so"
    errors.add(:episode, "#{where_you_are} you can't comment on #{self.class.label(position)}. " \
      "Comment on an episode you've watched, or update your progress first.")
  end
end
