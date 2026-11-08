Given("{string} has shared an invitation to {string}") do |owner, group_name|
  share_invitation(owner, group_name)
end

Given("{string} joined {string} using an invitation") do |viewer, group_name|
  as_viewer(viewer) do
    visit_page(:post, "/groups/join", code: @invitation_codes.fetch(group_name))
    expect(props.fetch("group").fetch("id")).to eq(group_id(group_name))
  end
end

When("I join {string} using its shared invitation") do |name|
  visit_page(:post, "/groups/join", code: @invitation_codes.fetch(name))
end

When("I join {string} using a lowercase invitation with surrounding spaces") do |name|
  visit_page(:post, "/groups/join", code: "  #{@invitation_codes.fetch(name).downcase}  ")
end

When("I join {string} using its previous invitation") do |name|
  visit_page(:post, "/groups/join", code: @previous_invitation_codes.fetch(name))
end

When("I join using invitation code {string}") do |code|
  visit_page(:post, "/groups/join", code: code)
end

When("I reset the invitation for {string}") do |name|
  @previous_invitation_codes[name] = @invitation_codes.fetch(name)
  visit_page(:post, "#{group_path(name)}/invitation/reset")
  if props["group"]
    @invitation_codes[name] = props.fetch("group").fetch("invitation_code")
  end
end

Then("member details contain names but no emails or invitation code") do
  group = props.fetch("group")
  expect(group).not_to have_key("invitation_code")
  expect(group).not_to have_key("invite_code")
  group.fetch("members").each do |member|
    expect(member.keys).to match_array(%w[id display_name])
  end
end

Then("{string} has exactly one membership in {string}") do |viewer, name|
  expect(membership_for(viewer, name).count).to eq(1)
end

Then("{string} has no membership in {string}") do |viewer, name|
  expect(membership_for(viewer, name)).to be_empty
end

Then("only the owner is allowed to do that") do
  expect(@response.status).to eq(403)
  expect(@page.fetch("component")).to eq("errors/show")
end

Then("the invitation code for {string} has changed") do |name|
  expect(@invitation_codes.fetch(name)).to be_present
  expect(@invitation_codes.fetch(name)).not_to eq(@previous_invitation_codes.fetch(name))
end

Then("the invitation code for {string} is unchanged") do |name|
  expect(Group.find(group_id(name)).invite_code).to eq(@invitation_codes.fetch(name))
end
