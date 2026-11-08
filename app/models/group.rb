class Group < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :owned_groups
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user

  normalizes :name, with: ->(name) { name.strip }
  before_validation :set_invite_code, on: :create

  validates :name, presence: true, length: { maximum: 80 }
  validates :invite_code, presence: true, uniqueness: true,
    format: { with: /\A[A-F0-9]{16}\z/ }

  def self.create_with_owner!(owner:, name:)
    transaction do
      group = create!(owner: owner, name: name)
      group.memberships.create!(user: owner)
      group
    end
  end

  def reset_invitation!
    with_lock { update!(invite_code: SecureRandom.hex(8).upcase) }
  end

  private

  def set_invite_code
    self.invite_code ||= SecureRandom.hex(8).upcase
  end
end
