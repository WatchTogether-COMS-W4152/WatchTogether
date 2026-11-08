require "rails_helper"

RSpec.describe "Groups and invitations", type: :request do
  let(:owner) { create_user(display_name: "Owner", email: "owner@example.com") }
  let(:member) { create_user(display_name: "Member", email: "member@example.com") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Friday films") }

  it "shows an empty group list and the create/join forms" do
    sign_in(owner)
    get groups_path
    expect(page_props["groups"]).to eq([])
    get new_group_path
    expect(inertia).to render_component("groups/new")
    get join_groups_path
    expect(inertia).to render_component("groups/join")
  end

  it "creates a private group with the signed-in user as its owner and first member" do
    sign_in(owner)
    expect {
      post groups_path, params: { name: " Weekend movies ", owner_id: member.id, invite_code: "A" * 16 }
    }.to change(Group, :count).by(1).and change(Membership, :count).by(1)
    created = Group.last
    expect(response).to redirect_to(group_path(created))
    expect(created.name).to eq("Weekend movies")
    expect(created.owner).to eq(owner)
    expect(created.members).to contain_exactly(owner)
    expect(created.invite_code).not_to eq("A" * 16)
  end

  it "rejects a blank or overlong group name without partial records" do
    sign_in(owner)
    [ " ", "x" * 81 ].each do |name|
      post groups_path, params: { name: name }
      expect(response).to redirect_to(new_group_path)
      follow_redirect!
      expect(page_props.dig("errors", "name")).not_to be_empty
    end
    expect(Group.count).to eq(0)
    expect(Membership.count).to eq(0)
  end

  it "lists only groups the user belongs to and omits invitation codes" do
    joined = group
    joined.memberships.create!(user: member)
    Group.create_with_owner!(owner: create_user, name: "Other private group")
    sign_in(member)
    get groups_path
    expect(page_props["groups"]).to eq([ { "id" => joined.id, "name" => "Friday films", "owner_id" => owner.id, "member_count" => 2 } ])
    expect(page_props.to_json).not_to include(joined.invite_code)
  end

  it "shows members' names while keeping their emails and secrets private" do
    group.memberships.create!(user: member)
    sign_in(member)
    get group_path(group)
    details = page_props["group"]
    expect(details["members"]).to contain_exactly(
      { "id" => owner.id, "display_name" => "Owner" }, { "id" => member.id, "display_name" => "Member" }
    )
    expect(details).not_to have_key("invitation_code")
    expect(response.body).not_to include(owner.email, owner.password_digest, group.invite_code)
  end

  it "shows invitation controls data only to the owner" do
    sign_in(owner)
    get group_path(group)
    expect(page_props.dig("group", "invitation_code")).to eq(group.invite_code)
  end

  it "returns the same not-found page for inaccessible and missing groups" do
    group
    sign_in(member)
    [ group.id, Group.maximum(:id) + 1 ].each do |id|
      get group_path(id)
      expect(response).to have_http_status(:not_found)
      expect(inertia).to render_component("errors/show")
      expect(page_props["message"]).to eq("That group could not be found.")
      expect(response.body).not_to include(group.name, group.invite_code)
    end
  end

  it "joins using a code with different case and surrounding whitespace" do
    sign_in(member)
    post join_groups_path, params: { code: " #{group.invite_code.downcase} " }
    expect(response).to redirect_to(group_path(group))
    expect(group.members).to contain_exactly(owner, member)
  end

  it "handles repeated joins without duplicate memberships" do
    sign_in(member)
    code = group.invite_code
    2.times do
      post join_groups_path, params: { code: code }
      expect(response).to redirect_to(group_path(group))
    end
    expect(group.memberships.where(user: member).count).to eq(1)
  end

  it "allows an owner to join their own group without duplicating their membership" do
    sign_in(owner)
    post join_groups_path, params: { code: group.invite_code }
    expect(response).to redirect_to(group_path(group))
    expect(group.memberships.count).to eq(1)
  end

  it "rejects missing and invalid codes without adding memberships" do
    group
    sign_in(member)
    [ nil, "", "not-a-code" ].each do |code|
      post join_groups_path, params: { code: code }
      expect(response).to redirect_to(join_groups_path)
      follow_redirect!
      expect(page_props.dig("errors", "code")).to eq([ "This invitation code is invalid or has been replaced." ])
    end
    expect(member.memberships).to be_empty
  end

  it "rechecks the code under the group lock if a reset raced with the lookup" do
    current_group = group
    old_code = current_group.invite_code
    allow(Group).to receive(:find_by).with(invite_code: old_code).and_return(current_group)
    allow(current_group).to receive(:with_lock).and_wrap_original do |original, &block|
      current_group.update!(invite_code: "B" * 16)
      original.call(&block)
    end
    sign_in(member)
    post join_groups_path, params: { code: old_code }
    expect(response).to redirect_to(join_groups_path)
    expect(member.memberships).to be_empty
  end

  it "lets an owner replace a code while retaining existing members" do
    group.memberships.create!(user: member)
    old_code = group.invite_code
    sign_in(owner)
    post group_reset_invitation_path(group)
    expect(response).to redirect_to(group_path(group))
    expect(group.reload.invite_code).not_to eq(old_code)
    expect(group.members).to contain_exactly(owner, member)
    delete session_path
    outsider = create_user
    sign_in(outsider)
    post join_groups_path, params: { code: old_code }
    expect(response).to redirect_to(join_groups_path)
    expect(outsider.memberships).to be_empty
    post join_groups_path, params: { code: group.invite_code }
    expect(response).to redirect_to(group_path(group))
    expect(group.members.reload).to include(outsider)
  end

  it "forbids ordinary members from resetting codes" do
    group.memberships.create!(user: member)
    old_code = group.invite_code
    sign_in(member)
    post group_reset_invitation_path(group)
    expect(response).to have_http_status(:forbidden)
    expect(group.reload.invite_code).to eq(old_code)
    expect(response.body).not_to include(old_code)
  end

  it "hides invitation reset from nonmembers" do
    group
    sign_in(member)
    post group_reset_invitation_path(group)
    expect(response).to have_http_status(:not_found)
  end

  it "throttles join attempts per user without blocking another user" do
    sign_in(member)
    20.times { post join_groups_path, params: { code: "invalid" } }
    post join_groups_path, params: { code: group.invite_code }
    expect(response).to have_http_status(:too_many_requests)
    expect(member.memberships).to be_empty
    delete session_path
    sign_in(owner)
    post join_groups_path, params: { code: group.invite_code }
    expect(response).to redirect_to(group_path(group))
  end
end
