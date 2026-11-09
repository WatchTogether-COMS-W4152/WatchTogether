require "simplecov"

SimpleCov.start "rails" do
  enable_coverage :branch
  cover "app/{controllers,models}/**/*.rb"
  minimum_coverage line: 90
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
  config.order = :random
  Kernel.srand config.seed
end
