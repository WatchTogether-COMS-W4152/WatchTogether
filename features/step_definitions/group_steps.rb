Given("{string} owns a group named {string}") do |owner, name|
  as_viewer(owner) do
    visit_page(:post, "/groups", name: name)
    group = props.fetch("group")
    @groups[name] = group.fetch("id")
    @invitation_codes[name] = group.fetch("invitation_code")
  end
end

When("I create a group named {string}") do |name|
  visit_page(:post, "/groups", name: name)
  @groups[name] = props["group"]["id"] if props["group"]
end

When("I view my groups") do
  visit_page(:get, "/groups")
end

When("I view the group {string}") do |name|
  visit_page(:get, group_path(name))
end

When("I delete the group {string}") do |name|
  visit_page(:delete, group_path(name))
end

Then("I am told the group was deleted") do
  expect(@response.status).to eq(200)
  expect(@page.fetch("component")).to eq("groups/index")
  expect(props.dig("flash", "notice")).to eq("The group was deleted.")
end

Then("the group {string} has been deleted") do |name|
  expect(Group.exists?(group_id(name))).to be(false)
  expect(Membership.where(group_id: group_id(name))).to be_empty
end

Then("the viewer accounts still exist:") do |table|
  account_ids = table.raw.flatten.map { |name| @accounts.fetch(name) }
  expect(User.where(id: account_ids).pluck(:id)).to match_array(account_ids)
end

Then("the group is named {string} and owned by {string}") do |name, owner|
  expect(props.fetch("group")).to include("name" => name, "owner_id" => @accounts.fetch(owner))
end

Then("the group has these members:") do |table|
  expect(@response.status).to eq(200)
  expect(props.fetch("group").fetch("members").map { |member| member.fetch("display_name") })
    .to match_array(table.raw.flatten)
end

Then("my group list contains only:") do |table|
  expect(@page.fetch("component")).to eq("groups/index")
  expect(props.fetch("groups").map { |group| group.fetch("name") }).to match_array(table.raw.flatten)
end

Then("my group list reports {int} members for {string}") do |count, name|
  group = props.fetch("groups").find { |item| item.fetch("name") == name }
  expect(group.fetch("member_count")).to eq(count)
end

Then("my group list is empty") do
  expect(props.fetch("groups")).to eq([])
end

Then("no group or membership was created") do
  expect(Group.count).to eq(0)
  expect(Membership.count).to eq(0)
end

Then("group summaries contain no invitation codes or email addresses") do
  expect(nested_keys(props.fetch("groups"))).not_to include("email", "invitation_code", "invite_code")
end

Then("the group is not available to me") do
  expect(@response.status).to eq(404)
  expect(@page.fetch("component")).to eq("errors/show")
end

Then("the page contains no group details") do
  expect(props).not_to have_key("group")
  expect(nested_keys(props)).not_to include("members", "invitation_code", "invite_code")
end
