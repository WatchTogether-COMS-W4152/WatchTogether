class MoveGroupOwnershipToMemberships < ActiveRecord::Migration[8.1]
  def up
    add_column :memberships, :role, :string, null: false, default: "member"
    add_check_constraint :memberships, "role IN ('member', 'owner')", name: "memberships_role_check"

    # Preserve existing owners, including any legacy group missing its owner membership.
    execute <<~SQL
      UPDATE memberships SET role = 'owner'
      WHERE EXISTS (
        SELECT 1 FROM groups
        WHERE groups.id = memberships.group_id AND groups.owner_id = memberships.user_id
      )
    SQL
    execute <<~SQL
      INSERT INTO memberships (group_id, user_id, role, created_at, updated_at)
      SELECT groups.id, groups.owner_id, 'owner', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM groups
      WHERE NOT EXISTS (
        SELECT 1 FROM memberships
        WHERE memberships.group_id = groups.id AND memberships.user_id = groups.owner_id
      )
    SQL

    remove_reference :groups, :owner, foreign_key: { to_table: :users }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Multiple owners cannot be represented by a single owner_id."
  end
end
