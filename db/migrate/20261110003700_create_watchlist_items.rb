class CreateWatchlistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :watchlist_items do |t|
      t.references :group, null: false, foreign_key: true
      t.string :title, null: false
      t.boolean :watched, null: false, default: false

      t.timestamps
    end
  end
end
