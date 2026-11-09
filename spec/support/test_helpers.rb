module TestHelpers
  def user_attributes(**overrides)
    {
      display_name: "Alex",
      email: "alex-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(overrides)
  end

  def create_user(**overrides)
    User.create!(user_attributes(**overrides))
  end

  def sign_in(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
    expect(response).to redirect_to(groups_path)
  end

  def page_props
    inertia.props.deep_stringify_keys
  end
end
