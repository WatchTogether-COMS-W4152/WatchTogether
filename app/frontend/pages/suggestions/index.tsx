import "../../styles/voting.css";
import { Link, useForm } from "@inertiajs/react";
import { useEffect, useRef, useState } from "react";

import Field from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";
import RatingButtons from "../../components/rating-buttons";
import type { Suggestion, VotingGroup } from "../../types/voting";

function formatScore(score: number) {
  return score > 0 ? `+${score}` : String(score);
}

export default function Suggestions({
  group,
  member_count: memberCount,
  suggestions,
}: {
  group: VotingGroup;
  member_count: number;
  suggestions: Suggestion[];
}) {
  const form = useForm({ title: "" });
  const removal = useForm({});
  const [confirmingId, setConfirmingId] = useState<number | null>(null);
  const cancelRemoval = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    if (confirmingId !== null) cancelRemoval.current?.focus();
  }, [confirmingId]);

  return (
    <Layout title={`What should we watch? · ${group.name}`}>
      <Link className="back-link" href={`/groups/${group.id}`}>
        ← {group.name}
      </Link>
      <PageHeader title="What should we watch?" />
      <section aria-labelledby="suggest-title">
        <h2 id="suggest-title" className="visually-hidden">
          Suggest a title
        </h2>
        <form
          className="suggest-form"
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            form.post(`/groups/${group.id}/suggestions`, {
              preserveScroll: true,
              onSuccess: () => form.reset(),
            });
          }}
        >
          <Field
            label="Title"
            name="title"
            autoComplete="off"
            required
            maxLength={120}
            placeholder="Add a movie or show"
            value={form.data.title}
            onChange={(event) => form.setData("title", event.target.value)}
            error={form.errors.title}
          />
          <button className="button button-primary" type="submit" disabled={form.processing}>
            {form.processing ? "Adding…" : "Add suggestion"}
          </button>
        </form>
        <p className="scoring-note">
          Love it adds 2, Maybe adds 1, and Not interested subtracts 2. Ratings are private;
          everyone sees only the totals.
        </p>
      </section>
      <section aria-labelledby="ranking-title">
        <div className="section-label">
          <h2 id="ranking-title">Ranking</h2>
          <span>
            {suggestions.length} {suggestions.length === 1 ? "title" : "titles"}
          </span>
        </div>
        {suggestions.length === 0 ? (
          <p className="muted empty-ranking">No suggestions yet. Add something above.</p>
        ) : (
          <ol className="list suggestion-list">
            {suggestions.map((suggestion, index) => (
              <li key={suggestion.id} className="suggestion-item">
                <div className="suggestion-row">
                  <span className="suggestion-rank" aria-hidden="true">
                    {index + 1}
                  </span>
                  <div className="suggestion-identity">
                    <h3>{suggestion.title}</h3>
                    <p className="muted">
                      {suggestion.suggested_by ? `Suggested by ${suggestion.suggested_by} · ` : ""}
                      {suggestion.votes_count} of {memberCount} rated
                    </p>
                  </div>
                  <span
                    className={`suggestion-score${suggestion.score < 0 ? " is-negative" : suggestion.score === 0 ? " is-zero" : ""}`}
                  >
                    <span className="visually-hidden">Score </span>
                    {formatScore(suggestion.score)}
                  </span>
                </div>
                <div className="suggestion-actions">
                  <RatingButtons groupId={group.id} suggestion={suggestion} />
                  {suggestion.can_remove && confirmingId !== suggestion.id && (
                    <button
                      type="button"
                      className="text-button danger-text suggestion-remove"
                      aria-label={`Remove ${suggestion.title}`}
                      disabled={removal.processing}
                      onClick={() => setConfirmingId(suggestion.id)}
                    >
                      Remove
                    </button>
                  )}
                </div>
                {suggestion.can_remove &&
                  (confirmingId === suggestion.id ? (
                    <div className="confirmation suggestion-removal">
                      <p>Remove “{suggestion.title}”? Everyone's ratings for it will be deleted.</p>
                      <div className="invite-actions">
                        <button
                          type="button"
                          className="button button-danger"
                          disabled={removal.processing}
                          onClick={() =>
                            removal.delete(`/groups/${group.id}/suggestions/${suggestion.id}`, {
                              preserveScroll: true,
                              onSuccess: () => setConfirmingId(null),
                            })
                          }
                        >
                          {removal.processing ? "Removing…" : "Yes, remove"}
                        </button>
                        <button
                          type="button"
                          className="text-button"
                          ref={cancelRemoval}
                          disabled={removal.processing}
                          onClick={() => setConfirmingId(null)}
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : null)}
              </li>
            ))}
          </ol>
        )}
      </section>
    </Layout>
  );
}
