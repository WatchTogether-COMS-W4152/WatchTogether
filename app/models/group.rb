class Group < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :watchlist_items, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :owner_memberships, -> { where(role: "owner") }, class_name: "Membership"
  has_many :owners, through: :owner_memberships, source: :user

  normalizes :name, with: ->(name) { name.strip }
  before_validation :set_invite_code, on: :create

  validates :name, presence: true, length: { maximum: 80 }
  validates :invite_code, presence: true, uniqueness: true,
    format: { with: /\A[A-F0-9]{16}\z/ }

  def self.create_with_owner!(owner:, name:)
    transaction do
      group = create!(name: name)
      group.memberships.create!(user: owner, role: "owner")
      group
    end
  end

  def owner?(user)
    memberships.exists?(user: user, role: "owner")
  end

  def reset_invitation!
    with_lock { update!(invite_code: SecureRandom.hex(8).upcase) }
  end

  private

  def set_invite_code
    self.invite_code ||= SecureRandom.hex(8).upcase
  end
end
