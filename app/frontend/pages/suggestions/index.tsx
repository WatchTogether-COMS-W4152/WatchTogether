import { useForm } from "@inertiajs/react";
import { useState } from "react";

import AddSuggestionToWatchlist from "../../components/add-suggestion-to-watchlist";
import AddTitleForm from "../../components/add-title-form";
import GroupHeader from "../../components/group-header";
import InlineConfirm from "../../components/inline-confirm";
import Layout from "../../components/layout";
import { MediaMeta, SmallPoster } from "../../components/media-details";
import RatingButtons from "../../components/rating-buttons";
import type { Suggestion, VotingGroup } from "../../types/voting";

function formatScore(score: number) {
  return score > 0 ? `+${score}` : score < 0 ? `−${-score}` : "0";
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
  const [adding, setAdding] = useState(suggestions.length === 0);
  const removal = useForm({});

  return (
    <Layout title={`Picks · ${group.name}`} section="groups">
      <GroupHeader
        group={group}
        current="picks"
        actions={
          !adding && (
            <button
              className="btn btn-primary btn-sm"
              type="button"
              onClick={() => setAdding(true)}
            >
              Suggest a title
            </button>
          )
        }
      />
      <div className="read-width stack-sections">
        {adding && (
          <AddTitleForm
            groupId={group.id}
            action={`/groups/${group.id}/picks`}
            submitLabel="Add suggestion"
            onClose={suggestions.length > 0 ? () => setAdding(false) : undefined}
          />
        )}
        <div className="ranking">
          <section className="card" aria-labelledby="ranking-title">
            <h2 id="ranking-title">Ranking</h2>
            {suggestions.length === 0 ? (
              <p className="muted">No suggestions yet.</p>
            ) : (
              <ol className="rows">
                {suggestions.map((suggestion, index) => (
                  <li key={suggestion.id} className="rank-row">
                    <span className="rank" aria-hidden="true">
                      {index + 1}
                    </span>
                    <SmallPoster poster_url={suggestion.poster_url} />
                    <div className="rank-title">
                      <h3>{suggestion.title}</h3>
                      <MediaMeta media={suggestion} />
                      <p className="meta">
                        {suggestion.suggested_by
                          ? `Suggested by ${suggestion.suggested_by} · `
                          : ""}
                        {suggestion.votes_count} of {memberCount} rated
                      </p>
                    </div>
                    <span
                      className={`score${suggestion.score < 0 ? " is-negative" : suggestion.score === 0 ? " is-zero" : ""}`}
                    >
                      <span className="visually-hidden">Score </span>
                      {formatScore(suggestion.score)}
                    </span>
                    <div className="actions">
                      <RatingButtons groupId={group.id} suggestion={suggestion} />
                      <AddSuggestionToWatchlist groupId={group.id} suggestion={suggestion} />
                      {suggestion.can_remove && (
                        <InlineConfirm
                          label="Remove"
                          accessibleLabel={`Remove ${suggestion.title}`}
                          question={`Remove “${suggestion.title}”? Its ratings will be deleted.`}
                          confirmLabel="Yes, remove"
                          pendingLabel="Removing…"
                          pending={removal.processing}
                          onConfirm={() =>
                            removal.delete(`/groups/${group.id}/picks/${suggestion.id}`, {
                              preserveScroll: true,
                            })
                          }
                        />
                      )}
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </section>
        </div>
      </div>
    </Layout>
  );
}
