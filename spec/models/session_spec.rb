require "rails_helper"

RSpec.describe Session, type: :model do
  let(:user) { create_user }

  it "issues an unpredictable token and persists only its digest for 30 days" do
    freeze_time do
      session, token = Session.issue!(user)

      expect(token).to match(/\A[a-f0-9]{64}\z/)
      expect(session.token_digest).to eq(Digest::SHA256.hexdigest(token))
      expect(session.token_digest).not_to eq(token)
      expect(session.expires_at).to eq(30.days.from_now)
      expect(Session.authenticate(token)).to eq(session)
      expect(session.attributes.values).not_to include(token)
    end
  end

  it "supports separate sessions for multiple devices" do
    first, first_token = Session.issue!(user)
    second, second_token = Session.issue!(user)

    expect(first_token).not_to eq(second_token)
    first.destroy!
    expect(Session.authenticate(first_token)).to be_nil
    expect(Session.authenticate(second_token)).to eq(second)
  end

  it "rejects expired sessions, including at the exact expiry time" do
    freeze_time do
      session, token = Session.issue!(user)
      travel_to session.expires_at

      expect(Session.authenticate(token)).to be_nil
    end
  end

  it "rejects missing, malformed, and unknown tokens" do
    [ nil, "", "short", "A" * 64, "a" * 64 ].each do |token|
      expect(Session.authenticate(token)).to be_nil
    end
  end

  it "requires a user, digest, and expiry" do
    session = Session.new

    expect(session).not_to be_valid
    expect(session.errors).to include(:user, :token_digest, :expires_at)
  end

  it "enforces unique digests at the database" do
    existing, = Session.issue!(user)
    duplicate = existing.dup

    expect {
      Session.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
