class Vote < ApplicationRecord
  SCORES = { "love" => 2, "maybe" => 1, "not_interested" => -2 }.freeze

  belongs_to :suggestion
  belongs_to :user

  enum :rating, { love: "love", maybe: "maybe", not_interested: "not_interested" }, validate: true
  validates :user_id, uniqueness: { scope: :suggestion_id }
  validate :user_belongs_to_group

  private

  def user_belongs_to_group
    return unless suggestion && user
    return if Membership.exists?(group_id: suggestion.group_id, user_id: user_id)

    errors.add(:user, "must be a member of this group")
  end
end
