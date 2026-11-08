class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :ownerships, -> { where(role: "owner") }, class_name: "Membership", dependent: :restrict_with_error
  has_many :owned_groups, through: :ownerships, source: :group
  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :display_name, with: ->(name) { name.strip }

  validates :display_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
end
