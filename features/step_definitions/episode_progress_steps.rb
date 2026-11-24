Given("{string} has watched {string} up to season {int} episode {int} in {string}") do |viewer, title, season, episode, group_name|
  as_viewer(viewer) do
    visit_page(:put, progress_path(title, group_name), season: season, episode: episode)
    expect_watchlist_item_page(title, group_name)
    expect(props.fetch("errors", {})).to be_empty
  end
end

When("I view {string} in {string}") do |title, group_name|
  visit_page(:get, watchlist_item_path(title, group_name))
end

When("I record that I watched {string} up to season {string} episode {string} in {string}") do |title, season, episode, group_name|
  visit_page(:put, progress_path(title, group_name), season: season, episode: episode)
end

When("I mark the next episode of {string} as watched in {string}") do |title, group_name|
  visit_page(:put, progress_path(title, group_name), next: "1")
end

When("I clear my progress for {string} in {string}") do |title, group_name|
  visit_page(:delete, progress_path(title, group_name))
end

When("I try to record progress for {string} from {string} through {string}") do |title, source_group, target_group|
  path = "#{watchlist_path(target_group)}/#{watchlist_item_id(title, source_group)}/progress"
  visit_page(:put, path, season: 1, episode: 1)
end

Then("I am told I've watched up to {string}") do |position|
  expect(props.dig("flash", "notice")).to eq("Watched up to #{position}.")
end

Then("my progress for {string} in {string} is {string}") do |title, group_name, position|
  expect_watchlist_item_page(title, group_name)
  expect(format_position(props.fetch("episode_progress").fetch("my_position"))).to eq(position)
end

Then("the progress for {string} in {string} shows:") do |title, group_name, table|
  expect_watchlist_item_page(title, group_name)
  rows = props.fetch("episode_progress").fetch("members").map do |member|
    [ member.fetch("display_name"), format_position(member.fetch("position")), member.fetch("caught_up") ? "Caught up" : "" ]
  end
  expect(rows).to eq(table.raw)
end

Then("the next episode for everyone is {string}") do |position|
  expect(format_position(props.fetch("episode_progress").fetch("next_episode"))).to eq(position)
end

Then("everyone is caught up") do
  expect(props.fetch("episode_progress").fetch("everyone_caught_up")).to be(true)
end

Then("not everyone is caught up") do
  expect(props.fetch("episode_progress").fetch("everyone_caught_up")).to be(false)
end

Then("the watchlist for {string} suggests {string} next for {string}") do |group_name, position, title|
  expect_watchlist_page(group_name)
  item = props.fetch("watchlist_items").find { |entry| entry.fetch("title") == title }
  expect(format_position(item.fetch("next_episode"))).to eq(position)
end

Then("progress details contain no emails or invitation codes") do
  expect(nested_keys(props.fetch("episode_progress"))).not_to include("email", "invitation_code", "invite_code")
end

Then("I see the error {string} for {string}") do |message, field|
  expect(props.fetch("errors").fetch(field)).to eq(message).or include(message)
end

Then("I am told I've watched every episode") do
  expect(props.dig("flash", "notice")).to eq("You've watched every episode.")
end

Then("the group has finished the show") do
  expect(props.fetch("episode_progress").fetch("finished")).to be(true)
end

Then("the group has not finished the show") do
  expect(props.fetch("episode_progress").fetch("finished")).to be(false)
end
