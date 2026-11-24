require "rails_helper"

RSpec.describe TmdbClient do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:client) { described_class.new(api_key: "private-test-key", cache: cache) }
  let(:movie) do
    { "id" => 11, "media_type" => "movie", "title" => "Star Wars", "overview" => "A space adventure.",
      "release_date" => "1977-05-25", "vote_average" => 8.24, "vote_count" => 100, "poster_path" => "/poster.jpg" }
  end

  def response_for(body, code: "200")
    response = case code
    when "200" then Net::HTTPOK.new("1.1", code, "OK")
    when "204" then Net::HTTPNoContent.new("1.1", code, "No Content")
    when "404" then Net::HTTPNotFound.new("1.1", code, "Not Found")
    else Net::HTTPServiceUnavailable.new("1.1", code, "Unavailable")
    end
    allow(response).to receive(:body).and_return(body.nil? || body.is_a?(String) ? body : body.to_json)
    response
  end

  def stub_response(body, code: "200")
    http = instance_double(Net::HTTP)
    allow(http).to receive(:max_retries=).with(0)
    allow(http).to receive(:get).and_return(response_for(body, code: code))
    allow(Net::HTTP).to receive(:start).and_yield(http)
    http
  end

  it "searches only movies/TV, normalizes display fields and caches repeated queries" do
    http = stub_response({ "results" => [ movie, movie.merge("media_type" => "person"), movie.merge("adult" => true), {} ] })
    result = client.search("  Star   Wars ")

    expect(result).to eq([ {
      tmdb_id: 11, media_type: "movie", title: "Star Wars", overview: "A space adventure.",
      release_year: 1977, tmdb_rating: 8.2, age_rating: nil, poster_path: "/poster.jpg"
    } ])
    expect(client.search("star wars")).to eq(result)
    expect(http).to have_received(:get).once.with(a_string_including("query=Star+Wars", "include_adult=false"), "Accept" => "application/json")
    expect(Net::HTTP).to have_received(:start).with("api.themoviedb.org", 443, use_ssl: true, open_timeout: 1, read_timeout: 2, write_timeout: 2)
    expect(result.to_json).not_to include("private-test-key")
  end

  it "skips short queries and rejects excessive queries without contacting TMDB" do
    expect(Net::HTTP).not_to receive(:start)
    expect(client.search(" ")).to eq([])
    expect(client.search("a")).to eq([])
    expect { client.search("a" * 121) }.to raise_error(TmdbClient::InvalidSelection)
  end

  it "fetches movie details with the US theatrical certification" do
    http = stub_response(movie.merge("release_dates" => { "results" => [
      { "iso_3166_1" => "GB", "release_dates" => [ { "type" => 3, "certification" => "U" } ] },
      { "iso_3166_1" => "US", "release_dates" => [ { "type" => 4, "certification" => "G" }, { "type" => 3, "certification" => "PG" } ] }
    ] }))

    expect(client.details("movie", "11")).to include(age_rating: "PG")
    expect(http).to have_received(:get).with(a_string_including("/movie/11?", "append_to_response=release_dates"), anything)
  end

  it "fetches TV details and its content rating, allowing unknown metadata" do
    stub_response({ "id" => 1399, "name" => "A TV series", "first_air_date" => "", "vote_average" => 0,
      "vote_count" => 0, "poster_path" => "https://unsafe.example/poster.jpg",
      "content_ratings" => { "results" => [ { "iso_3166_1" => "US", "rating" => "TV-14" } ] } })

    expect(client.details("tv", 1399)).to include(title: "A TV series", release_year: nil, tmdb_rating: nil,
      poster_path: nil, overview: nil, age_rating: "TV-14")
  end

  it "does not substitute another country's age classification" do
    stub_response(movie.merge("release_dates" => { "results" => [
      { "iso_3166_1" => "GB", "release_dates" => [ { "type" => 3, "certification" => "U" } ] }
    ] }))
    expect(client.details("movie", 11)[:age_rating]).to be_nil
  end

  it "rejects an upstream response for a different title instead of saving the wrong movie" do
    stub_response(movie.merge("id" => 12))

    expect { client.details("movie", 11) }.to raise_error(TmdbClient::InvalidSelection, /unavailable/)
  end

  it "skips malformed search entries and preserves usable titles when optional metadata has unexpected types" do
    malformed = [ nil, "invalid", movie.merge("id" => "11"), movie.merge("title" => " "), movie.merge("id" => -1) ]
    usable = movie.merge("overview" => {}, "release_date" => "unknown", "vote_average" => "8.2", "vote_count" => {})
    invalid_vote_count = movie.merge("id" => 12, "vote_count" => {})
    stub_response({ "results" => malformed + [ usable, invalid_vote_count ] })

    expect(client.search("Star")).to contain_exactly(
      a_hash_including(tmdb_id: 11, title: "Star Wars", overview: nil, release_year: nil, tmdb_rating: nil),
      a_hash_including(tmdb_id: 12, title: "Star Wars", tmdb_rating: nil)
    )
  end

  it "does not invent an age rating from malformed certification data" do
    invalid_releases = [ "invalid", { "results" => {} }, { "results" => [ nil, "invalid" ] },
      { "results" => [ { "iso_3166_1" => "US", "release_dates" => {} } ] },
      { "results" => [ { "iso_3166_1" => "US", "release_dates" => [ nil, { "certification" => [] } ] } ] } ]
    invalid_releases.each do |releases|
      cache.clear
      stub_response(movie.merge("release_dates" => releases))
      expect(client.details("movie", 11)[:age_rating]).to be_nil
    end
    stub_response(movie.merge("name" => "A TV show", "content_ratings" => { "results" => [ { "iso_3166_1" => "US", "rating" => [] } ] }))
    expect(client.details("tv", 11)[:age_rating]).to be_nil
  end

  it "uses a valid US non-theatrical certification when theatrical certification is absent" do
    stub_response(movie.merge("release_dates" => { "results" => [
      { "iso_3166_1" => "US", "release_dates" => [ { "type" => 3, "certification" => "" }, { "type" => 4, "certification" => "PG-13" } ] }
    ] }))

    expect(client.details("movie", 11)[:age_rating]).to eq("PG-13")
  end

  it "keeps cached movie and TV details separate even when their numeric IDs match" do
    http = stub_response(movie)
    tv = { "id" => 11, "name" => "A different TV show", "first_air_date" => "2020-01-01" }
    allow(http).to receive(:get).and_return(response_for(movie), response_for(tv))

    expect(client.details("movie", 11)).to include(title: "Star Wars", media_type: "movie")
    expect(client.details("tv", 11)).to include(title: "A different TV show", media_type: "tv")
    expect(client.details("movie", "11")).to include(title: "Star Wars", media_type: "movie")
    expect(client.details("tv", "11")).to include(title: "A different TV show", media_type: "tv")
    expect(http).to have_received(:get).exactly(2).times
  end

  it "refreshes expired catalog details while reusing recent results" do
    http = stub_response(movie)
    expect(client.details("movie", 11)[:tmdb_rating]).to eq(8.2)
    allow(http).to receive(:get).and_return(response_for(movie.merge("vote_average" => 8.6)))

    travel 1.hour do
      expect(client.details("movie", 11)[:tmdb_rating]).to eq(8.2)
    end
    travel 13.hours do
      expect(client.details("movie", 11)[:tmdb_rating]).to eq(8.6)
    end
    expect(http).to have_received(:get).exactly(2).times
  end

  it "rejects invalid identities before making network calls" do
    expect(Net::HTTP).not_to receive(:start)
    [ [ "person", 11 ], [ "movie", "1/credits" ], [ "tv", -1 ], [ nil, 11 ], [ "movie", "1?api_key=x" ] ].each do |type, id|
      expect { client.details(type, id) }.to raise_error(TmdbClient::InvalidSelection)
    end
  end

  it "reports missing credentials without making network calls" do
    expect(Net::HTTP).not_to receive(:start)
    expect { described_class.new(api_key: "").search("Heat") }.to raise_error(TmdbClient::Unavailable, TmdbClient::UNAVAILABLE_MESSAGE)
  end

  it "handles unavailable, invalid JSON and malformed search responses without exposing credentials or upstream bodies" do
    [ [ "private-test-key", "401" ], [ "private-test-key", "429" ], [ "private-test-key", "503" ],
      [ "private-test-key", "200" ], [ [], "200" ], [ {}, "200" ] ].each do |body, code|
      stub_response(body, code: code)
      expect { client.search("Heat") }.to raise_error(TmdbClient::Unavailable, TmdbClient::UNAVAILABLE_MESSAGE)
    end
  end

  it "reports empty success responses as unavailable instead of exposing a parser exception" do
    [ "200", "204" ].each do |code|
      stub_response(nil, code: code)
      expect { client.details("movie", 11) }.to raise_error(TmdbClient::Unavailable, TmdbClient::UNAVAILABLE_MESSAGE)
    end
  end

  it "does not follow upstream redirects, keeping the credential on TMDB's host" do
    response = Net::HTTPFound.new("1.1", "302", "Found")
    response["Location"] = "https://untrusted.example/collect"
    http = stub_response("ignored")
    allow(http).to receive(:get).and_return(response)

    expect { client.search("Heat") }.to raise_error(TmdbClient::Unavailable, TmdbClient::UNAVAILABLE_MESSAGE)
    expect(Net::HTTP).to have_received(:start).once.with("api.themoviedb.org", 443, use_ssl: true, open_timeout: 1, read_timeout: 2, write_timeout: 2)
    expect(http).to have_received(:get).once
  end

  it "recovers once the short outage window passes instead of caching an error with the result" do
    http = stub_response("upstream failure", code: "503")
    expect { client.details("movie", 11) }.to raise_error(TmdbClient::Unavailable)
    allow(http).to receive(:get).and_return(response_for(movie))

    travel(TmdbClient::OUTAGE_TTL + 1.second) do
      expect(client.details("movie", 11)).to include(title: "Star Wars")
    end
    expect(http).to have_received(:get).exactly(2).times
  end

  it "handles missing/deleted titles and adult titles" do
    stub_response("private-test-key", code: "404")
    expect { client.details("movie", 11) }.to raise_error(TmdbClient::InvalidSelection, /could not be found/)
    stub_response(movie.merge("adult" => true))
    expect { client.details("movie", 11) }.to raise_error(TmdbClient::InvalidSelection, /unavailable/)
  end

  it "sanitizes timeout and TLS errors and removes the underlying exception cause" do
    [ Net::ReadTimeout, OpenSSL::SSL::SSLError ].each do |error|
      allow(Net::HTTP).to receive(:start).and_raise(error, "private-test-key")
      expect { client.search("Heat") }.to raise_error(TmdbClient::Unavailable) { |failure|
        expect(failure.message).to eq(TmdbClient::UNAVAILABLE_MESSAGE)
        expect(failure.cause).to be_nil
      }
    end
  end

  it "only builds poster URLs on the TMDB image CDN" do
    expect(described_class.poster_url("/poster.jpg")).to eq("https://image.tmdb.org/t/p/w342/poster.jpg")
    [ nil, "//evil.example/image.jpg", "/../../etc/passwd", "https://example.com/a.jpg" ].each do |path|
      expect(described_class.poster_url(path)).to be_nil
    end
  end

  describe "#watch_providers" do
    it "returns US watch providers by availability type and caches results" do
      http = stub_response({
        "results" => {
          "US" => {
            "flatrate" => [ { "provider_name" => "Netflix" } ],
            "rent" => [ { "provider_name" => "Amazon Video" } ],
            "buy" => [ { "provider_name" => "Apple TV" } ],
            "free" => [ { "provider_name" => "Plex" } ],
            "ads" => [ { "provider_name" => "Tubi" } ]
          },
          "GB" => {
            "flatrate" => [ { "provider_name" => "BBC iPlayer" } ]
          }
        }
      })

      expected = {
        region: "US",
        streaming: [ "Netflix" ],
        rent: [ "Amazon Video" ],
        buy: [ "Apple TV" ],
        free: [ "Plex" ],
        ads: [ "Tubi" ]
      }

      expect(client.watch_providers("movie", 11)).to eq(expected)
      expect(client.watch_providers("movie", "11")).to eq(expected)
      expect(http).to have_received(:get).once.with(
        a_string_including("/movie/11/watch/providers?"), anything
      )
    end

    it "returns empty availability when US providers are missing" do
      stub_response({ "results" => { "GB" => {} } })

      expect(client.watch_providers("tv", 11)).to eq({
        region: "US",
        streaming: [],
        rent: [],
        buy: [],
        free: [],
        ads: []
      })
    end

    it "filters malformed and duplicate provider names" do
      stub_response({
        "results" => {
          "US" => {
            "flatrate" => [
              nil,
              "invalid",
              {},
              { "provider_name" => 123 },
              { "provider_name" => " " },
              { "provider_name" => " Netflix " },
              { "provider_name" => "Netflix" }
            ],
            "rent" => {}
          }
        }
      })

      result = client.watch_providers("tv", 11)

      expect(result[:streaming]).to eq([ "Netflix" ])
      expect(result[:rent]).to eq([])
    end

    it "rejects invalid title identities without contacting TMDB" do
      expect(Net::HTTP).not_to receive(:start)

      expect { client.watch_providers("person", 11) }
        .to raise_error(TmdbClient::InvalidSelection)

      expect { client.watch_providers("movie", -1) }
        .to raise_error(TmdbClient::InvalidSelection)
    end

    it "handles malformed availability responses" do
      stub_response({ "results" => [] })

      expect { client.watch_providers("movie", 11) }
        .to raise_error(TmdbClient::Unavailable)
    end

    it "handles upstream failures" do
      stub_response(nil, code: "503")

      expect { client.watch_providers("tv", 11) }
        .to raise_error(TmdbClient::Unavailable)
    end
  end

  describe "after TMDB fails" do
    it "skips TMDB for a short while, then tries again" do
      stub_response(nil, code: "503")
      expect { client.search("Heat") }.to raise_error(TmdbClient::Unavailable)

      expect { client.search("Alien") }.to raise_error(TmdbClient::Unavailable, TmdbClient::UNAVAILABLE_MESSAGE)
      expect(Net::HTTP).to have_received(:start).once

      travel(31.seconds) do
        stub_response({ "results" => [ movie ] })
        expect(client.search("Alien").map { |title| title[:title] }).to eq([ "Star Wars" ])
      end
    end

    it "treats network errors the same way" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
      expect { client.search("Heat") }.to raise_error(TmdbClient::Unavailable)
      expect { client.details("movie", 11) }.to raise_error(TmdbClient::Unavailable)

      expect(Net::HTTP).to have_received(:start).once
    end

    it "does not record an outage for a missing title" do
      stub_response(nil, code: "404")
      expect { client.details("movie", 11) }.to raise_error(TmdbClient::InvalidSelection)

      stub_response({ "results" => [ movie ] })
      expect(client.search("Star")).to be_present
    end
  end
end
