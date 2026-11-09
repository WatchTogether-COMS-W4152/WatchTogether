module WebHelpers
  PASSWORD = "CourseProject123!"
  HEADERS = {
    "HTTP_X_INERTIA" => "true",
    "HTTP_X_INERTIA_VERSION" => InertiaRails.configuration.version,
    "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
    "HTTP_ACCEPT" => "text/html, application/xhtml+xml",
    "HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/140.0.0.0 Safari/537.36"
  }.freeze

  def browser_for(name)
    @browsers[name] ||= Rack::Test::Session.new(Rack::MockSession.new(Rails.application))
  end

  def browser
    @browser ||= browser_for("visitor")
  end

  def visit_page(method, path, fields = {})
    browser.public_send(method, path, fields, HEADERS)
    redirects = 0
    while browser.last_response.redirect?
      raise "Unexpected redirect loop" if (redirects += 1) > 5

      location = URI.parse(browser.last_response.headers.fetch("location"))
      browser.get(location.request_uri, {}, HEADERS)
    end
    @response = browser.last_response
    @page = JSON.parse(@response.body)
  end

  def props
    @page.fetch("props")
  end

  def current_user
    props.dig("auth", "user")
  end

  def as_viewer(name)
    previous_browser = @browser
    @browser = browser_for(name)
    yield
  ensure
    @browser = previous_browser
  end

  def account_email(name)
    "#{name.downcase}@example.com"
  end

  def register_viewer(name)
    as_viewer(name) do
      visit_page(:post, "/sign-up", display_name: name, email: account_email(name),
        password: PASSWORD, password_confirmation: PASSWORD)
      expect(@response.status).to eq(200)
      @accounts[name] = current_user.fetch("id")
    end
  end

  def group_id(name)
    @groups.fetch(name)
  end

  def group_path(name)
    "/groups/#{group_id(name)}"
  end

  def share_invitation(owner, group_name)
    as_viewer(owner) do
      visit_page(:get, group_path(group_name))
      code = props.fetch("group").fetch("invitation_code")
      expect(code).to be_present
      @invitation_codes[group_name] = code
    end
  end

  def membership_for(viewer, group_name)
    Membership.where(user_id: @accounts.fetch(viewer), group_id: group_id(group_name))
  end

  def nested_keys(value)
    case value
    when Hash then value.keys + value.values.flat_map { |item| nested_keys(item) }
    when Array then value.flat_map { |item| nested_keys(item) }
    else []
    end
  end
end

World(WebHelpers)
