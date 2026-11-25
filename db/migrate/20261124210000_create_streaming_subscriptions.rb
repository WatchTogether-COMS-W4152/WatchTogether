class CreateStreamingSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :streaming_subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :provider_id, null: false
      t.timestamps
    end

    add_index :streaming_subscriptions, [ :user_id, :provider_id ], unique: true,
      name: "index_streaming_subscriptions_on_user_id_and_provider_id"
    add_check_constraint :streaming_subscriptions,
      "provider_id IN (8, 9, 15, 283, 337, 350, 386, 531, 1899)",
      name: "streaming_subscriptions_provider_id_check"
  end
end
