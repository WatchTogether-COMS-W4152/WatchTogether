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
