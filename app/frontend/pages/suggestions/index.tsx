import "../../styles/voting.css";
import { Link, useForm } from "@inertiajs/react";
import { useEffect, useRef, useState } from "react";

import AddSuggestionToWatchlist from "../../components/add-suggestion-to-watchlist";
import Layout, { PageHeader } from "../../components/layout";
import MediaDetails, { MediaPoster, TmdbAttribution } from "../../components/media-details";
import RatingButtons from "../../components/rating-buttons";
import TitleSearch from "../../components/title-search";
import type { CatalogTitle } from "../../types/catalog";
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
  const [selected, setSelected] = useState<CatalogTitle | null>(null);
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
      <PageHeader
        title="What should we watch?"
        actions={
          <Link className="button button-secondary" href={`/groups/${group.id}/watchlist_items`}>
            Our Watchlist →
          </Link>
        }
      />
      <section aria-labelledby="suggest-title">
        <h2 id="suggest-title" className="visually-hidden">
          Suggest a title
        </h2>
        <form
          className="catalog-add-form"
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            form.transform((data) =>
              selected
                ? { ...data, tmdb_id: selected.tmdb_id, media_type: selected.media_type }
                : data,
            );
            form.post(`/groups/${group.id}/suggestions`, {
              preserveScroll: true,
              onSuccess: () => {
                form.reset();
                setSelected(null);
              },
            });
          }}
        >
          <TitleSearch
            groupId={group.id}
            value={form.data.title}
            selected={selected}
            disabled={form.processing}
            onChange={(title) => {
              form.setData("title", title);
              setSelected(null);
            }}
            onSelect={(title) => {
              form.setData("title", title.title);
              setSelected(title);
            }}
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
                  {suggestion.tmdb_id && <MediaPoster {...suggestion} />}
                  <div className="suggestion-identity">
                    <h3>{suggestion.title}</h3>
                    <MediaDetails media={suggestion} />
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
                  <div className="suggestion-secondary-actions">
                    <AddSuggestionToWatchlist groupId={group.id} suggestion={suggestion} />
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
      <TmdbAttribution />
    </Layout>
  );
}
