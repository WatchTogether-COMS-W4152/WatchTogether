class StreamingSubscription < ApplicationRecord
  belongs_to :user

  validates :provider_id, presence: true, inclusion: { in: StreamingService::IDS }, uniqueness: { scope: :user_id }
end
