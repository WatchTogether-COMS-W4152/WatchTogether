Given("{string} added {string} to the watchlist for {string}") do |viewer, title, group_name|
  as_viewer(viewer) do
    visit_page(:post, watchlist_path(group_name), title: title)
    expect_watchlist_page(group_name)
    expect(props.fetch("errors", {})).to be_empty
  end
  remember_watchlist_item(title, group_name)
end

When("I view the watchlist for {string}") do |group_name|
  visit_page(:get, watchlist_path(group_name))
end

When("I add {string} to the watchlist for {string}") do |title, group_name|
  visit_page(:post, watchlist_path(group_name), title: title)
  remember_watchlist_item(title, group_name)
end

When("I add a watchlist title of {int} characters to {string}") do |length, group_name|
  visit_page(:post, watchlist_path(group_name), title: "A" * length)
end

When("I add a whitespace-only title to the watchlist for {string}") do |group_name|
  visit_page(:post, watchlist_path(group_name), title: "   ")
end

When("I change the watched status of {string} in {string}") do |title, group_name|
  visit_page(:patch, "#{watchlist_path(group_name)}/#{watchlist_item_id(title, group_name)}")
end

When("I remove {string} from the watchlist for {string}") do |title, group_name|
  visit_page(:delete, "#{watchlist_path(group_name)}/#{watchlist_item_id(title, group_name)}")
end

When("I try to change {string} from {string} through the watchlist for {string}") do |title, source_group, target_group|
  visit_page(:patch, "#{watchlist_path(target_group)}/#{watchlist_item_id(title, source_group)}")
end

When("I try to remove {string} from {string} through the watchlist for {string}") do |title, source_group, target_group|
  visit_page(:delete, "#{watchlist_path(target_group)}/#{watchlist_item_id(title, source_group)}")
end

Then("the watchlist for {string} contains:") do |group_name, table|
  expect_watchlist_page(group_name)
  items = props.fetch("watchlist_items").map do |item|
    [ item.fetch("title"), item.fetch("watched") ? "Watched" : "Not watched" ]
  end
  expect(items).to match_array(table.raw)
end

Then("the watchlist for {string} is empty") do |group_name|
  expect_watchlist_page(group_name)
  expect(props.fetch("watchlist_items")).to eq([])
end

Then("the watchlist for {string} contains the {int}-character title") do |group_name, length|
  expect_watchlist_page(group_name)
  expect(props.fetch("watchlist_items")).to contain_exactly(
    include("title" => "A" * length, "watched" => false)
  )
end

Then("{string} has no watchlist items") do |group_name|
  expect(WatchlistItem.where(group_id: group_id(group_name))).to be_empty
end

Then("the watchlist item {string} has been removed from {string}") do |title, group_name|
  expect(WatchlistItem.exists?(watchlist_item_id(title, group_name))).to be(false)
end

Then("watchlist details contain no emails or invitation codes") do
  expect(props.fetch("group").keys).to match_array(%w[id name])
  props.fetch("watchlist_items").each do |item|
    expect(item.keys).to match_array(%w[id title watched])
  end
  expect(nested_keys(props.except("auth"))).not_to include("email", "invitation_code", "invite_code")
end

Then("the page contains no watchlist details") do
  expect(props).not_to have_key("group")
  expect(props).not_to have_key("watchlist_items")
end
