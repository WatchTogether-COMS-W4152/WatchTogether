Given("{string} has an account") do |name|
  register_viewer(name)
end

Given("I am signed in as {string}") do |name|
  @browser = browser_for(name)
  visit_page(:post, "/sign-in", email: account_email(name), password: WebHelpers::PASSWORD)
  expect(current_user.fetch("id")).to eq(@accounts.fetch(name))
end

Given("I am signed out") do
  @browser = Rack::Test::Session.new(Rack::MockSession.new(Rails.application))
end

Given("my session has expired") do
  Session.where(user_id: current_user.fetch("id")).order(:id).last.update!(expires_at: 1.minute.ago)
end

When("I register with:") do |table|
  visit_page(:post, "/sign-up", table.rows_hash)
end

When("I sign in with email {string} and password {string}") do |email, password|
  visit_page(:post, "/sign-in", email: email, password: password)
end

When("I visit my profile") do
  visit_page(:get, "/profile")
end

When("I change my display name to {string}") do |name|
  visit_page(:patch, "/profile", display_name: name)
end

When("I sign out") do
  @previous_session_cookie = browser.cookie_jar["session_token"]
  @previous_session_id = Session.where(user_id: current_user.fetch("id")).order(:id).last.id
  visit_page(:delete, "/session")
end

When("I reuse the previous session cookie and visit my profile") do
  @browser = Rack::Test::Session.new(Rack::MockSession.new(Rails.application))
  browser.set_cookie("session_token=#{Rack::Utils.escape(@previous_session_cookie)}")
  visit_page(:get, "/profile")
end

Then("I am signed in with display name {string} and email {string}") do |name, email|
  expect(@response.status).to eq(200)
  expect(current_user).to include("display_name" => name, "email" => email)
end

Then("my session expires in 30 days") do
  expires_at = Session.where(user_id: current_user.fetch("id")).order(:id).last.expires_at
  expect(expires_at).to be_between(30.days.from_now - 1.minute, 30.days.from_now + 1.minute)
end

Then("the page contains no password or session credentials") do
  expect(nested_keys(props)).not_to include("password", "password_digest", "token", "token_digest", "session_token")
end

Then("I see an error for {string}") do |field|
  expect(props.fetch("errors").fetch(field)).to be_present
end

Then("no account or authenticated session was created") do
  expect(User.count).to eq(0)
  expect(Session.count).to eq(0)
  expect(current_user).to be_nil
end

Then("there is still only one account") do
  expect(User.count).to eq(1)
  expect(current_user).to be_nil
end

Then("I remain signed out and see a sign-in error") do
  expect(@page.fetch("component")).to eq("auth/sign-in")
  expect(current_user).to be_nil
  expect(props.fetch("errors")).not_to be_empty
end

Then("I am asked to sign in") do
  expect(@page.fetch("component")).to eq("auth/sign-in")
  expect(current_user).to be_nil
end

Then("that session has been revoked on the server") do
  expect(Session.exists?(@previous_session_id)).to be(false)
end
