class StreamingService
  CATALOG = [
    { id: 8, name: "Netflix" },
    { id: 9, name: "Amazon Prime Video" },
    { id: 337, name: "Disney Plus" },
    { id: 15, name: "Hulu" },
    { id: 1899, name: "Max" },
    { id: 350, name: "Apple TV Plus" },
    { id: 386, name: "Peacock" },
    { id: 531, name: "Paramount Plus" },
    { id: 283, name: "Crunchyroll" }
  ].freeze

  IDS = CATALOG.map { |service| service.fetch(:id) }.freeze

  def self.allowed?(provider_id)
    IDS.include?(provider_id)
  end

  def self.id_for(name)
    CATALOG.find { |service| service.fetch(:name) == name }&.fetch(:id)
  end
end
