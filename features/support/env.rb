# Acceptance scenarios use real Rails requests and independent browser cookies.
ENV["RAILS_ENV"] = "test"

require_relative "../../config/environment"
require "rack/test"
require "rspec/expectations"
require "json"
require "uri"

World(RSpec::Matchers)

Before do
  Rails.cache.clear
  ApplicationController::RATE_LIMIT_STORE.clear
  @browsers = {}
  @accounts = {}
  @groups = {}
  @invitation_codes = {}
  @previous_invitation_codes = {}
  ActiveRecord::Base.connection.begin_transaction(joinable: false)
end

After do
  ActiveRecord::Base.connection.rollback_transaction
end
