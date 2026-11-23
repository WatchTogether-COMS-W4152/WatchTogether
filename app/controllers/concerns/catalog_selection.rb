module CatalogSelection
  private

  def selected_title_attributes
    selection = params.permit(:title, :tmdb_id, :media_type)
    return { title: selection[:title].to_s } if selection[:tmdb_id].blank? && selection[:media_type].blank?

    TmdbClient.new.details(selection[:media_type], selection[:tmdb_id])
  end
end
