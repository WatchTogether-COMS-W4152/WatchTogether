require "digest"

class Session < ApplicationRecord
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def self.issue!(user)
    token = SecureRandom.hex(32)
    session = create!(user: user, token_digest: Digest::SHA256.hexdigest(token),
      expires_at: 30.days.from_now)
    [ session, token ]
  end

  def self.authenticate(token)
    return unless token&.match?(/\A[a-f0-9]{64}\z/)

    where("expires_at > ?", Time.current)
      .find_by(token_digest: Digest::SHA256.hexdigest(token))
  end
end
