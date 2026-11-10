class WatchlistItem < ApplicationRecord
  belongs_to :group

  validates :title, presence: true, length: { maximum: 120 }
end
