Given("the TMDB catalogue is available") do
  @catalogue_unavailable = false
end

Given("the TMDB catalogue is unavailable") do
  @catalogue_unavailable = true
  Rails.cache.clear
end

When("I search the catalogue for {string} in {string}") do |query, group_name|
  visit_catalogue("#{group_path(group_name)}/catalog/search", q: query)
end

When(/^I preview catalogue (movie|TV show) (\d+) in "([^"]+)"$/) do |kind, id, group_name|
  visit_catalogue("#{group_path(group_name)}/catalog/#{catalogue_type(kind)}/#{id}")
end

When("I request unsupported catalogue type {string} with ID {string} in {string}") do |kind, id, group_name|
  visit_catalogue("#{group_path(group_name)}/catalog/#{kind}/#{id}")
end

When(/^I add catalogue (movie|TV show) (\d+) to the (suggestions|watchlist) for "([^"]+)"( with forged details)?$/) do |kind, id, destination, group_name, forged|
  fields = { tmdb_id: id, media_type: catalogue_type(kind) }
  if forged
    fields.merge!(title: "Forged title", overview: "Injected description", release_year: 1900,
      tmdb_rating: 10, age_rating: "G", poster_url: "https://untrusted.example/poster.jpg")
  end
  path = destination == "suggestions" ? suggestions_path(group_name) : watchlist_path(group_name)
  visit_page(:post, path, fields)
  if destination == "suggestions"
    Suggestion.for_group(group_id(group_name)).each { |suggestion| remember_suggestion(suggestion.title, group_name) }
  end
end

When(/^I submit an incomplete catalogue selection to the (suggestions|watchlist) for "([^"]+)"$/) do |destination, group_name|
  path = destination == "suggestions" ? suggestions_path(group_name) : watchlist_path(group_name)
  visit_page(:post, path, title: "A forged manual fallback", tmdb_id: 329865)
end

When("I send the suggestion {string} from {string} to its watchlist") do |title, group_name|
  visit_page(:post, "#{suggestions_path(group_name)}/#{suggestion_id(title, group_name)}/watchlist")
  remember_watchlist_item(title, group_name)
end

When("I send the suggestion {string} from {string} through {string} to its watchlist") do |title, source_group, target_group|
  visit_page(:post, "#{suggestions_path(target_group)}/#{suggestion_id(title, source_group)}/watchlist")
end

Then(/^the catalogue includes the (movie|TV show) "([^"]+)" from (\d+)$/) do |kind, title, year|
  expect(@response.status).to eq(200)
  expect(@catalogue.fetch("results")).to include(include(
    "title" => title, "media_type" => catalogue_type(kind), "release_year" => year.to_i,
    "overview" => be_present, "poster_url" => start_with("https://image.tmdb.org/t/p/")
  ))
  expect(@catalogue.fetch("results").map { |item| item.fetch("media_type") }).to all(be_in(%w[movie tv]))
end

Then("the catalogue response contains no API credentials") do
  expect(nested_keys(@catalogue)).not_to include("api_key", "access_token", "authorization")
  expect(@response.body).not_to include(TmdbHelpers::FAKE_API_KEY)
end

Then("the catalogue search has no results") do
  expect(@response.status).to eq(200)
  expect(@catalogue).to eq("results" => [])
end

Then("the catalogue preview has age rating {string}") do |rating|
  expect(@response.status).to eq(200)
  expect(@catalogue.fetch("title").fetch("age_rating")).to eq(rating)
end

Then("the suggestion {string} shows its catalogue details") do |title|
  expect(suggestion_props(title)).to include(expected_catalogue_details(title))
end

Then("the watchlist item {string} shows its catalogue details") do |title|
  item = props.fetch("watchlist_items").find { |entry| entry.fetch("title") == title }
  expect(item).to include(expected_catalogue_details(title))
end

Then("the suggestion {string} is marked as on the watchlist") do |title|
  expect(@page.fetch("component")).to eq("suggestions/index")
  expect(suggestion_props(title).fetch("in_watchlist")).to be(true)
end

Then("the suggestion {string} is available to add to the watchlist") do |title|
  expect(@page.fetch("component")).to eq("suggestions/index")
  expect(suggestion_props(title).fetch("in_watchlist")).to be(false)
end

Then("{string} has exactly one watchlist item titled {string}") do |group_name, title|
  expect(WatchlistItem.where(group_id: group_id(group_name), title: title).count).to eq(1)
end

Then(/^"([^"]+)" has exactly one watchlist item for catalogue (movie|TV show) (\d+)$/) do |group_name, kind, id|
  expect(WatchlistItem.where(group_id: group_id(group_name), media_type: catalogue_type(kind), tmdb_id: id).count).to eq(1)
end

Then("{string} has catalogue suggestions:") do |group_name, table|
  records = Suggestion.for_group(group_id(group_name)).order(:tmdb_id, :media_type)
  actual = records.map { |item| [ item.tmdb_id.to_s, item.media_type, item.title, item.release_year.to_s ] }
  expect(actual).to eq(table.raw)
end

Then("the watchlist item {string} has no invented catalogue details") do |title|
  item = props.fetch("watchlist_items").find { |entry| entry.fetch("title") == title }
  expect(item).to include("tmdb_id" => 999002, "media_type" => "tv", "poster_url" => nil,
    "age_rating" => nil, "release_year" => nil, "tmdb_rating" => nil)
end

Then("the catalogue request fails safely with status {int}") do |status|
  expect(@response.status).to eq(status)
  expect(@catalogue).to include("error" => be_present)
  expect(@catalogue).not_to have_key("results")
  expect(@response.body).not_to include(TmdbHelpers::FAKE_API_KEY, "Injected upstream failure")
end
