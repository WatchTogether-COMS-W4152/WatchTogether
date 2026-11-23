export type EpisodePosition = { season: number; episode: number };

export function formatEpisode({ season, episode }: EpisodePosition) {
  return `S${season} E${episode}`;
}
