import { router, useForm, usePage } from "@inertiajs/react";

import { formatEpisode, type EpisodeProgressData } from "../types/episodes";
import Avatar from "./avatar";
import Field from "./field";

type ProgressPageProps = {
  group: { id: number };
  item: { id: number };
  episode_progress?: EpisodeProgressData;
};

export default function EpisodeProgressSection(_props: Record<string, unknown>) {
  const { props } = usePage<ProgressPageProps>();
  if (!props.episode_progress) return null;
  return (
    <EpisodeProgressPanel
      path={`/groups/${props.group.id}/watchlist_items/${props.item.id}/progress`}
      progress={props.episode_progress}
      currentUserId={props.auth.user?.id}
    />
  );
}

export function EpisodeProgressPanel({
  path,
  progress,
  currentUserId,
}: {
  path: string;
  progress: EpisodeProgressData;
  currentUserId?: number;
}) {
  const mine = progress.my_position;
  const form = useForm({
    season: mine ? String(mine.season) : "1",
    episode: mine ? String(mine.episode) : "",
  });
  const started = progress.members.some((member) => member.position);
  const advanceTo = progress.my_next_episode;

  function save(data: { season: string; episode: string }) {
    form.transform(() => data);
    form.put(path, { preserveScroll: true });
  }

  return (
    <section className="panel episode-progress" aria-labelledby="episode-progress-title">
      <h2 id="episode-progress-title">Episode progress</h2>
      <p className="progress-next">
        {!started
          ? "Nobody has started yet. Start together with S1 E1."
          : !progress.next_episode
            ? "Everyone has finished the show."
            : progress.everyone_caught_up
              ? `Everyone is caught up. Next up together: ${formatEpisode(progress.next_episode)}.`
              : `Next episode for everyone: ${formatEpisode(progress.next_episode)}`}
      </p>

      <ul className="member-list" aria-label="Where everyone is">
        {progress.members.map((member) => (
          <li key={member.id} className="member-row">
            <Avatar name={member.display_name} />
            <div className="member-identity">
              <span className="member-name">
                {member.display_name}
                {member.id === currentUserId && <span className="muted"> (you)</span>}
              </span>
              {member.caught_up && <span className="badge">Caught up</span>}
            </div>
            <span className={member.position ? "progress-position" : "progress-position muted"}>
              {member.position ? formatEpisode(member.position) : "Not started"}
            </span>
          </li>
        ))}
      </ul>

      <form
        className="progress-form"
        noValidate
        onSubmit={(event) => {
          event.preventDefault();
          save(form.data);
        }}
      >
        <h3>Your progress</h3>
        <p className="muted">
          {mine ? `You've watched up to ${formatEpisode(mine)}.` : "You haven't started yet."}
        </p>
        <div className="progress-fields">
          <Field
            label="Season"
            name="season"
            type="number"
            inputMode="numeric"
            min={1}
            required
            value={form.data.season}
            onChange={(event) => form.setData("season", event.target.value)}
            error={form.errors.season}
          />
          <Field
            label="Episode"
            name="episode"
            type="number"
            inputMode="numeric"
            min={1}
            required
            value={form.data.episode}
            onChange={(event) => form.setData("episode", event.target.value)}
            error={form.errors.episode}
          />
        </div>
        <div className="form-actions progress-actions">
          <button className="button button-primary" type="submit" disabled={form.processing}>
            Save progress
          </button>
          {advanceTo && (
            <button
              className="button button-secondary"
              type="button"
              disabled={form.processing}
              onClick={() => {
                form.setData({
                  season: String(advanceTo.season),
                  episode: String(advanceTo.episode),
                });
                form.transform(() => ({ next: "1" }));
                form.put(path, { preserveScroll: true });
              }}
            >
              Watched next episode ({formatEpisode(advanceTo)})
            </button>
          )}
          {mine && (
            <button
              className="text-button danger-text"
              type="button"
              disabled={form.processing}
              onClick={() => {
                form.setData({ season: "1", episode: "" });
                router.delete(path, { preserveScroll: true });
              }}
            >
              Clear my progress
            </button>
          )}
        </div>
      </form>
    </section>
  );
}
