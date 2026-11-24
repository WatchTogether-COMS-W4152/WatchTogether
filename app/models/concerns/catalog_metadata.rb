module CatalogMetadata
  extend ActiveSupport::Concern

  FIELDS = %w[tmdb_id media_type overview release_year tmdb_rating age_rating poster_path manual_media_type].freeze

  included do
    validates :manual_media_type, inclusion: { in: TmdbClient::MEDIA_TYPES }, allow_nil: true
    validates :media_type, inclusion: { in: TmdbClient::MEDIA_TYPES }, if: -> { tmdb_id.present? || media_type.present? }
    validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }, if: -> { tmdb_id.present? || media_type.present? }
  end

  def catalog_attributes
    attributes.slice("title", *FIELDS)
  end

  def catalog_json
    return {} unless tmdb_id

    attributes.slice(*FIELDS.excluding("poster_path")).merge("poster_url" => TmdbClient.poster_url(poster_path))
  end
end
