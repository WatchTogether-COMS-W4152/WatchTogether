require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders the home page" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component("home/index")
      expect(inertia).to have_props(environment: "test")
    end
  end
end
