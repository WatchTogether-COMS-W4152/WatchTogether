require "rails_helper"

RSpec.describe Membership, type: :model do
  let(:owner) { create_user }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Movie night") }

  it "requires a user and group" do
    membership = Membership.new

    expect(membership).not_to be_valid
    expect(membership.errors).to include(:user, :group)
  end

  it "defaults to an ordinary member and accepts only the two supported roles" do
    membership = group.memberships.build(user: create_user)
    expect(membership.role).to eq("member")
    expect(membership).to be_member
    [ nil, "admin", "" ].each do |role|
      membership.role = role
      expect(membership).not_to be_valid
      expect(membership.errors[:role]).not_to be_empty
    end
    membership.role = "owner"
    expect(membership).to be_valid
    expect(membership).to be_owner
  end

  it "enforces supported and non-null roles in the database" do
    membership = group.memberships.build(user: create_user, role: "admin")
    expect {
      Membership.transaction(requires_new: true) { membership.save!(validate: false) }
    }.to raise_error(ActiveRecord::StatementInvalid)

    membership.role = nil
    expect {
      Membership.transaction(requires_new: true) { membership.save!(validate: false) }
    }.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "prevents duplicate memberships" do
    duplicate = group.memberships.build(user: owner)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to include("has already been taken")
  end

  it "enforces uniqueness at the database for concurrent joins" do
    duplicate = group.memberships.build(user: owner)

    expect {
      Membership.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows a user to belong to several groups" do
    first = group
    second = Group.create_with_owner!(owner: owner, name: "Weekend films")

    expect(owner.groups).to contain_exactly(first, second)
  end

  it "enforces required associations and foreign keys in the database" do
    missing_user = Membership.new(group: group)
    invalid_user = Membership.new(group: group, user_id: User.maximum(:id) + 1)

    expect {
      Membership.transaction(requires_new: true) { missing_user.save!(validate: false) }
    }.to raise_error(ActiveRecord::NotNullViolation)
    expect {
      Membership.transaction(requires_new: true) { invalid_user.save!(validate: false) }
    }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
