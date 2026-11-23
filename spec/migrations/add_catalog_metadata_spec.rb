require "rails_helper"
require Rails.root.join("db/migrate/20261116000000_add_catalog_metadata")

RSpec.describe AddCatalogMetadata do
  # These examples own a separate in-memory database and exercise the real
  # migrator's transaction boundaries, so fixture transactions must not wrap it.
  self.use_transactional_tests = false

  it "upgrades a populated legacy database without losing titles, votes, or watched progress" do
    # Exercise the actual upgrade, not just the generated schema, on an isolated connection.
    stub_const("CatalogMigrationTestRecord", Class.new(ActiveRecord::Base) { self.abstract_class = true })
    CatalogMigrationTestRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:migration_class).and_return(CatalogMigrationTestRecord)
    CatalogMigrationTestRecord.connection_pool.with_connection do |connection|
      context = CatalogMigrationTestRecord.connection_pool.migration_context
      described_class.suppress_messages { context.migrate(20261110003700) }
      connection.execute <<~SQL
        INSERT INTO users (id, display_name, email, password_digest, created_at, updated_at)
        VALUES (1, 'Alice', 'alice@example.com', 'existing digest', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.execute <<~SQL
        INSERT INTO groups (id, name, invite_code, created_at, updated_at)
        VALUES (1, 'Friday films', 'AAAAAAAAAAAAAAAA', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.execute <<~SQL
        INSERT INTO suggestions (id, group_id, suggested_by_id, title, title_key, created_at, updated_at)
        VALUES (1, 1, 1, 'Dune', 'dune', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.execute <<~SQL
        INSERT INTO votes (id, suggestion_id, user_id, rating, created_at, updated_at)
        VALUES (1, 1, 1, 'love', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.execute <<~SQL
        INSERT INTO watchlist_items (id, group_id, title, watched, created_at, updated_at) VALUES
        (1, 1, 'Dune', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        (2, 1, 'Dune', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      originals = %w[suggestions votes watchlist_items].to_h do |table|
        [ table, connection.select_all("SELECT * FROM #{table} ORDER BY id").to_a ]
      end

      described_class.suppress_messages { context.migrate(20261116000000) }

      expect(context.current_version).to eq(20261116000000)
      expect(connection.select_value("PRAGMA foreign_keys")).to eq(1)
      expect(connection.select_rows("PRAGMA foreign_key_check")).to eq([])

      originals.each do |table, rows|
        columns = rows.first.keys.join(", ")
        expect(connection.select_all("SELECT #{columns} FROM #{table} ORDER BY id").to_a).to eq(rows)
      end
      %w[suggestions watchlist_items].each do |table|
        expect(connection.select_rows("SELECT tmdb_id, media_type, overview, release_year, tmdb_rating, age_rating, poster_path FROM #{table}"))
          .to all(eq([ nil ] * 7))
      end

      # The new partial title index keeps manual uniqueness while permitting adaptations.
      expect {
        connection.execute <<~SQL
          INSERT INTO suggestions (group_id, title, title_key, created_at, updated_at)
          VALUES (1, 'DUNE', 'dune', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      }.to raise_error(ActiveRecord::RecordNotUnique)
      connection.execute <<~SQL
        INSERT INTO suggestions (id, group_id, title, title_key, tmdb_id, media_type, created_at, updated_at) VALUES
        (2, 1, 'Dune', 'dune', 10, 'movie', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        (3, 1, 'Dune', 'dune', 11, 'movie', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        (4, 1, 'Dune', 'dune', 10, 'tv', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      expect {
        connection.execute <<~SQL
          INSERT INTO suggestions (group_id, title, title_key, tmdb_id, media_type, created_at, updated_at)
          VALUES (1, 'Renamed movie', 'renamed movie', 10, 'movie', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      }.to raise_error(ActiveRecord::RecordNotUnique)

      # Both the old vote cascade and new watchlist nullification must survive the upgrade.
      connection.execute("UPDATE watchlist_items SET source_suggestion_id = 1 WHERE id = 1")
      connection.execute("DELETE FROM suggestions WHERE id = 1")
      expect(connection.select_value("SELECT COUNT(*) FROM votes")).to eq(0)
      expect(connection.select_rows("SELECT id, title, watched, source_suggestion_id FROM watchlist_items ORDER BY id"))
        .to eq([ [ 1, "Dune", 1, nil ], [ 2, "Dune", 0, nil ] ])
    end
  ensure
    CatalogMigrationTestRecord.remove_connection
  end

  it "rolls back the whole upgrade and restores foreign-key enforcement when a later schema change fails" do
    stub_const("CatalogMigrationTestRecord", Class.new(ActiveRecord::Base) { self.abstract_class = true })
    CatalogMigrationTestRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:migration_class).and_return(CatalogMigrationTestRecord)
    CatalogMigrationTestRecord.connection_pool.with_connection do |connection|
      context = CatalogMigrationTestRecord.connection_pool.migration_context
      described_class.suppress_messages { context.migrate(20261110003700) }
      # Fail near the end, after columns, constraints, and indexes have changed.
      allow(connection).to receive(:add_reference).and_raise("planned schema failure")

      expect {
        described_class.suppress_messages { context.migrate(20261116000000) }
      }.to raise_error(StandardError, /planned schema failure/)

      expect(context.current_version).to eq(20261110003700)
      expect(connection.column_exists?(:suggestions, :tmdb_id)).to be(false)
      expect(connection.column_exists?(:watchlist_items, :tmdb_id)).to be(false)
      title_index = connection.indexes(:suggestions).find { |index| index.columns == %w[group_id title_key] }
      expect(title_index).to have_attributes(unique: true, where: nil)
      expect(connection.select_value("PRAGMA foreign_keys")).to eq(1)
      expect(connection.select_rows("PRAGMA foreign_key_check")).to eq([])
    end
  ensure
    CatalogMigrationTestRecord.remove_connection
  end
end
