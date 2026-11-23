SimpleCov.configure do
  enable_coverage :branch
  cover "app/{controllers,models,services}/**/*.rb"
  group "Services", "app/services"
end
