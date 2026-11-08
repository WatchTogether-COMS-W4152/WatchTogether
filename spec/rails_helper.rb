require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("Do not run tests in production!") if Rails.env.production?
require "rspec/rails"
require "inertia_rails/rspec"

Rails.root.glob("spec/support/**/*.rb").sort.each { |file| require file }
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include TestHelpers
  config.include ActiveSupport::Testing::TimeHelpers
  config.before { ApplicationController::RATE_LIMIT_STORE.clear }
  config.filter_rails_from_backtrace!
end
