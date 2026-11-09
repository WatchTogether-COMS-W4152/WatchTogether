class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  enum :role, { member: "member", owner: "owner" }, validate: true
  validates :user_id, uniqueness: { scope: :group_id }
end
