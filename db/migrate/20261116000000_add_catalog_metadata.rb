class AddCatalogMetadata < ActiveRecord::Migration[8.1]
  # SQLite rebuilds suggestions to add the check constraint. Its foreign-key
  # switch must happen before the transaction, or dropping the old table can
  # cascade into votes. Keep the entire upgrade atomic with our own transaction.
  disable_ddl_transaction!

  def exec_migration(conn, direction)
    migrate_atomically = lambda do
      conn.transaction do
        super(conn, direction)
        conn.check_all_foreign_keys_valid! if conn.adapter_name == "SQLite"
      end
    end

    if conn.adapter_name == "SQLite"
      conn.disable_referential_integrity(&migrate_atomically)
    else
      migrate_atomically.call
    end
  end

  def change
    [ :suggestions, :watchlist_items ].each do |table|
      add_column table, :tmdb_id, :bigint
      add_column table, :media_type, :string
      add_column table, :overview, :text
      add_column table, :release_year, :integer
      add_column table, :tmdb_rating, :float
      add_column table, :age_rating, :string
      add_column table, :poster_path, :string
      add_index table, [ :group_id, :media_type, :tmdb_id ], unique: true, where: "tmdb_id IS NOT NULL"
      add_check_constraint table,
        "(tmdb_id IS NULL AND media_type IS NULL) OR (tmdb_id IS NOT NULL AND tmdb_id > 0 AND media_type IS NOT NULL AND media_type IN ('movie', 'tv'))",
        name: "#{table}_catalog_identity_check"
    end
    remove_index :suggestions, [ :group_id, :title_key ], unique: true
    add_index :suggestions, [ :group_id, :title_key ], unique: true, where: "tmdb_id IS NULL"
    add_reference :watchlist_items, :source_suggestion, foreign_key: { to_table: :suggestions, on_delete: :nullify }, index: { unique: true }
  end
end
