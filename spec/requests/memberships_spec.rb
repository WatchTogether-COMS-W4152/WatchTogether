require "rails_helper"

RSpec.describe "Group ownership and member management", type: :request do
  let(:owner) { create_user(display_name: "Alice") }
  let(:member) { create_user(display_name: "Bob") }
  let(:group) { Group.create_with_owner!(owner: owner, name: "Friday films") }
  let!(:membership) { group.memberships.create!(user: member) }

  it "promotes an existing member without replacing or duplicating owners" do
    sign_in(owner)
    original_code = group.invite_code

    2.times do
      expect {
        post group_member_promote_path(group, member)
      }.not_to change(Membership, :count)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(group_path(group))
    end

    expect(group.owners).to contain_exactly(owner, member)
    expect(group.reload.invite_code).to eq(original_code)
    follow_redirect!
    expect(page_props.dig("flash", "notice")).to eq("Bob is now an owner.")
    expect(page_props.dig("group", "members").map { |item| item["role"] }).to eq([ "owner", "owner" ])
    expect(response.body).not_to include(member.email, member.password_digest)
  end

  it "gives a promoted owner invitation, management, and deletion permissions immediately" do
    third_member = create_user
    group.memberships.create!(user: third_member)
    sign_in(owner)
    post group_member_promote_path(group, member)
    delete session_path
    sign_in(member)

    get groups_path
    expect(page_props["groups"].first["is_owner"]).to be(true)
    get group_path(group)
    expect(page_props.dig("group", "is_owner")).to be(true)
    expect(page_props.dig("group", "invitation_code")).to eq(group.invite_code)
    original_code = group.invite_code
    post group_reset_invitation_path(group)
    expect(response).to redirect_to(group_path(group))
    expect(group.reload.invite_code).not_to eq(original_code)

    post group_member_promote_path(group, third_member)
    expect(group.owner?(third_member)).to be(true)
    delete group_path(group)
    expect(response).to redirect_to(groups_path)
    expect(Group.exists?(group.id)).to be(false)
  end

  it "removes an ordinary member, replaces the code, and preserves accounts and unrelated memberships" do
    other_group = Group.create_with_owner!(owner: member, name: "Other films")
    original_code = group.invite_code
    sign_in(owner)

    expect {
      delete group_member_path(group, member)
    }.to change(Membership, :count).by(-1)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(group_path(group))
    expect(group.reload.invite_code).not_to eq(original_code)
    expect(group.members).to contain_exactly(owner)
    expect(member.reload.groups).to contain_exactly(other_group)
    expect(User.exists?(member.id)).to be(true)
    follow_redirect!
    expect(page_props.dig("flash", "notice")).to eq("Bob was removed. The invitation code has been replaced.")
    expect(page_props.dig("group", "invitation_code")).to eq(group.invite_code)

    delete session_path
    sign_in(member)
    get group_path(group)
    expect(response).to have_http_status(:not_found)
    post join_groups_path, params: { code: original_code }
    expect(response).to redirect_to(join_groups_path)
    expect(group.memberships.exists?(user: member)).to be(false)
    post join_groups_path, params: { code: group.invite_code, role: "owner" }
    expect(response).to redirect_to(group_path(group))
    expect(group.memberships.find_by!(user: member)).to be_member
  end

  it "lets an owner remove another owner without losing the remaining ownership" do
    membership.update!(role: "owner")
    sign_in(member)
    delete group_member_path(group, owner)

    expect(response).to redirect_to(group_path(group))
    expect(group.owners).to contain_exactly(member)
    expect(group.members).to contain_exactly(member)
    expect(User.exists?(owner.id)).to be(true)
    delete session_path
    sign_in(owner)
    [ :promote, :remove, :reset, :delete ].each do |action|
      case action
      when :promote then post group_member_promote_path(group, member)
      when :remove then delete group_member_path(group, member)
      when :reset then post group_reset_invitation_path(group)
      when :delete then delete group_path(group)
      end
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(group.name, group.invite_code)
    end
  end

  it "rejects self-removal for both the only owner and an owner with a co-owner" do
    sign_in(owner)
    original_code = group.invite_code

    [ false, true ].each do |with_co_owner|
      membership.update!(role: "owner") if with_co_owner
      expect {
        delete group_member_path(group, owner)
      }.not_to change(Membership, :count)
      expect(response).to redirect_to(group_path(group))
      follow_redirect!
      expect(page_props.dig("flash", "alert")).to eq("You cannot remove yourself. A group must keep at least one owner.")
      expect(group.owner?(owner)).to be(true)
      expect(group.reload.invite_code).to eq(original_code)
    end
  end

  it "forbids members from promoting themselves or removing anyone, even with forged role parameters" do
    sign_in(member)
    original_code = group.invite_code
    post group_member_promote_path(group, member), params: { role: "owner", is_owner: true }
    expect(response).to have_http_status(:forbidden)
    expect(page_props["message"]).to eq("Only group owners can manage members.")
    delete group_member_path(group, owner), params: { owner_id: member.id }
    expect(response).to have_http_status(:forbidden)
    expect(group.owners).to contain_exactly(owner)
    expect(group.members).to contain_exactly(owner, member)
    expect(group.reload.invite_code).to eq(original_code)
    expect(response.body).not_to include(group.invite_code, owner.email)
  end

  it "requires sign-in for both member management actions" do
    post group_member_promote_path(group, member)
    expect(response).to redirect_to(sign_in_path)
    delete group_member_path(group, member)
    expect(response).to redirect_to(sign_in_path)
    expect(membership.reload).to be_member
  end

  it "hides group details from outsiders attempting either action" do
    outsider = create_user
    sign_in(outsider)
    post group_member_promote_path(group, outsider)
    expect(response).to have_http_status(:not_found)
    delete group_member_path(group, owner)
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(group.name, group.invite_code)
    expect(group.members).to contain_exactly(owner, member)
  end

  it "scopes targets to the selected group and does not create membership by promotion" do
    other_member = create_user
    other_group = Group.create_with_owner!(owner: owner, name: "Other films")
    other_membership = other_group.memberships.create!(user: other_member)
    sign_in(owner)
    original_code = group.invite_code

    [ other_member.id, User.maximum(:id) + 1 ].each do |user_id|
      post group_member_promote_path(group, user_id)
      expect(response).to have_http_status(:not_found)
      delete group_member_path(group, user_id)
      expect(response).to have_http_status(:not_found)
    end
    expect(other_membership.reload).to be_member
    expect(group.members).to contain_exactly(owner, member)
    expect(group.reload.invite_code).to eq(original_code)
  end

  it "rolls back member removal if invitation replacement fails" do
    original_code = group.invite_code
    sign_in(owner)
    allow_any_instance_of(Group).to receive(:reset_invitation!).and_raise(ActiveRecord::RecordInvalid.new(group))

    delete group_member_path(group, member)
    expect(response).to have_http_status(:unprocessable_content)
    expect(membership.reload).to be_member
    expect(group.reload.invite_code).to eq(original_code)
  end

  [ :promote, :remove, :reset, :delete ].each do |action|
    it "rechecks ownership under the group lock before #{action}" do
      membership.update!(role: "owner")
      sign_in(owner)
      allow_any_instance_of(Group).to receive(:with_lock).and_wrap_original do |original, &block|
        group.memberships.find_by!(user: owner).destroy!
        original.call(&block)
      end

      case action
      when :promote then post group_member_promote_path(group, member)
      when :remove then delete group_member_path(group, member)
      when :reset then post group_reset_invitation_path(group)
      when :delete then delete group_path(group)
      end
      expect(response).to have_http_status(:forbidden)
      expect(group.reload.owners).to contain_exactly(member)
      expect(group.members).to contain_exactly(member)
    end
  end
end
