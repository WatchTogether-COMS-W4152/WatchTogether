require "rails_helper"

RSpec.describe GroupWatchability, type: :service do
  def member(name, *service_ids)
    user = create_user(display_name: name)
    service_ids.each { |id| user.streaming_subscriptions.create!(provider_id: id) }
    user
  end

  def title(tmdb_id: 11, media_type: "movie")
    WatchlistItem.new(title: "Title", tmdb_id: tmdb_id, media_type: media_type)
  end

  def availability(**lists)
    {
      region: "US",
      streaming: [], streaming_ids: [],
      rent: [], buy: [],
      free: [], ads: []
    }.merge(lists)
  end

  def result_for(record, members, providers)
    client = instance_double(TmdbClient)
    if providers
      allow(client).to receive(:watch_providers).with(record.media_type, record.tmdb_id).and_return(providers)
    else
      allow(client).to receive(:watch_providers).and_raise(TmdbClient::Unavailable)
    end
    described_class.for(record, members: members, client: client)
  end

  it "includes a title every member can watch on a service they pay for" do
    alice = member("Alice", 8)
    bob = member("Bob", 8, 15)

    result = result_for(title, [ bob, alice ], availability(streaming: [ "Netflix" ], streaming_ids: [ 8 ]))

    expect(result).to eq("included" => true, "label" => "On everyone's services")
  end

  it "includes a free or ad-supported title when a member has listed no services" do
    alice = member("Alice")

    free = result_for(title, [ alice ], availability(free: [ "Plex" ]))
    ads = result_for(title(tmdb_id: 12), [ alice ], availability(ads: [ "Tubi" ]))

    expect(free).to eq("included" => true, "label" => "On everyone's services")
    expect(ads).to eq("included" => true, "label" => "On everyone's services")
  end

  it "does not treat rent or buy as covered, and names uncovered members in display-name order" do
    bob = member("Bob", 8)
    alice = member("Alice", 8)
    carol = member("Carol")
    rent_only = availability(rent: [ "Amazon Video" ])
    buy_only = availability(buy: [ "Apple TV" ], streaming_ids: [ 15 ])

    expect(result_for(title, [ bob ], rent_only)).to eq("included" => false, "label" => "Bob needs a rental")
    expect(result_for(title(tmdb_id: 12), [ bob, alice ], rent_only)).to eq(
      "included" => false, "label" => "Alice and Bob need a rental"
    )
    expect(result_for(title(tmdb_id: 13), [ carol, bob, alice ], rent_only)).to eq(
      "included" => false, "label" => "Alice, Bob, and Carol need a rental"
    )
    expect(result_for(title(tmdb_id: 14), [ alice ], buy_only)).to eq(
      "included" => false, "label" => "Alice needs a rental"
    )
  end

  it "says a title is not available when nobody can rent or buy it either" do
    alice = member("Alice", 8)

    result = result_for(title, [ alice ], availability(streaming: [ "Hulu" ], streaming_ids: [ 15 ]))

    expect(result).to eq("included" => false, "label" => "Not available for Alice")
  end

  it "explains an empty US result, a manual title, and a TMDB failure without raising" do
    alice = member("Alice", 8)
    client = instance_double(TmdbClient)
    manual = WatchlistItem.new(title: "Home movie", manual_media_type: "movie")

    expect(client).not_to receive(:watch_providers)
    expect(described_class.for(manual, members: [ alice ], client: client)).to eq(
      "included" => false, "label" => described_class::MANUAL_LABEL
    )
    expect(result_for(title, [ alice ], availability)).to eq(
      "included" => false, "label" => described_class::EMPTY_LABEL
    )
    expect(result_for(title(tmdb_id: 12), [ alice ], nil)).to eq(
      "included" => false, "label" => described_class::UNAVAILABLE_LABEL
    )
  end

  it "ignores someone who has left the group" do
    alice = member("Alice", 8)
    member("Bob")

    result = result_for(title, [ alice ], availability(streaming: [ "Netflix" ], streaming_ids: [ 8 ]))

    expect(result).to eq("included" => true, "label" => "On everyone's services")
  end
end
