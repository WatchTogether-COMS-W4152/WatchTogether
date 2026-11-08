require "rails_helper"

RSpec.describe User, type: :model do
  it "normalizes names and emails and stores a password hash" do
    user = create_user(display_name: " Alex ", email: " ALEX@Example.COM ")

    expect(user.display_name).to eq("Alex")
    expect(user.email).to eq("alex@example.com")
    expect(user.password_digest).not_to eq("password123")
    expect(user.authenticate("password123")).to eq(user)
    expect(user.authenticate("wrong-password")).to be(false)
  end

  it "rejects the same email regardless of case or surrounding spaces" do
    create_user(email: "alex@example.com")
    duplicate = User.new(user_attributes(email: " ALEX@EXAMPLE.COM "))

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "enforces unique emails at the database as well" do
    user = create_user
    duplicate = User.new(user_attributes(email: user.email))

    expect {
      User.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "requires a name and valid email" do
    user = User.new(user_attributes(display_name: " ", email: "not-an-email"))

    expect(user).not_to be_valid
    expect(user.errors).to include(:display_name, :email)
  end

  it "limits names and email addresses" do
    user = User.new(user_attributes(display_name: "a" * 51, email: "a" * 245 + "@example.com"))

    expect(user).not_to be_valid
    expect(user.errors).to include(:display_name, :email)
  end

  it "requires a password on registration" do
    user = User.new(user_attributes(password: nil, password_confirmation: nil))

    expect(user).not_to be_valid
    expect(user.errors[:password]).to include("can't be blank")
  end

  it "rejects short passwords and mismatching confirmation" do
    user = User.new(user_attributes(password: "short", password_confirmation: "different"))

    expect(user).not_to be_valid
    expect(user.errors).to include(:password, :password_confirmation)
  end

  it "rejects passwords above bcrypt's 72-byte limit, including multibyte input" do
    user = User.new(user_attributes(password: "é" * 37, password_confirmation: "é" * 37))

    expect(user).not_to be_valid
    expect(user.errors[:password]).not_to be_empty
  end

  it "allows updating a profile without setting the password again" do
    user = create_user.reload

    expect(user.update(display_name: "Sam")).to be(true)
    expect(user.authenticate("password123")).to eq(user)
  end
end
