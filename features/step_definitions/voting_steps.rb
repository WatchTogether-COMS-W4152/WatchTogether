Given("{string} suggested {string} to {string}") do |viewer, title, group_name|
  as_viewer(viewer) do
    visit_page(:post, suggestions_path(group_name), title: title)
    expect(@page.fetch("component")).to eq("suggestions/index")
    expect(props.fetch("errors", {})).to be_empty
  end
  remember_suggestion(title, group_name)
end

Given("{string} rated {string} in {string} as {string}") do |viewer, title, group_name, label|
  as_viewer(viewer) do
    visit_page(:put, "#{suggestions_path(group_name)}/#{suggestion_id(title, group_name)}/vote", rating: rating_value(label))
    expect(suggestion_props(title).fetch("my_rating")).to eq(rating_value(label))
  end
end

When("I suggest {string} to {string}") do |title, group_name|
  visit_page(:post, suggestions_path(group_name), title: title)
  remember_suggestion(title, group_name)
end

When("I view the suggestions for {string}") do |group_name|
  visit_page(:get, suggestions_path(group_name))
end

When("I rate {string} in {string} as {string}") do |title, group_name, label|
  visit_page(:put, "#{suggestions_path(group_name)}/#{suggestion_id(title, group_name)}/vote", rating: rating_value(label))
end

When("I rate {string} in {string} with the unsupported rating {string}") do |title, group_name, rating|
  visit_page(:put, "#{suggestions_path(group_name)}/#{suggestion_id(title, group_name)}/vote", rating: rating)
end

When("I remove the suggestion {string} from {string}") do |title, group_name|
  visit_page(:delete, "#{suggestions_path(group_name)}/#{suggestion_id(title, group_name)}")
end

Then("the suggestions for {string} are ranked:") do |group_name, table|
  expect(@response.status).to eq(200)
  expect(@page.fetch("component")).to eq("suggestions/index")
  expect(props.fetch("group").fetch("id")).to eq(group_id(group_name))
  ranked = props.fetch("suggestions").map { |suggestion| [ suggestion.fetch("title"), suggestion.fetch("score").to_s ] }
  expect(ranked).to eq(table.raw)
end

Then("{string} has no suggestions") do |group_name|
  expect(Suggestion.for_group(group_id(group_name))).to be_empty
end

Then("{string} has exactly one suggestion titled {string}") do |group_name, title|
  expect(Suggestion.for_group(group_id(group_name)).where(title_key: Suggestion.title_key_for(title)).count).to eq(1)
end

Then("I am told {string} was added") do |title|
  expect(props.dig("flash", "notice")).to eq("“#{title}” was added. Rate it below.")
end

Then("{string} is shown as suggested by {string}") do |title, viewer|
  expect(suggestion_props(title).fetch("suggested_by")).to eq(viewer)
end

Then("my rating for {string} is {string}") do |title, label|
  expect(suggestion_props(title).fetch("my_rating")).to eq(rating_value(label))
end

Then("I have not rated {string}") do |title|
  expect(suggestion_props(title).fetch("my_rating")).to be_nil
end

Then("{string} shows {int} of {int} members rated") do |title, votes, members|
  expect(suggestion_props(title).fetch("votes_count")).to eq(votes)
  expect(props.fetch("member_count")).to eq(members)
end

Then("{string} has exactly one rating for {string} in {string}") do |viewer, title, group_name|
  expect(Vote.where(user_id: @accounts.fetch(viewer), suggestion_id: suggestion_id(title, group_name)).count).to eq(1)
end

Then("nobody has rated {string} in {string}") do |title, group_name|
  expect(Vote.where(suggestion_id: suggestion_id(title, group_name))).to be_empty
end

Then("the suggestions show no individual ratings or emails") do
  props.fetch("suggestions").each do |suggestion|
    expect(suggestion.keys).to match_array(%w[id title score votes_count my_rating suggested_by can_remove])
  end
  expect(nested_keys(props)).not_to include("rating", "votes", "voters", "user_id", "love_count")
  expect(nested_keys(props.except("auth"))).not_to include("email")
end

Then("I can remove {string}") do |title|
  expect(suggestion_props(title).fetch("can_remove")).to be(true)
end

Then("I cannot remove {string}") do |title|
  expect(suggestion_props(title).fetch("can_remove")).to be(false)
end

Then("the suggestion {string} was removed from {string} with its ratings") do |title, group_name|
  expect(Suggestion.exists?(suggestion_id(title, group_name))).to be(false)
  expect(Vote.where(suggestion_id: suggestion_id(title, group_name))).to be_empty
end

Then("the suggestion {string} is still in {string}") do |title, group_name|
  expect(Suggestion.for_group(group_id(group_name)).exists?(suggestion_id(title, group_name))).to be(true)
end

Then("only the suggester or an owner is allowed to do that") do
  expect(@response.status).to eq(403)
  expect(@page.fetch("component")).to eq("errors/show")
  expect(props.fetch("message")).to match(/suggested a title or a group owner/)
end
