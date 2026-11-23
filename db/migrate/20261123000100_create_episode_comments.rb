class CreateEpisodeComments < ActiveRecord::Migration[8.1]
  def change
    create_table :episode_comments do |t|
      t.references :watchlist_item, null: false, index: false, foreign_key: { on_delete: :cascade }
      # Comments outlive a deleted account (the author shows as a former member),
      # like suggestions do, so the rest of the group's conversation still reads well.
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.integer :season, null: false
      t.integer :episode, null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :episode_comments, [ :watchlist_item_id, :season, :episode, :created_at ],
      name: "index_episode_comments_on_item_and_position"
    add_check_constraint :episode_comments, "season >= 1 AND episode >= 1", name: "episode_comments_position_check"
    add_check_constraint :episode_comments, "length(body) BETWEEN 1 AND 1000", name: "episode_comments_body_length_check"
  end
end
