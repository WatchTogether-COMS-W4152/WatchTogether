When("I save the streaming services {string}") do |list|
  ids = list.split(", ").map { |name| StreamingService.id_for(name) }
  expect(ids).to all(be_present)
  visit_page(:patch, "/profile", streaming_services: "1", provider_ids: ids)
end

When("I clear my streaming services") do
  visit_page(:patch, "/profile", streaming_services: "1")
end

When("I save streaming services including an unknown service") do
  visit_page(:patch, "/profile", streaming_services: "1", provider_ids: [ StreamingService.id_for("Netflix"), 999_999 ])
end

Then("my streaming services are {string}") do |list|
  visit_page(:get, "/profile") unless @page.fetch("component") == "profile/show"
  names = list.split(", ").reject(&:empty?)
  expected = StreamingService::CATALOG.filter_map { |service| service.fetch(:id) if names.include?(service.fetch(:name)) }
  expect(props.fetch("selected_service_ids")).to eq(expected)
  expect(User.find(current_user.fetch("id")).streaming_subscriptions.pluck(:provider_id)).to match_array(expected)
end

Then("the watchability of {string} on the watchlist is {string}") do |title, label|
  item = props.fetch("watchlist_items").find { |entry| entry.fetch("title") == title }
  expect(item&.dig("watchability", "label")).to eq(label)
end

Then("the watchability of {string} on the picks is {string}") do |title, label|
  item = props.fetch("suggestions").find { |entry| entry.fetch("title") == title }
  expect(item&.dig("watchability", "label")).to eq(label)
end

Then("{string} is listed with the streaming services {string}") do |name, list|
  expect(@page.fetch("component")).to eq("groups/members")
  member = props.fetch("group").fetch("members").find { |entry| entry.fetch("display_name") == name }
  expect(member&.fetch("services")).to eq(list.split(", ").reject(&:empty?))
end

Then("the page does not list streaming service ids") do
  expect(nested_keys(props)).not_to include("provider_id", "provider_ids", "streaming_ids", "selected_service_ids")
end

When("I filter the watchlist for {string} to what everyone can watch") do |group_name|
  visit_page(:get, "#{watchlist_path(group_name)}?where=everyone")
end

When("I show the full watchlist for {string}") do |group_name|
  visit_page(:get, watchlist_path(group_name))
end

When("I filter the picks for {string} to what everyone can watch") do |group_name|
  visit_page(:get, "#{suggestions_path(group_name)}?where=everyone")
end

When("I show every pick for {string}") do |group_name|
  visit_page(:get, suggestions_path(group_name))
end

Then("the filtered watchlist for {string} is empty") do |group_name|
  expect_watchlist_page(group_name)
  expect(props.fetch("filtering")).to be(true)
  expect(props.fetch("watchlist_items")).to eq([])
end
