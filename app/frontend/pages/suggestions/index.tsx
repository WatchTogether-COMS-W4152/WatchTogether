import { Link, useForm } from "@inertiajs/react";
import { useState } from "react";

import AddSuggestionToWatchlist from "../../components/add-suggestion-to-watchlist";
import InlineConfirm from "../../components/inline-confirm";
import Layout, { PageHeader } from "../../components/layout";
import { MediaMeta, SmallPoster } from "../../components/media-details";
import MediaKind from "../../components/media-kind";
import RatingButtons from "../../components/rating-buttons";
import TitleSearch from "../../components/title-search";
import type { CatalogTitle } from "../../types/catalog";
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
  const form = useForm({ title: "", manual_media_type: "" });
  const [selected, setSelected] = useState<CatalogTitle | null>(null);
  const removal = useForm({});

  return (
    <Layout title={`What should we watch? · ${group.name}`} section="groups">
      <PageHeader
        title="What should we watch?"
        back={{ href: `/groups/${group.id}`, label: group.name }}
        actions={
          <Link className="btn btn-secondary" href={`/groups/${group.id}/watchlist_items`}>
            Watchlist
          </Link>
        }
      />
      <div className="read-width stack-sections">
        <section className="card" aria-labelledby="suggest-title">
          <h2 id="suggest-title">Suggest a title</h2>
          <form
            className="form"
            noValidate
            onSubmit={(event) => {
              event.preventDefault();
              form.transform((data) =>
                selected
                  ? {
                      title: data.title,
                      tmdb_id: selected.tmdb_id,
                      media_type: selected.media_type,
                    }
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
            {!selected && form.data.title.trim() && (
              <MediaKind
                value={form.data.manual_media_type}
                disabled={form.processing}
                onChange={(kind) => form.setData("manual_media_type", kind)}
              />
            )}
            <div className="row">
              <button className="btn btn-primary" type="submit" disabled={form.processing}>
                {form.processing ? "Adding…" : "Add suggestion"}
              </button>
            </div>
          </form>
        </section>
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
                            removal.delete(`/groups/${group.id}/suggestions/${suggestion.id}`, {
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
