require "rails_helper"

RSpec.describe "Accounts and sessions", type: :request do
  it "renders public registration and sign-in screens" do
    get sign_up_path
    expect(inertia).to render_component("auth/sign-up")
    expect(page_props.dig("auth", "user")).to be_nil
    get sign_in_path
    expect(inertia).to render_component("auth/sign-in")
  end

  it "registers a normalized profile and signs in with a protected cookie" do
    expect {
      post sign_up_path, params: user_attributes(email: " ALEX@EXAMPLE.COM ", display_name: " Alex ")
    }.to change(User, :count).by(1).and change(Session, :count).by(1)
    expect(response).to have_http_status(:see_other)
    cookie_header = Array(response.headers["Set-Cookie"]).join("\n")
    expect(cookie_header).to include("session_token=", "httponly", "samesite=lax", "expires=")
    follow_redirect!
    expect(page_props.dig("auth", "user")).to eq({ "id" => User.last.id, "display_name" => "Alex", "email" => "alex@example.com" })
    expect(page_props.to_json).not_to include("password_digest", "token_digest", "password123")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "sets the Secure cookie flag in production" do
    allow(Rails.env).to receive(:production?).and_return(true)
    https!
    post sign_up_path, params: user_attributes
    expect(Array(response.headers["Set-Cookie"]).join("\n")).to match(/session_token=[^\n]*secure/i)
  ensure
    https!(false)
  end

  it "rejects invalid registration without creating users or sessions" do
    expect {
      post sign_up_path, params: { display_name: " ", email: "invalid", password: "short", password_confirmation: "different" }
    }.not_to change(User, :count)
    expect(Session.count).to eq(0)
    expect(response).to redirect_to(sign_up_path)
    follow_redirect!
    expect(page_props["errors"].keys).to include("display_name", "email", "password", "password_confirmation")
  end

  it "rejects duplicate emails regardless of letter case" do
    create_user(email: "alex@example.com")
    expect {
      post sign_up_path, params: user_attributes(email: " ALEX@EXAMPLE.COM ")
    }.not_to change(User, :count)
    follow_redirect!
    expect(page_props.dig("errors", "email")).to include("has already been taken")
  end

  it "handles a duplicate-email race without an unhandled database error" do
    allow_any_instance_of(User).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
    post sign_up_path, params: user_attributes
    follow_redirect!
    expect(page_props.dig("errors", "email")).to include("has already been taken")
  end

  it "signs in with normalized email and correct credentials" do
    user = create_user(email: "alex@example.com")
    post sign_in_path, params: { email: " ALEX@EXAMPLE.COM ", password: "password123" }
    expect(response).to have_http_status(:see_other)
    follow_redirect!
    expect(page_props.dig("auth", "user", "id")).to eq(user.id)
  end

  it "uses the same validation error for unknown users and wrong passwords" do
    user = create_user
    [ "missing@example.com", user.email ].each do |email|
      post sign_in_path, params: { email: email, password: "wrong" }
      expect(response).to redirect_to(sign_in_path)
      follow_redirect!
      expect(page_props.dig("errors", "email")).to eq([ "Email or password is incorrect." ])
    end
    expect(Session.count).to eq(0)
  end

  it "redirects authenticated visitors away from the account forms" do
    sign_in(create_user)
    [ sign_up_path, sign_in_path ].each do |path|
      get path
      expect(response).to redirect_to(groups_path)
    end
  end

  it "replaces the existing browser session when signing in again" do
    user = create_user
    sign_in(user)
    old_session = user.sessions.last
    sign_in(user)
    expect(Session.exists?(old_session.id)).to be(false)
    expect(user.sessions.count).to eq(1)
  end

  it "revokes logout server-side even if the old cookie is replayed" do
    user = create_user
    sign_in(user)
    old_cookie = cookies[:session_token]
    expect { delete session_path }.to change(Session, :count).by(-1)
    expect(response).to redirect_to(sign_in_path)
    follow_redirect!
    expect(page_props.dig("auth", "user")).to be_nil
    cookies[:session_token] = old_cookie
    get groups_path
    expect(response).to redirect_to(sign_in_path)
  end

  it "does not revoke another device's session on logout" do
    user = create_user
    other_session, other_token = Session.issue!(user)
    sign_in(user)
    delete session_path
    expect(Session.authenticate(other_token)).to eq(other_session)
  end

  it "redirects expired sessions to sign-in and clears their cookie" do
    user = create_user
    sign_in(user)
    user.sessions.last.update!(expires_at: 1.second.ago)
    get groups_path
    expect(response).to redirect_to(sign_in_path)
    expect(cookies[:session_token]).to be_blank
    follow_redirect!
    expect(page_props.dig("flash", "alert")).to include("expired")
  end

  it "does not trust a forged session cookie" do
    cookies[:session_token] = "forged-token"
    get groups_path
    expect(response).to redirect_to(sign_in_path)
  end

  it "requires a session for all private pages and writes" do
    [ root_path, groups_path, new_group_path, join_groups_path, profile_path, group_path(999) ].each do |path|
      get path
      expect(response).to redirect_to(sign_in_path)
    end
    post groups_path, params: { name: "Not signed in" }
    expect(response).to redirect_to(sign_in_path)
    expect(Group.count).to eq(0)
    post join_groups_path, params: { code: "unknown" }
    expect(response).to redirect_to(sign_in_path)
    patch profile_path, params: { display_name: "Changed" }
    expect(response).to redirect_to(sign_in_path)
    post group_reset_invitation_path(999)
    expect(response).to redirect_to(sign_in_path)
  end

  it "limits registration and login attempts" do
    10.times { post sign_up_path, params: { email: "invalid" } }
    post sign_up_path, params: user_attributes
    expect(response).to have_http_status(:too_many_requests)
    expect(User.count).to eq(0)
    10.times { post sign_in_path, params: { email: "missing@example.com", password: "wrong" } }
    post sign_in_path, params: { email: "missing@example.com", password: "wrong" }
    expect(response).to have_http_status(:too_many_requests)
    expect(page_props["message"]).to include("Too many")
  end

  it "enforces CSRF protection and accepts a valid same-session token" do
    previous = ApplicationController.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true
    post sign_up_path, params: user_attributes
    expect(response).to have_http_status(:unprocessable_content)
    expect(User.count).to eq(0)
    get sign_up_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    post sign_up_path, params: user_attributes, headers: { "X-CSRF-Token" => token }
    expect(response).to redirect_to(groups_path)
    expect(User.count).to eq(1)
  ensure
    ApplicationController.allow_forgery_protection = previous
  end
end
