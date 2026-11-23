import "../styles/discussion.css";
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
import Field from "./field";

type DiscussionPageProps = {
  group: { id: number };
  item: { id: number };
  discussion?: Discussion;
};

function hiddenLabel({ season, episode, hidden_count: count }: DiscussionEpisode) {
  const comments = count === 1 ? "1 comment" : `${count} comments`;
  return `${comments} on ${formatEpisode({ season, episode })}, unlocked when you get there.`;
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
      <div className="section-label">
        <h2 id="discussion-title">Discussion</h2>
        <span>
          {total} {total === 1 ? "comment" : "comments"}
        </span>
      </div>
      <p className="muted">
        Comments are tied to episodes. You only see comments on episodes you've watched.
      </p>
      {position ? (
        <CommentForm
          key={`${position.season}-${position.episode}`}
          path={basePath}
          position={position}
          maxLength={discussion.max_body_length}
        />
      ) : (
        <p className="panel muted">Mark the episodes you've watched to join the conversation.</p>
      )}
      {discussion.episodes.length === 0 ? (
        <p className="muted">No comments yet.</p>
      ) : (
        <ol className="discussion-episodes">
          {discussion.episodes.map((entry) => (
            <li key={`${entry.season}-${entry.episode}`} className="discussion-episode">
              <h3>{formatEpisode(entry)}</h3>
              {entry.comments.length > 0 && (
                <ul className="list comment-list">
                  {entry.comments.map((comment) => (
                    <Comment
                      key={comment.id}
                      comment={comment}
                      path={`${basePath}/${comment.id}`}
                    />
                  ))}
                </ul>
              )}
              {entry.hidden_count > 0 && <p className="discussion-locked">{hiddenLabel(entry)}</p>}
            </li>
          ))}
        </ol>
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

  return (
    <form
      className="panel discussion-form"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        form.post(path, { preserveScroll: true, onSuccess: () => form.reset("body") });
      }}
    >
      <div className="discussion-position">
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
        <label htmlFor="comment-body">Comment</label>
        <textarea
          id="comment-body"
          name="comment-body"
          maxLength={maxLength}
          placeholder={`What did you think of ${formatEpisode(position)}?`}
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
      <div className="form-actions">
        <span className="field-hint">
          You can comment on any episode up to {formatEpisode(position)}.
        </span>
        <button className="button button-primary" type="submit" disabled={form.processing}>
          {form.processing ? "Posting…" : "Post comment"}
        </button>
      </div>
    </form>
  );
}

function Comment({ comment, path }: { comment: EpisodeComment; path: string }) {
  const [confirming, setConfirming] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const name = comment.author?.display_name ?? "Former member";

  return (
    <li className="comment">
      <Avatar name={name} size="small" />
      <div className="comment-main">
        <div className="comment-meta">
          <strong>{comment.mine ? `${name} (you)` : name}</strong>
          <time dateTime={comment.created_at} title={new Date(comment.created_at).toLocaleString()}>
            {formatCommentTime(comment.created_at)}
          </time>
        </div>
        <p className="comment-body">{comment.body}</p>
        {comment.can_delete && (
          <div className="comment-actions">
            {confirming ? (
              <>
                <span>Delete this comment?</span>
                <button
                  type="button"
                  className="text-button danger-text"
                  disabled={deleting}
                  onClick={() =>
                    router.delete(path, {
                      preserveScroll: true,
                      onStart: () => setDeleting(true),
                      onFinish: () => setDeleting(false),
                    })
                  }
                >
                  {deleting ? "Deleting…" : "Yes, delete"}
                </button>
                <button
                  type="button"
                  className="text-button"
                  disabled={deleting}
                  onClick={() => setConfirming(false)}
                >
                  Cancel
                </button>
              </>
            ) : (
              <button
                type="button"
                className="text-button danger-text"
                aria-label={`Delete comment by ${name}`}
                onClick={() => setConfirming(true)}
              >
                Delete
              </button>
            )}
          </div>
        )}
      </div>
    </li>
  );
}
