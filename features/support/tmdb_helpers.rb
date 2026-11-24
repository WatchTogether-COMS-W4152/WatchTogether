require "net/http"
require "rspec/mocks"

module TmdbHelpers
  FAKE_API_KEY = "acceptance-test-key-not-a-real-secret"
  TITLES = {
    [ "movie", 329865 ] => {
      "id" => 329865, "title" => "Arrival", "media_type" => "movie", "release_date" => "2016-11-11",
      "overview" => "A linguist searches for meaning in an alien language.", "poster_path" => "/arrival.jpg",
      "vote_average" => 7.6, "vote_count" => 200,
      "release_dates" => { "results" => [
        { "iso_3166_1" => "GB", "release_dates" => [ { "type" => 3, "certification" => "12A" } ] },
        { "iso_3166_1" => "US", "release_dates" => [ { "type" => 3, "certification" => "PG-13" } ] }
      ] }
    },
    [ "tv", 63639 ] => {
      "id" => 63639, "name" => "The Expanse", "media_type" => "tv", "first_air_date" => "2015-12-14",
      "overview" => "A missing person brings a scattered crew together across the solar system.",
      "poster_path" => "/expanse.jpg", "vote_average" => 8.1, "vote_count" => 100,
      "seasons" => [
        { "season_number" => 0, "episode_count" => 3 },
        { "season_number" => 1, "episode_count" => 10 },
        { "season_number" => 2, "episode_count" => 13 }
      ],
      "content_ratings" => { "results" => [ { "iso_3166_1" => "US", "rating" => "TV-14" } ] }
    },
    [ "tv", 329865 ] => {
      "id" => 329865, "name" => "Arrival: The Series", "media_type" => "tv", "first_air_date" => "2018-03-01",
      "overview" => "A television series that is distinct from the movie.",
      "poster_path" => "/arrivalseries.jpg", "vote_average" => 7.2, "vote_count" => 50,
      "content_ratings" => { "results" => [ { "iso_3166_1" => "US", "rating" => "TV-14" } ] }
    },
    [ "movie", 999001 ] => {
      "id" => 999001, "title" => "Arrival", "media_type" => "movie", "release_date" => "1996-05-31",
      "overview" => "A different movie with the same name.", "vote_average" => 6.1, "vote_count" => 10
    },
    [ "tv", 999002 ] => {
      "id" => 999002, "name" => "Unannounced Series", "media_type" => "tv", "first_air_date" => "",
      "overview" => "", "poster_path" => nil, "vote_average" => 0, "vote_count" => 0
    }
  }.freeze

  def catalogue_type(kind)
    kind == "movie" ? "movie" : "tv"
  end

  def visit_catalogue(path, fields = {})
    browser.get(path, fields, WebHelpers::HEADERS.except("HTTP_X_INERTIA", "HTTP_X_INERTIA_VERSION").merge("HTTP_ACCEPT" => "application/json"))
    @response = browser.last_response
    @catalogue = JSON.parse(@response.body)
  end

  def expected_catalogue_details(title)
    if title == "Arrival"
      { "tmdb_id" => 329865, "media_type" => "movie", "title" => "Arrival", "release_year" => 2016,
        "tmdb_rating" => 7.6, "age_rating" => "PG-13", "overview" => TITLES.fetch([ "movie", 329865 ]).fetch("overview"),
        "poster_url" => "https://image.tmdb.org/t/p/w342/arrival.jpg" }
    else
      { "tmdb_id" => 63639, "media_type" => "tv", "title" => "The Expanse", "release_year" => 2015,
        "tmdb_rating" => 8.1, "age_rating" => "TV-14", "overview" => TITLES.fetch([ "tv", 63639 ]).fetch("overview"),
        "poster_url" => "https://image.tmdb.org/t/p/w342/expanse.jpg" }
    end
  end

  def catalogue_http_response(request_path)
    if @catalogue_unavailable
      response = Net::HTTPServiceUnavailable.new("1.1", "503", "Unavailable")
      allow(response).to receive(:body).and_return("Injected upstream failure #{FAKE_API_KEY}")
      return response
    end

    uri = URI.parse(request_path)
    data = if uri.path == "/3/search/multi"
      query = URI.decode_www_form(uri.query).to_h.fetch("query").downcase
      matches = TITLES.values.select { |entry| (entry["title"] || entry["name"]).downcase.include?(query) }
      { "results" => matches + [
        { "id" => 10, "media_type" => "person", "name" => "A Person" },
        { "id" => 11, "media_type" => "movie", "title" => "Adult result", "adult" => true }
      ] }
    elsif uri.path.end_with?("/watch/providers")
      _, _, media_type, id = uri.path.split("/")

      if media_type == "movie" && id.to_i == 329865
        {
          "results" => {
            "US" => {
              "flatrate" => [ { "provider_name" => "Netflix" } ],
              "rent" => [ { "provider_name" => "Amazon Video" } ],
              "buy" => [ { "provider_name" => "Apple TV Store" } ]
            },
            "GB" => {
              "flatrate" => [ { "provider_name" => "BBC iPlayer" } ]
            }
          }
        }
      else
        { "results" => {} }
      end
    else
      _, _, media_type, id = uri.path.split("/")
      TITLES[[ media_type, id.to_i ]]
    end
    return Net::HTTPNotFound.new("1.1", "404", "Not Found") unless data

    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(JSON.generate(data))
    response
  end
end

World(TmdbHelpers)
World(RSpec::Mocks::ExampleMethods)

Before("@tmdb") do
  RSpec::Mocks.setup
  allow(ENV).to receive(:[]).and_call_original
  allow(ENV).to receive(:[]).with("TMDB_API_KEY").and_return(TmdbHelpers::FAKE_API_KEY)
  http = double("TMDB HTTP connection", "max_retries=" => nil)
  allow(http).to receive(:get) { |path, _headers| catalogue_http_response(path) }
  allow(Net::HTTP).to receive(:start) do |host, port, **options, &request|
    expect(host).to eq("api.themoviedb.org")
    expect(port).to eq(443)
    expect(options.fetch(:use_ssl)).to be(true)
    request.call(http)
  end
end

After("@tmdb") do
  RSpec::Mocks.verify
ensure
  RSpec::Mocks.teardown
end
