class CreateSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :suggestions do |t|
      t.references :group, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :suggested_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :title, null: false
      t.string :title_key, null: false
      t.timestamps
    end
    add_index :suggestions, [ :group_id, :title_key ], unique: true
  end
end
