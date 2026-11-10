SimpleCov.configure do
  enable_coverage :branch
  cover "app/{controllers,models}/**/*.rb"
end
