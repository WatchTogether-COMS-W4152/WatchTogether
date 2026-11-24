require "net/http"
require "json"

class TmdbClient
  class Error < StandardError; end
  class InvalidSelection < Error; end
  class Unavailable < Error; end

  MEDIA_TYPES = %w[movie tv].freeze
  UNAVAILABLE_MESSAGE = "Movie search is temporarily unavailable. Please try again later or add a title manually."
  TIMEOUTS = { open_timeout: 1, read_timeout: 2, write_timeout: 2 }.freeze
  OUTAGE_KEY = [ "tmdb", "outage" ].freeze
  OUTAGE_TTL = 30.seconds

  def initialize(api_key: ENV["TMDB_API_KEY"].presence || Rails.application.credentials.dig(:tmdb, :api_key), cache: Rails.cache)
    @api_key = api_key
    @cache = cache
  end

  def search(query)
    query = query.to_s.squish
    return [] if query.length < 2
    raise InvalidSelection, "Search must be 120 characters or fewer." if query.length > 120

    @cache.fetch([ "tmdb", "search", query.downcase ], expires_in: 10.minutes) do
      data = request("search/multi", query: query, include_adult: false)
      results = data["results"]
      raise Unavailable, UNAVAILABLE_MESSAGE unless results.is_a?(Array)

      results.filter_map do |entry|
        next unless entry.is_a?(Hash) && MEDIA_TYPES.include?(entry["media_type"]) && !entry["adult"]

        normalize(entry, entry["media_type"])
      end.first(8)
    end
  end

  def details(media_type, tmdb_id)
    unless MEDIA_TYPES.include?(media_type) && tmdb_id.to_s.match?(/\A[1-9]\d{0,9}\z/)
      raise InvalidSelection, "Choose a valid movie or TV show."
    end

    @cache.fetch([ "tmdb", "details", media_type, tmdb_id.to_s ], expires_in: 12.hours) do
      extra = media_type == "movie" ? "release_dates" : "content_ratings"
      data = request("#{media_type}/#{tmdb_id}", append_to_response: extra)
      title = normalize(data, media_type)
      raise InvalidSelection, "That title is unavailable. Choose another movie or TV show." if title.nil? || title[:tmdb_id] != tmdb_id.to_i || data["adult"]

      title.merge(age_rating: certification(data, media_type))
    end
  end

  def season_lengths(tmdb_id)
    raise InvalidSelection, "Choose a valid movie or TV show." unless tmdb_id.to_s.match?(/\A[1-9]\d{0,9}\z/)

    @cache.fetch([ "tmdb", "season_lengths", tmdb_id.to_s ], expires_in: 12.hours) do
      seasons = request("tv/#{tmdb_id}")["seasons"]
      counts = (seasons.is_a?(Array) ? seasons : []).each_with_object({}) do |season, lengths|
        next unless season.is_a?(Hash)

        number, count = season.values_at("season_number", "episode_count")
        lengths[number] = count if number.is_a?(Integer) && number.positive? && count.is_a?(Integer) && count.positive?
      end
      (1..counts.size).map { |number| counts[number] }.take_while(&:itself).presence
    end
  end

  def self.poster_url(path)
    "https://image.tmdb.org/t/p/w342#{path}" if path.is_a?(String) && path.match?(/\A\/[A-Za-z0-9_-]+\.(jpg|png|webp)\z/i)
  end

  private

  def request(path, **query)
    raise Unavailable, UNAVAILABLE_MESSAGE if @api_key.blank? || @cache.read(OUTAGE_KEY)

    fetch_json(path, **query)
  rescue Unavailable
    @cache.write(OUTAGE_KEY, true, expires_in: OUTAGE_TTL) if @api_key.present?
    raise
  end

  def fetch_json(path, **query)
    uri = URI("https://api.themoviedb.org/3/#{path}")
    uri.query = URI.encode_www_form(query.merge(language: "en-US", api_key: @api_key))
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, **TIMEOUTS) do |http|
      http.max_retries = 0
      http.get(uri.request_uri, "Accept" => "application/json")
    end
    raise InvalidSelection, "That title could not be found. Please choose another result." if response.code == "404"
    raise Unavailable, UNAVAILABLE_MESSAGE unless response.is_a?(Net::HTTPSuccess)

    body = response.body
    raise Unavailable, UNAVAILABLE_MESSAGE unless body.is_a?(String) && body.present?

    data = JSON.parse(body)
    raise Unavailable, UNAVAILABLE_MESSAGE unless data.is_a?(Hash)

    data
  rescue JSON::ParserError, IOError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError
    # Never expose the URL, API key, response body or original exception message.
    raise Unavailable, UNAVAILABLE_MESSAGE, cause: nil
  end

  def normalize(data, media_type)
    title = data[media_type == "movie" ? "title" : "name"]
    id = data["id"]
    return unless id.is_a?(Integer) && id.positive? && title.is_a?(String) && title.present?

    date = data[media_type == "movie" ? "release_date" : "first_air_date"].to_s
    rating = data["vote_average"]
    {
      tmdb_id: id, media_type: media_type, title: title,
      overview: data["overview"].is_a?(String) ? data["overview"].presence : nil,
      release_year: date.match?(/\A\d{4}-\d{2}-\d{2}\z/) ? date.first(4).to_i : nil,
      tmdb_rating: rating.is_a?(Numeric) && rating.between?(0, 10) && data["vote_count"].is_a?(Numeric) && data["vote_count"].positive? ? rating.round(1) : nil,
      age_rating: nil, poster_path: self.class.poster_url(data["poster_path"]) ? data["poster_path"] : nil
    }
  end

  def certification(data, media_type)
    key = media_type == "movie" ? "release_dates" : "content_ratings"
    ratings = data[key]
    return unless ratings.is_a?(Hash) && ratings["results"].is_a?(Array)

    country = ratings["results"].find { |entry| entry.is_a?(Hash) && entry["iso_3166_1"] == "US" }
    return unless country
    return country["rating"].is_a?(String) ? country["rating"].presence : nil if media_type == "tv"

    releases = country["release_dates"]
    return unless releases.is_a?(Array)

    releases = releases.select { |entry| entry.is_a?(Hash) }
    # Prefer theatrical certification, falling back to another US release.
    releases.sort_by { |release| release["type"] == 3 ? 0 : 1 }.filter_map { |release| release["certification"].presence if release["certification"].is_a?(String) }.first
  end
end
