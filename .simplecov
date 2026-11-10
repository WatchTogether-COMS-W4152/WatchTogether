SimpleCov.start "rails" do
  enable_coverage :branch
  cover "app/{controllers,models}/**/*.rb"
end
