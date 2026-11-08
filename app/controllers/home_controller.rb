class HomeController < InertiaController
  def index
    render inertia: { environment: Rails.env }
  end
end
