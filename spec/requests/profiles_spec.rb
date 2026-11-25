require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let(:user) { create_user }
  before { sign_in(user) }

  it "renders the current user's profile without secret fields" do
    get profile_path
    expect(inertia).to render_component("profile/show")
    expect(page_props.dig("auth", "user").keys).to contain_exactly("id", "display_name", "email")
  end

  it "persists an edited and trimmed display name" do
    patch profile_path, params: { display_name: " Sam " }
    expect(response).to redirect_to(profile_path)
    follow_redirect!
    expect(user.reload.display_name).to eq("Sam")
    expect(page_props.dig("auth", "user", "display_name")).to eq("Sam")
  end

  it "rejects invalid edits and preserves the current name" do
    [ " ", "x" * 51 ].each do |name|
      patch profile_path, params: { display_name: name }
      follow_redirect!
      expect(page_props.dig("errors", "display_name")).not_to be_empty
      expect(user.reload.display_name).to eq("Alex")
    end
  end

  it "saves, replaces, and clears the services the member pays for" do
    patch profile_path, params: { streaming_services: "1", provider_ids: [ 8, 15, 999_999, "nope" ] }

    expect(response).to redirect_to(profile_path)
    follow_redirect!
    expect(user.streaming_subscriptions.pluck(:provider_id)).to contain_exactly(8, 15)
    expect(page_props["selected_service_ids"]).to eq([ 8, 15 ])
    expect(page_props["services"].map { |service| service["id"] }).to eq(StreamingService::IDS)

    patch profile_path, params: { streaming_services: "1", provider_ids: [ 9 ] }
    follow_redirect!
    expect(user.streaming_subscriptions.pluck(:provider_id)).to eq([ 9 ])

    patch profile_path, params: { streaming_services: "1" }
    follow_redirect!
    expect(user.streaming_subscriptions).to be_empty
    expect(page_props["selected_service_ids"]).to eq([])
  end

  it "does not let a streaming update change the display name or another account" do
    other = create_user(display_name: "Sam")

    patch profile_path, params: {
      streaming_services: "1", provider_ids: [ 8 ], display_name: "Hacker", user_id: other.id
    }

    expect(user.reload.display_name).to eq("Alex")
    expect(user.streaming_subscriptions.pluck(:provider_id)).to eq([ 8 ])
    expect(other.streaming_subscriptions).to be_empty
  end

  it "requires sign-in before saving streaming services" do
    delete "/session"
    patch profile_path, params: { streaming_services: "1", provider_ids: [ 8 ] }

    expect(response).to redirect_to(sign_in_path)
    expect(user.streaming_subscriptions).to be_empty
  end

  it "does not let profile editing change email, password, or another user's id" do
    original_digest = user.password_digest
    patch profile_path, params: { display_name: "Sam", email: "changed@example.com", password: "newpassword123", id: user.id + 1 }
    expect(user.reload.email).not_to eq("changed@example.com")
    expect(user.password_digest).to eq(original_digest)
    expect(user.display_name).to eq("Sam")
  end
end
