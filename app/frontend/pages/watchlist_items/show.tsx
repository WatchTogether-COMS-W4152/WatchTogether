import { Link, router, usePage } from "@inertiajs/react";
import { useState } from "react";

import EpisodeDiscussionSection from "../../components/episode-discussion";
import EpisodeProgressSection from "../../components/episode-progress";
import InlineConfirm from "../../components/inline-confirm";
import Layout, { PageHeader } from "../../components/layout";
import { Poster, TmdbAttribution } from "../../components/media-details";
import { mediaFacts, type MediaMetadata } from "../../types/catalog";

export type WatchlistItemDetails = MediaMetadata & {
  id: number;
  title: string;
  watched: boolean;
  episodic: boolean;
};

export default function WatchlistItemPage({
  group,
  item,
}: {
  group: { id: number; name: string };
  item: WatchlistItemDetails;
}) {
  const { props } = usePage();
  const [pending, setPending] = useState(false);
  const path = `/groups/${group.id}/watchlist_items/${item.id}`;
  const facts = mediaFacts(item, true);
  const requestOptions = {
    onStart: () => setPending(true),
    onFinish: () => setPending(false),
  };

  return (
    <Layout title={`${item.title} · ${group.name}`} section="groups">
      <Link className="back title-back" href={`/groups/${group.id}/watchlist_items`}>
        ← Watchlist
      </Link>
      <div className="title-header">
        <Poster title={item.title} poster_url={item.poster_url} />
        <PageHeader
          title={item.title}
          meta={
            facts.length > 0 || item.watched ? (
              <>
                {item.watched && <span className="chip">Watched</span>}
                {facts.map((fact) => (
                  <span key={fact}>{fact}</span>
                ))}
              </>
            ) : undefined
          }
        >
          {item.overview && <p className="overview">{item.overview}</p>}
        </PageHeader>
      </div>
      {item.episodic && (
        <>
          <EpisodeProgressSection {...props} />
          <EpisodeDiscussionSection {...props} />
        </>
      )}
      <section className="title-actions row" aria-label="Watchlist actions">
        <button
          className={`btn btn-sm ${item.episodic ? "btn-secondary" : "btn-primary"}`}
          type="button"
          disabled={pending}
          onClick={() => router.patch(path, {}, requestOptions)}
        >
          {item.watched ? "Mark as unwatched" : "Mark as watched"}
        </button>
        <InlineConfirm
          label="Remove"
          question={`Remove “${item.title}” from the watchlist?`}
          confirmLabel="Yes, remove"
          pendingLabel="Removing…"
          pending={pending}
          onConfirm={() => router.delete(path, requestOptions)}
        />
      </section>
      {item.tmdb_id && <TmdbAttribution />}
    </Layout>
  );
}
