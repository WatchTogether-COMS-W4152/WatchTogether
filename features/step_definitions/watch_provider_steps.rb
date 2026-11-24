When("I open the streaming details for {string} in {string}") do |title, group_name|
  remember_watchlist_item(title, group_name)
  visit_page(:get, watchlist_item_path(title, group_name))
  expect_watchlist_item_page(title, group_name)
end

Then("the watch provider status is {string}") do |status|
  expect(@response.status).to eq(200)
  expect(props.fetch("watch_providers").fetch("status")).to eq(status)
end

Then("the US watch providers are:") do |table|
  availability = props.fetch("watch_providers")
  expect(availability.fetch("region")).to eq("US")

  actual = %w[streaming rent buy free ads].flat_map do |category|
    availability.fetch(category).map { |name| [ category, name ] }
  end

  expect(actual).to match_array(table.raw)
end

Then("no US watch providers are listed") do
  availability = props.fetch("watch_providers")
  expect(availability.fetch("region")).to eq("US")

  %w[streaming rent buy free ads].each do |category|
    expect(availability.fetch(category)).to be_empty
  end
end
