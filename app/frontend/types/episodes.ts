export type EpisodePosition = { season: number; episode: number };

export function formatEpisode({ season, episode }: EpisodePosition) {
  return `S${season} E${episode}`;
}

export type MemberProgress = {
  id: number;
  display_name: string;
  position: EpisodePosition | null;
  caught_up: boolean;
};

export type EpisodeProgressData = {
  members: MemberProgress[];
  my_position: EpisodePosition | null;
  next_episode: EpisodePosition;
  everyone_caught_up: boolean;
};
