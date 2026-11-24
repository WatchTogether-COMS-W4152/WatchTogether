import { router, usePage } from "@inertiajs/react";
import { useState } from "react";

import EpisodeDiscussionSection from "../../components/episode-discussion";
import EpisodeProgressSection from "../../components/episode-progress";
import GroupHeader from "../../components/group-header";
import InlineConfirm from "../../components/inline-confirm";
import Layout, { PageHeader } from "../../components/layout";
import { Poster } from "../../components/media-details";
import WatchProvidersSection, { type WatchProviders } from "../../components/watch-providers";
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
  watch_providers,
}: {
  group: { id: number; name: string };
  item: WatchlistItemDetails;
  watch_providers?: WatchProviders;
}) {
  const { props } = usePage();
  const [pending, setPending] = useState(false);
  const path = `/groups/${group.id}/watchlist/${item.id}`;
  const facts = mediaFacts(item, true);
  const requestOptions = {
    onStart: () => setPending(true),
    onFinish: () => setPending(false),
  };

  return (
    <Layout title={`${item.title} · ${group.name}`} section="groups">
      <GroupHeader group={group} current="watchlist" nested />
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
          <div className="title-actions row">
            <button
              className="btn btn-secondary btn-sm"
              type="button"
              disabled={pending}
              onClick={() => router.patch(path, { watched: !item.watched }, requestOptions)}
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
          </div>
        </PageHeader>
      </div>
      {item.episodic && <EpisodeProgressSection {...props} />}
      <WatchProvidersSection availability={watch_providers} />
      {item.episodic && <EpisodeDiscussionSection {...props} />}
    </Layout>
  );
}
