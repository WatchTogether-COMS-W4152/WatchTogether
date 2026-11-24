module CatalogSelection
  private

  def selected_title_attributes
    selection = params.permit(:title, :tmdb_id, :media_type)
    if selection[:tmdb_id].blank? && selection[:media_type].blank?
      kind = params[:manual_media_type].presence
      if selection[:title].to_s.squish.present? && !TmdbClient::MEDIA_TYPES.include?(kind)
        raise TmdbClient::InvalidSelection, "Choose whether it's a movie or a TV show."
      end

      return { title: selection[:title].to_s, manual_media_type: kind }
    end

    TmdbClient.new.details(selection[:media_type], selection[:tmdb_id])
  end
end
