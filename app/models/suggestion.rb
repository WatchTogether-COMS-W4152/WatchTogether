class Suggestion < ApplicationRecord
  belongs_to :group
  belongs_to :suggested_by, class_name: "User", optional: true
  has_many :votes, dependent: :delete_all

  normalizes :title, with: ->(title) { title.squish }

  validates :title, presence: true, length: { maximum: 120 }
  validate :title_unique_in_group

  scope :for_group, ->(group) { where(group: group) }

  # Ranks a group's suggestions by the summed score of current members' votes.
  # Each row also carries score, love_count, votes_count and viewer_rating.
  def self.ranked_for(group, viewer:)
    score_cases = Vote::SCORES.map { |rating, points| "WHEN #{connection.quote(rating)} THEN #{Integer(points)}" }.join(" ")
    member_votes_join = <<~SQL.squish
      LEFT JOIN votes member_votes ON member_votes.suggestion_id = suggestions.id
        AND EXISTS (
          SELECT 1 FROM memberships
          WHERE memberships.group_id = suggestions.group_id AND memberships.user_id = member_votes.user_id
        )
    SQL
    viewer_vote_join = sanitize_sql_array([
      "LEFT JOIN votes viewer_votes ON viewer_votes.suggestion_id = suggestions.id AND viewer_votes.user_id = ?",
      viewer.id
    ])

    for_group(group)
      .joins(member_votes_join)
      .joins(viewer_vote_join)
      .group("suggestions.id")
      .select(
        "suggestions.*",
        "COALESCE(SUM(CASE member_votes.rating #{score_cases} END), 0) AS score",
        "COUNT(CASE WHEN member_votes.rating = 'love' THEN 1 END) AS love_count",
        "COUNT(member_votes.id) AS votes_count",
        "MAX(viewer_votes.rating) AS viewer_rating"
      )
      .order(Arel.sql("score DESC, love_count DESC, suggestions.created_at ASC, suggestions.id ASC"))
      .preload(:suggested_by)
  end

  def self.title_key_for(title)
    title.to_s.squish.downcase
  end

  def title=(value)
    super
    self.title_key = self.class.title_key_for(title)
  end

  private

  def title_unique_in_group
    return if title_key.blank? || group_id.nil?
    return unless self.class.for_group(group_id).where(title_key: title_key).where.not(id: id).exists?

    errors.add(:title, "has already been suggested in this group")
  end
end
