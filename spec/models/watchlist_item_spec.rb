
require "rails_helper"

RSpec.describe WatchlistItem, type: :model do
  it "requires a title" do
    item = WatchlistItem.new(title: "")

    expect(item).not_to be_valid
    expect(item.errors[:title]).to be_present
  end

  it "does not allow titles longer than 120 characters" do
    item = WatchlistItem.new(title: "A" * 121)

    expect(item).not_to be_valid
  end

  it "belongs to a group" do
    expect(WatchlistItem.reflect_on_association(:group).macro).to eq(:belongs_to)
  end
end

