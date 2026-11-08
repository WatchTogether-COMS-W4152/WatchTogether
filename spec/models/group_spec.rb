require "rails_helper"

RSpec.describe Group, type: :model do
  let(:owner) { create_user }

  it "creates a private group and owner membership together" do
    group = Group.create_with_owner!(owner: owner, name: " Movie night ")

    expect(group.name).to eq("Movie night")
    expect(group.owner).to eq(owner)
    expect(group.members).to contain_exactly(owner)
    expect(group.invite_code).to match(/\A[A-F0-9]{16}\z/)
  end

  it "rejects blank and overlong names without creating any membership" do
    [ " ", "a" * 81 ].each do |name|
      expect {
        Group.create_with_owner!(owner: owner, name: name)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
    expect(Group.count).to eq(0)
    expect(Membership.count).to eq(0)
  end

  it "rolls back the group if its owner membership cannot be saved" do
    allow_any_instance_of(Membership).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(Membership.new))

    expect {
      Group.create_with_owner!(owner: owner, name: "Movie night")
    }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Group.count).to eq(0)
  end

  it "rotates the invite code without changing existing membership" do
    group = Group.create_with_owner!(owner: owner, name: "Movie night")
    old_code = group.invite_code

    group.reset_invitation!

    expect(group.reload.invite_code).to match(/\A[A-F0-9]{16}\z/)
    expect(group.invite_code).not_to eq(old_code)
    expect(Group.find_by(invite_code: old_code)).to be_nil
    expect(group.members).to contain_exactly(owner)
  end

  it "requires an owner and a unique invitation code" do
    group = Group.create_with_owner!(owner: owner, name: "Movie night")
    duplicate = Group.new(name: "Another group", invite_code: group.invite_code)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors).to include(:owner, :invite_code)
  end

  it "enforces unique invitation codes at the database" do
    group = Group.create_with_owner!(owner: owner, name: "Movie night")
    duplicate = Group.new(owner: owner, name: "Another group", invite_code: group.invite_code)

    expect {
      Group.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
