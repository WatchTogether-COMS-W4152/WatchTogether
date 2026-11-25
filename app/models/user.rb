class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :streaming_subscriptions, dependent: :destroy
  has_many :ownerships, -> { where(role: "owner") }, class_name: "Membership", dependent: :restrict_with_error
  has_many :owned_groups, through: :ownerships, source: :group
  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :display_name, with: ->(name) { name.gsub(/[\u200B-\u200D\u2060\uFEFF]/, "").gsub(/\A[[:space:]]+|[[:space:]]+\z/, "") }

  validates :display_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :password_not_blank

  def replace_streaming_services!(raw_ids)
    ids = Array(raw_ids).filter_map { |value| Integer(value, exception: false) }.uniq
    ids.select! { |id| StreamingService.allowed?(id) }

    transaction do
      if ids.empty?
        streaming_subscriptions.delete_all
      else
        streaming_subscriptions.where.not(provider_id: ids).delete_all
        ids.each { |id| streaming_subscriptions.find_or_create_by!(provider_id: id) }
      end
    end
  end

  private

  def password_not_blank
    errors.add(:password, "can't be only spaces") if password && password.strip.empty?
  end
end
