When("I make {string} an owner of {string}") do |viewer, name|
  visit_page(:post, "#{group_path(name)}/members/#{@accounts.fetch(viewer)}/promote")
end

When("I remove {string} from {string}") do |viewer, name|
  @previous_invitation_codes[name] = @invitation_codes.fetch(name)
  visit_page(:delete, "#{group_path(name)}/members/#{@accounts.fetch(viewer)}")
  if props["group"] && props.fetch("group")["invitation_code"]
    @invitation_codes[name] = props.fetch("group").fetch("invitation_code")
  end
end

Then("the group has these owners:") do |table|
  expect(@response.status).to eq(200)
  owners = props.fetch("group").fetch("members").select { |member| member.fetch("role") == "owner" }
  expect(owners.map { |owner| owner.fetch("display_name") }).to match_array(table.raw.flatten)
end

Then("I have owner access to the group") do
  expect(props.fetch("group").fetch("is_owner")).to be(true)
  expect(props.fetch("group").fetch("invitation_code")).to be_present
  expect(nested_keys(props.fetch("group"))).not_to include("email", "password_digest", "token_digest")
end

Then("{string} is an ordinary member of {string}") do |viewer, name|
  expect(membership_for(viewer, name).sole.role).to eq("member")
end

Then("I am told I cannot remove myself") do
  expect(@response.status).to eq(200)
  expect(@page.fetch("component")).to eq("groups/show")
  expect(props.dig("flash", "alert")).to match(/cannot remove yourself/i)
end
