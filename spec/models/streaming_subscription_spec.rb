require "rails_helper"

RSpec.describe StreamingSubscription, type: :model do
  it "rejects a service the catalogue does not offer" do
    subscription = create_user.streaming_subscriptions.build(provider_id: 1)

    expect(subscription).not_to be_valid
    expect(subscription.errors[:provider_id]).to be_present
  end

  it "rejects a duplicate service for the same member" do
    user = create_user
    user.streaming_subscriptions.create!(provider_id: 8)
    duplicate = user.streaming_subscriptions.build(provider_id: 8)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:provider_id]).to include("has already been taken")
    expect {
      StreamingSubscription.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects an unknown service at the database when validation is skipped" do
    subscription = create_user.streaming_subscriptions.build(provider_id: 1)

    expect {
      StreamingSubscription.transaction(requires_new: true) { subscription.save!(validate: false) }
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "deletes a member's services when the account is deleted" do
    user = create_user
    user.streaming_subscriptions.create!(provider_id: 8)

    user.destroy!

    expect(StreamingSubscription.where(user_id: user.id)).to be_empty
  end
end

RSpec.describe User, type: :model do
  it "replaces the services a member pays for and ignores ids outside the catalogue" do
    user = create_user
    user.replace_streaming_services!([ 8, 15 ])

    user.replace_streaming_services!([ "9", 8, 8, "nope", 1 ])

    expect(user.streaming_subscriptions.pluck(:provider_id)).to contain_exactly(8, 9)
  end

  it "clears every service when the saved set is empty" do
    user = create_user
    user.replace_streaming_services!([ 8 ])

    user.replace_streaming_services!([])

    expect(user.streaming_subscriptions).to be_empty
  end
end
