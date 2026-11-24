class AddSeasonLengthsToWatchlistItems < ActiveRecord::Migration[8.1]
  def change
    add_column :watchlist_items, :season_lengths, :json
    add_column :watchlist_items, :season_lengths_checked_at, :datetime
  end
end
