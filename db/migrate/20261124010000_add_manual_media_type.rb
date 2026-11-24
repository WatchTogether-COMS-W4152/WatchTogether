class AddManualMediaType < ActiveRecord::Migration[8.1]
  def change
    add_column :watchlist_items, :manual_media_type, :string
    add_column :suggestions, :manual_media_type, :string
  end
end
