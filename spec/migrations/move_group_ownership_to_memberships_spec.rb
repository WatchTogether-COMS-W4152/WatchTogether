require "rails_helper"
require Rails.root.join("db/migrate/20261108000001_create_users")
require Rails.root.join("db/migrate/20261108000003_create_groups")
require Rails.root.join("db/migrate/20261108000004_create_memberships")
require Rails.root.join("db/migrate/20261109000001_move_group_ownership_to_memberships")

RSpec.describe MoveGroupOwnershipToMemberships do
  it "preserves existing data and repairs missing owner memberships in an isolated legacy database" do
    # Use a separate connection so this schema change cannot alter the suite's database.
    stub_const("MigrationTestRecord", Class.new(ActiveRecord::Base) { self.abstract_class = true })
    MigrationTestRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    MigrationTestRecord.connection_pool.with_connection do |connection|
      [ CreateUsers, CreateGroups, CreateMemberships ].each do |migration_class|
        migration = migration_class.new
        migration.suppress_messages { migration.exec_migration(connection, :up) }
      end
      connection.execute <<~SQL
        INSERT INTO users (id, display_name, email, password_digest, created_at, updated_at) VALUES
        (1, 'Alice', 'alice@example.com', 'existing digest', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        (2, 'Bob', 'bob@example.com', 'existing digest', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        (3, 'Charlie', 'charlie@example.com', 'existing digest', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.execute <<~SQL
        INSERT INTO groups (id, name, owner_id, invite_code, created_at, updated_at) VALUES
        (1, 'Friday films', 1, 'AAAAAAAAAAAAAAAA', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        (2, 'Legacy group', 3, 'BBBBBBBBBBBBBBBB', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.execute <<~SQL
        INSERT INTO memberships (group_id, user_id, created_at, updated_at) VALUES
        (1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        (1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      migration = described_class.new
      migration.suppress_messages { migration.exec_migration(connection, :up) }

      expect(connection.select_rows("SELECT group_id, user_id, role FROM memberships ORDER BY group_id, user_id")).to eq(
        [ [ 1, 1, "owner" ], [ 1, 2, "member" ], [ 2, 3, "owner" ] ]
      )
      expect(connection.select_value("SELECT COUNT(*) FROM users")).to eq(3)
      expect(connection.select_rows("SELECT id, name, invite_code FROM groups ORDER BY id")).to eq(
        [ [ 1, "Friday films", "AAAAAAAAAAAAAAAA" ], [ 2, "Legacy group", "BBBBBBBBBBBBBBBB" ] ]
      )
      expect(connection.column_exists?(:groups, :owner_id)).to be(false)
      expect(connection.index_exists?(:memberships, [ :group_id, :user_id ], unique: true)).to be(true)
      expect(connection.foreign_key_exists?(:memberships, :groups)).to be(true)
      expect(connection.foreign_key_exists?(:memberships, :users)).to be(true)
    end
  ensure
    MigrationTestRecord.remove_connection
  end
end
