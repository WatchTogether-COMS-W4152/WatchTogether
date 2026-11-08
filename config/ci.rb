# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Style: Frontend format", "npm run fmt:check"
  step "Style: Frontend lint", "npm run lint"
  step "Types: Frontend", "npm run typecheck"
  step "Tests: Frontend", "npm test"
  step "Tests: RSpec", "bin/rspec"
  step "Stories: Cucumber", "bundle exec cucumber"
  step "Build: Production assets", "RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile"


  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
