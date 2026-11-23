import { useState, type ReactNode } from "react";

import { mediaFacts, type MediaMetadata } from "../types/catalog";

function usePosterImage(url?: string | null) {
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  return { src: url && failedUrl !== url ? url : null, onError: () => setFailedUrl(url ?? null) };
}

export function Poster({
  title,
  poster_url,
  children,
}: {
  title: string;
  poster_url?: string | null;
  children?: ReactNode;
}) {
  const { src, onError } = usePosterImage(poster_url);
  return (
    <span className="poster">
      {src ? (
        <img src={src} alt="" loading="lazy" onError={onError} />
      ) : (
        <span className="poster-blank" aria-hidden="true">
          {title}
        </span>
      )}
      {children}
    </span>
  );
}

export function SmallPoster({ poster_url }: { poster_url?: string | null }) {
  const { src, onError } = usePosterImage(poster_url);
  return src ? (
    <img className="poster-sm" src={src} alt="" loading="lazy" onError={onError} />
  ) : (
    <span className="poster-sm" aria-hidden="true" />
  );
}

export function MediaMeta({
  media,
  withAgeRating = false,
}: {
  media: MediaMetadata;
  withAgeRating?: boolean;
}) {
  const facts = mediaFacts(media, withAgeRating);
  if (!facts.length) return null;
  return (
    <span className="poster-meta">
      {facts.map((fact) => (
        <span key={fact}>{fact}</span>
      ))}
    </span>
  );
}

export function TmdbAttribution() {
  return (
    <footer className="tmdb">
      <a href="https://www.themoviedb.org/" target="_blank" rel="noreferrer">
        <img src="/tmdb-logo.svg" alt="TMDB" width={72} />
      </a>
      <p className="meta">
        This product uses the TMDB API but is not endorsed or certified by TMDB.
      </p>
    </footer>
  );
}
