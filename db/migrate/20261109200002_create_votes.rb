class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.references :suggestion, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :rating, null: false
      t.timestamps
    end
    add_index :votes, [ :suggestion_id, :user_id ], unique: true
    add_check_constraint :votes, "rating IN ('love', 'maybe', 'not_interested')", name: "votes_rating_check"
  end
end
