class CreateEpisodeProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :episode_progresses do |t|
      t.references :watchlist_item, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :season, null: false
      t.integer :episode, null: false
      t.timestamps
    end
    add_index :episode_progresses, [ :watchlist_item_id, :user_id ], unique: true
    add_check_constraint :episode_progresses, "season >= 1 AND episode >= 1", name: "episode_progresses_position_check"
  end
end
