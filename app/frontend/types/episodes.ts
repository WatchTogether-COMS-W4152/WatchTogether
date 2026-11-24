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
  my_next_episode: EpisodePosition | null;
  next_episode: EpisodePosition | null;
  finished: boolean;
  everyone_caught_up: boolean;
  season_lengths: number[] | null;
};

export type EpisodeComment = {
  id: number;
  body: string;
  author: { id: number; display_name: string } | null;
  created_at: string;
  mine: boolean;
  can_delete: boolean;
};

export type DiscussionEpisode = EpisodePosition & {
  comments: EpisodeComment[];
  hidden_count: number;
};

export type Discussion = {
  viewer_position: EpisodePosition | null;
  max_body_length: number;
  episodes: DiscussionEpisode[];
};

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

export function formatCommentTime(iso: string, now: Date = new Date()) {
  const time = new Date(iso);
  const elapsed = now.getTime() - time.getTime();
  if (elapsed < MINUTE) return "just now";
  if (elapsed < HOUR) return `${Math.floor(elapsed / MINUTE)}m ago`;
  if (elapsed < DAY) return `${Math.floor(elapsed / HOUR)}h ago`;
  if (elapsed < 7 * DAY) return `${Math.floor(elapsed / DAY)}d ago`;
  return time.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    ...(time.getFullYear() === now.getFullYear() ? {} : { year: "numeric" }),
  });
}
