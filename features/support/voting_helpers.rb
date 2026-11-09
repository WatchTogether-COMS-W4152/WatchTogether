module VotingHelpers
  RATINGS = { "Love it" => "love", "Maybe" => "maybe", "Not interested" => "not_interested" }.freeze

  def suggestions_path(group_name)
    "#{group_path(group_name)}/suggestions"
  end

  def suggestion_ids
    @suggestion_ids ||= {}
  end

  def suggestion_in(title, group_name)
    Suggestion.for_group(group_id(group_name)).find_by(title_key: Suggestion.title_key_for(title))
  end

  def remember_suggestion(title, group_name)
    suggestion = suggestion_in(title, group_name)
    suggestion_ids[[ group_name, Suggestion.title_key_for(title) ]] = suggestion.id if suggestion
  end

  def suggestion_id(title, group_name)
    suggestion_ids.fetch([ group_name, Suggestion.title_key_for(title) ])
  end

  def rating_value(label)
    RATINGS.fetch(label)
  end

  def suggestion_props(title)
    props.fetch("suggestions").find { |suggestion| suggestion.fetch("title") == title } ||
      raise("No suggestion titled #{title.inspect} on this page")
  end
end

World(VotingHelpers)
