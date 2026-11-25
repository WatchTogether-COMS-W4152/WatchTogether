class GroupWatchability
  MANUAL_LABEL = "Streaming information is not available for manually added titles."
  UNAVAILABLE_LABEL = "Streaming information is temporarily unavailable. Try again later."
  EMPTY_LABEL = "No watch providers are currently listed in the United States."
  EVERYONE_LABEL = "On everyone's services"

  def self.for(record, members:, client:)
    new(record, members, client).to_h
  end

  def initialize(record, members, client)
    @record = record
    @members = members
    @client = client
  end

  def to_h
    return excluded(MANUAL_LABEL) unless catalogue?

    availability = providers
    return excluded(UNAVAILABLE_LABEL) if availability.nil?
    return excluded(EMPTY_LABEL) if listed(availability).empty?

    uncovered = @members
      .reject { |member| covered?(member, availability) }
      .sort_by { |member| [ member.display_name.downcase, member.id ] }
    return { "included" => true, "label" => EVERYONE_LABEL } if uncovered.empty?

    excluded(gap_label(uncovered, availability))
  end

  private

  def catalogue?
    @record.tmdb_id.present? && @record.media_type.present?
  end

  def providers
    @client.watch_providers(@record.media_type, @record.tmdb_id)
  rescue TmdbClient::Error
    nil
  end

  def listed(availability)
    %i[streaming rent buy free ads].flat_map { |key| Array(availability[key]) }
  end

  def covered?(member, availability)
    return true if Array(availability[:free]).any? || Array(availability[:ads]).any?

    (member.streaming_subscriptions.map(&:provider_id) & Array(availability[:streaming_ids])).any?
  end

  def gap_label(members, availability)
    names = name_list(members.map(&:display_name))
    if Array(availability[:rent]).any? || Array(availability[:buy]).any?
      members.one? ? "#{names} needs a rental" : "#{names} need a rental"
    else
      "Not available for #{names}"
    end
  end

  def name_list(names)
    return names.fetch(0) if names.one?
    return "#{names.fetch(0)} and #{names.fetch(1)}" if names.length == 2

    "#{names[0..-2].join(", ")}, and #{names.fetch(-1)}"
  end

  def excluded(label)
    { "included" => false, "label" => label }
  end
end
