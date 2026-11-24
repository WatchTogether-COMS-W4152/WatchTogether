import { router, useForm, usePage } from "@inertiajs/react";
import { useState } from "react";

import {
  formatCommentTime,
  formatEpisode,
  type Discussion,
  type DiscussionEpisode,
  type EpisodeComment,
  type EpisodePosition,
} from "../types/episodes";
import Avatar from "./avatar";
import EpisodeCode from "./episode-code";
import Field from "./field";
import InlineConfirm from "./inline-confirm";

type DiscussionPageProps = {
  group: { id: number };
  item: { id: number };
  discussion?: Discussion;
};

function hiddenLabel({ hidden_count: count }: DiscussionEpisode) {
  return `${count === 1 ? "1 comment" : `${count} comments`} hidden until you watch it`;
}

export default function EpisodeDiscussionSection(_props: Record<string, unknown>) {
  const { group, item, discussion } = usePage<DiscussionPageProps>().props;
  if (!discussion) return null;

  const basePath = `/groups/${group.id}/watchlist_items/${item.id}/comments`;
  const position = discussion.viewer_position;
  const total = discussion.episodes.reduce(
    (sum, entry) => sum + entry.comments.length + entry.hidden_count,
    0,
  );

  return (
    <section className="discussion" aria-labelledby="discussion-title">
      <div className="section-title">
        <h2 id="discussion-title">Discussion</h2>
        <span className="meta">
          {total} {total === 1 ? "comment" : "comments"}
        </span>
      </div>
      {discussion.episodes.length === 0 ? (
        <p className="muted">No comments yet.</p>
      ) : (
        <ol className="thread">
          {discussion.episodes.map((entry) => (
            <li key={`${entry.season}-${entry.episode}`} className="thread-ep">
              <header>
                <h3>
                  <EpisodeCode position={entry} />
                </h3>
              </header>
              {entry.comments.length > 0 && (
                <ul className="comments">
                  {entry.comments.map((comment) => (
                    <Comment
                      key={comment.id}
                      comment={comment}
                      path={`${basePath}/${comment.id}`}
                    />
                  ))}
                </ul>
              )}
              {entry.hidden_count > 0 && (
                <div className="shutter">
                  <span className="shutter-label">{hiddenLabel(entry)}</span>
                </div>
              )}
            </li>
          ))}
        </ol>
      )}
      {position ? (
        <CommentForm
          key={`${position.season}-${position.episode}`}
          path={basePath}
          position={position}
          maxLength={discussion.max_body_length}
        />
      ) : (
        <p className="muted">Mark an episode as watched to comment.</p>
      )}
    </section>
  );
}

function CommentForm({
  path,
  position,
  maxLength,
}: {
  path: string;
  position: EpisodePosition;
  maxLength: number;
}) {
  const form = useForm({
    season: String(position.season),
    episode: String(position.episode),
    body: "",
  });
  const season = Number(form.data.season);
  const episode = Number(form.data.episode);
  const target = season >= 1 && episode >= 1 ? formatEpisode({ season, episode }) : null;

  return (
    <form
      className="card comment-form"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        form.post(path, { preserveScroll: true, onSuccess: () => form.reset("body") });
      }}
    >
      <div className="field-pair">
        <Field
          label="Season"
          name="comment-season"
          type="number"
          min={1}
          max={position.season}
          inputMode="numeric"
          value={form.data.season}
          onChange={(event) => form.setData("season", event.target.value)}
          error={form.errors.season}
        />
        <Field
          label="Episode"
          name="comment-episode"
          type="number"
          min={1}
          inputMode="numeric"
          value={form.data.episode}
          onChange={(event) => form.setData("episode", event.target.value)}
          error={form.errors.episode}
        />
      </div>
      <div className="field">
        <label htmlFor="comment-body">{target ? `Comment on ${target}` : "Comment"}</label>
        <textarea
          id="comment-body"
          name="comment-body"
          maxLength={maxLength}
          value={form.data.body}
          aria-invalid={Boolean(form.errors.body?.length)}
          aria-describedby={form.errors.body?.length ? "comment-body-error" : undefined}
          onChange={(event) => form.setData("body", event.target.value)}
        />
        {form.errors.body?.length ? (
          <p className="field-error" id="comment-body-error" role="alert">
            {form.errors.body.join(". ")}
          </p>
        ) : null}
      </div>
      <div className="row">
        <button className="btn btn-secondary" type="submit" disabled={form.processing}>
          {form.processing ? "Posting…" : "Post comment"}
        </button>
      </div>
    </form>
  );
}

function Comment({ comment, path }: { comment: EpisodeComment; path: string }) {
  const [deleting, setDeleting] = useState(false);
  const name = comment.author?.display_name ?? "Former member";

  return (
    <li className={comment.mine ? "comment is-mine" : "comment"}>
      <Avatar name={name} size="sm" />
      <div className="bubble">
        <div className="bubble-meta">
          <strong>{comment.mine ? `${name} (you)` : name}</strong>
          <time dateTime={comment.created_at} title={new Date(comment.created_at).toLocaleString()}>
            {formatCommentTime(comment.created_at)}
          </time>
        </div>
        <p>{comment.body}</p>
        {comment.can_delete && (
          <div className="bubble-actions">
            <InlineConfirm
              flush
              label="Delete"
              accessibleLabel={`Delete comment by ${name}`}
              question="Delete this comment?"
              confirmLabel="Yes, delete"
              pendingLabel="Deleting…"
              pending={deleting}
              onConfirm={() =>
                router.delete(path, {
                  preserveScroll: true,
                  onStart: () => setDeleting(true),
                  onFinish: () => setDeleting(false),
                })
              }
            />
          </div>
        )}
      </div>
    </li>
  );
}
