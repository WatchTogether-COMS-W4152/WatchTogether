import { router, useForm, usePage } from "@inertiajs/react";
import { useState } from "react";

import {
  formatEpisode,
  type EpisodePosition,
  type EpisodeProgressData,
  type MemberProgress,
} from "../types/episodes";
import Avatar from "./avatar";
import EpisodeCode from "./episode-code";
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
  const next = progress.next_episode;
  const form = useForm({
    season: mine ? String(mine.season) : "1",
    episode: mine ? String(mine.episode) : "",
  });
  const [exactOpen, setExactOpen] = useState(false);
  const [savingExact, setSavingExact] = useState(false);
  const started = progress.members.some((member) => member.position);
  const advanceTo = progress.my_next_episode;
  const showExact = exactOpen || Object.keys(form.errors).length > 0;

  return (
    <section className="card" aria-labelledby="episode-progress-title">
      <h2 id="episode-progress-title">
        {!started ? (
          <>
            Start with <EpisodeCode position={next ?? { season: 1, episode: 1 }} next />
          </>
        ) : !next ? (
          "Everyone has finished the show"
        ) : (
          <>
            Next episode for everyone: <EpisodeCode position={next} next />
          </>
        )}
      </h2>

      {next && (
        <SeasonStrip
          members={progress.members}
          next={next}
          length={progress.season_lengths?.[next.season - 1]}
        />
      )}

      <ul className="rows" aria-label="Where everyone is">
        {progress.members.map((member) => (
          <li key={member.id} className="person-row">
            <Avatar name={member.display_name} />
            <span className="who">
              {member.display_name}
              {member.id === currentUserId && <span className="muted"> (you)</span>}
              {member.caught_up && <span className="chip">Caught up</span>}
            </span>
            {member.position ? (
              <EpisodeCode position={member.position} />
            ) : (
              <span className="chip chip-quiet">Not started</span>
            )}
          </li>
        ))}
      </ul>

      <div className="row">
        {advanceTo && (
          <button
            className="btn btn-primary"
            type="button"
            disabled={form.processing}
            onClick={() => {
              form.setData({
                season: String(advanceTo.season),
                episode: String(advanceTo.episode),
              });
              form.transform(() => ({ next: "1" }));
              setSavingExact(false);
              form.put(path, { preserveScroll: true });
            }}
          >
            Watched next episode ({formatEpisode(advanceTo)})
          </button>
        )}
        <button
          className="btn btn-quiet"
          type="button"
          aria-expanded={showExact}
          aria-controls="exact-progress"
          onClick={() => setExactOpen(!showExact)}
        >
          Set exact episode
        </button>
      </div>

      {showExact && (
        <form
          id="exact-progress"
          className="form"
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            form.transform((data) => data);
            setSavingExact(true);
            form.put(path, { preserveScroll: true, onSuccess: () => setExactOpen(false) });
          }}
        >
          <div className="field-pair">
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
          <div className="row">
            <button className="btn btn-secondary btn-sm" type="submit" disabled={form.processing}>
              {form.processing && savingExact ? "Saving…" : "Save progress"}
            </button>
            {mine && (
              <button
                className="btn btn-quiet btn-sm is-danger"
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
      )}
    </section>
  );
}

function SeasonStrip({
  members,
  next,
  length,
}: {
  members: MemberProgress[];
  next: EpisodePosition;
  length?: number;
}) {
  const furthest = Math.max(
    0,
    ...members.flatMap((member) =>
      member.position?.season === next.season ? [member.position.episode] : [],
    ),
  );
  const episodes = Array.from(
    { length: length ?? Math.max(furthest + 1, next.episode) },
    (_, index) => index + 1,
  );
  return (
    <>
      <ol className="strip" aria-label={`Season ${next.season}`}>
        {episodes.map((episode) =>
          episode < next.episode ? (
            <li
              key={episode}
              className="cell cell-watched"
              aria-label={`E${episode}, everyone has watched`}
            >
              {episode}
            </li>
          ) : episode === next.episode ? (
            <li
              key={episode}
              className="cell cell-next"
              aria-label={`E${episode}, next episode for everyone`}
            >
              {episode}
            </li>
          ) : (
            <li key={episode} className="cell cell-ahead" aria-label={`E${episode}`}>
              {episode}
            </li>
          ),
        )}
      </ol>
    </>
  );
}
