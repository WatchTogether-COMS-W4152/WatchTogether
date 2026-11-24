export type MediaMetadata = {
  tmdb_id?: number | null;
  media_type?: "movie" | "tv" | null;
  overview?: string | null;
  release_year?: number | null;
  tmdb_rating?: number | null;
  age_rating?: string | null;
  poster_url?: string | null;
};

export type CatalogTitle = MediaMetadata & {
  tmdb_id: number;
  media_type: "movie" | "tv";
  title: string;
};

export function mediaFacts(media: MediaMetadata, withAgeRating = false) {
  if (!media.tmdb_id) return [];
  const facts = [
    media.media_type === "tv" ? "TV show" : "Movie",
    media.release_year ? String(media.release_year) : "Year unavailable",
    media.tmdb_rating != null ? `TMDB ${media.tmdb_rating.toFixed(1)}` : "Not yet rated",
  ];
  if (withAgeRating)
    facts.push(media.age_rating ? `${media.age_rating} (US)` : "US age rating unavailable");
  return facts;
}
