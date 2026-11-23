# Progress is recorded through the model here; the progress page has its own stories.
Given("{string} has watched up to season {int} episode {int} of {string} in {string}") do |viewer, season, episode, title, group_name|
  progress = EpisodeProgress.find_or_initialize_by(
    watchlist_item_id: watchlist_item_id(title, group_name), user_id: @accounts.fetch(viewer)
  )
  progress.update!(season: season, episode: episode)
end

Given("{string} commented {string} on season {int} episode {int} of {string} in {string}") do |viewer, body, season, episode, title, group_name|
  as_viewer(viewer) do
    visit_page(:post, comments_path(title, group_name), season: season, episode: episode, body: body)
    expect(@page.fetch("component")).to eq("watchlist_items/show")
    expect(props.fetch("errors", {})).to be_empty
  end
end

When("I comment {string} on season {int} episode {int} of {string} in {string}") do |body, season, episode, title, group_name|
  visit_page(:post, comments_path(title, group_name), season: season, episode: episode, body: body)
end

When("I view {string} in {string}") do |title, group_name|
  visit_page(:get, watchlist_item_path(title, group_name))
end

When("I delete the comment {string} on {string} in {string}") do |body, title, group_name|
  visit_page(:delete, "#{comments_path(title, group_name)}/#{comment_id(body, title, group_name)}")
end

Then("the discussion shows:") do |table|
  shown = discussion_episodes.flat_map do |entry|
    entry.fetch("comments").map do |comment|
      [ episode_label(entry.fetch("season"), entry.fetch("episode")), comment.dig("author", "display_name"), comment.fetch("body") ]
    end
  end
  expect(shown).to eq(table.raw)
end

Then("the discussion shows no comments") do
  expect(discussion_episodes.flat_map { |entry| entry.fetch("comments") }).to be_empty
end

Then("the discussion hides {int} comment(s) on {string}") do |count, label|
  entry = discussion_entry(label)
  expect(entry).to be_present
  expect(entry.fetch("hidden_count")).to eq(count)
end

Then("nothing is hidden from me in the discussion") do
  expect(discussion_episodes.sum { |entry| entry.fetch("hidden_count") }).to eq(0)
end

Then("the page does not reveal {string}") do |text|
  expect(@response.body).not_to include(text)
end

Then("I am told my comment was posted on {string}") do |label|
  expect(props.dig("flash", "notice")).to eq("Comment posted on #{label}.")
end

Then("the comment {string} on {string} in {string} still exists") do |body, title, group_name|
  expect(EpisodeComment.exists?(watchlist_item_id: watchlist_item_id(title, group_name), body: body)).to be(true)
end

Then("the comment {string} on {string} in {string} was deleted") do |body, title, group_name|
  expect(EpisodeComment.exists?(watchlist_item_id: watchlist_item_id(title, group_name), body: body)).to be(false)
  expect(props.dig("flash", "notice")).to eq("Comment deleted.")
end

Then("{string} has no comments") do |title|
  expect(EpisodeComment.joins(:watchlist_item).where(watchlist_items: { title: title })).to be_empty
end

Then("only the author or an owner is allowed to do that") do
  expect(@response.status).to eq(403)
  expect(@page.fetch("component")).to eq("errors/show")
end
