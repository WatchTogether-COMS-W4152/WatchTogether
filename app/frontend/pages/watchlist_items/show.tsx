import "../../styles/catalog.css";
import { Link, usePage } from "@inertiajs/react";

import EpisodeDiscussionSection from "../../components/episode-discussion";
import EpisodeProgressSection from "../../components/episode-progress";
import Layout, { PageHeader } from "../../components/layout";
import MediaDetails, { MediaPoster } from "../../components/media-details";
import WatchProvidersSection, { type WatchProviders } from "../../components/watch-providers";
import type { MediaMetadata } from "../../types/catalog";

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
  return (
    <Layout title={`${item.title} · ${group.name}`}>
      <Link className="back-link" href={`/groups/${group.id}/watchlist_items`}>
        ← Watchlist
      </Link>
      <div className="watchlist-item-header">
        {item.tmdb_id && <MediaPoster {...item} />}
        <div>
          <PageHeader title={item.title} />
          <MediaDetails media={item} />
        </div>
      </div>
      <WatchProvidersSection availability={watch_providers} />
      {item.episodic ? (
        <>
          <EpisodeProgressSection {...props} />
          <EpisodeDiscussionSection {...props} />
        </>
      ) : (
        <p className="muted">Episode tracking and discussion are available for TV shows.</p>
      )}
    </Layout>
  );
}
