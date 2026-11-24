class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  enum :role, { member: "member", owner: "owner" }, validate: true
  validates :user_id, uniqueness: { scope: :group_id }

  after_destroy :forget_group_activity

  private

  def forget_group_activity
    EpisodeProgress.where(user_id: user_id, watchlist_item_id: WatchlistItem.where(group_id: group_id).select(:id)).delete_all
    Vote.where(user_id: user_id, suggestion_id: Suggestion.where(group_id: group_id).select(:id)).delete_all
  end
end
