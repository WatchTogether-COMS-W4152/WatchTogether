import { useState } from "react";

import type { MediaMetadata } from "../types/catalog";

export function MediaPoster({ title, poster_url }: MediaMetadata & { title: string }) {
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  return poster_url && failedUrl !== poster_url ? (
    <img
      className="media-poster"
      src={poster_url}
      alt={`${title} poster`}
      loading="lazy"
      onError={() => setFailedUrl(poster_url)}
    />
  ) : (
    <span className="media-poster media-poster-placeholder" aria-label="No poster available">
      <span aria-hidden="true">No poster</span>
    </span>
  );
}

export default function MediaDetails({
  media,
  compact = false,
}: {
  media: MediaMetadata;
  compact?: boolean;
}) {
  if (!media.tmdb_id) return null;
  return (
    <>
      <div className="media-metadata">
        <span>{media.media_type === "tv" ? "TV show" : "Movie"}</span>
        <span>{media.release_year || "Year unavailable"}</span>
        <span>
          {media.tmdb_rating != null ? `TMDB ${media.tmdb_rating.toFixed(1)}/10` : "Not yet rated"}
        </span>
        {!compact && (
          <span className="media-certification">
            {media.age_rating ? `${media.age_rating} (US)` : "US age rating unavailable"}
          </span>
        )}
      </div>
      <p className={`media-overview${compact ? " media-overview-compact" : ""}`}>
        {media.overview || "No description available."}
      </p>
    </>
  );
}

export function TmdbAttribution() {
  return (
    <footer className="tmdb-attribution">
      <a href="https://www.themoviedb.org/" target="_blank" rel="noreferrer">
        <img className="tmdb-logo" src="/tmdb-logo.svg" alt="TMDB" /> Movie and TV data
      </a>
      <p>This product uses the TMDB API but is not endorsed or certified by TMDB.</p>
    </footer>
  );
}
