import { formatEpisode, type EpisodePosition } from "../types/episodes";

export default function EpisodeCode({
  position,
  next = false,
}: {
  position: EpisodePosition;
  next?: boolean;
}) {
  return (
    <span className={next ? "ep ep-next" : "ep"}>
      <span aria-hidden="true">{formatEpisode(position)}</span>
      <span className="visually-hidden">
        Season {position.season}, Episode {position.episode}
      </span>
    </span>
  );
}
