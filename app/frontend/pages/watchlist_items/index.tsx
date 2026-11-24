import { Link } from "@inertiajs/react";
import { useState } from "react";

import AddTitleForm from "../../components/add-title-form";
import EpisodeCode from "../../components/episode-code";
import GroupHeader from "../../components/group-header";
import Layout from "../../components/layout";
import { MediaMeta, Poster } from "../../components/media-details";
import type { MediaMetadata } from "../../types/catalog";
import type { EpisodePosition } from "../../types/episodes";

type WatchlistItem = MediaMetadata & {
  id: number;
  title: string;
  watched: boolean;
  next_episode?: EpisodePosition | null;
};

type Group = {
  id: number;
  name: string;
};

export default function Watchlist({
  group,
  watchlist_items,
}: {
  group: Group;
  watchlist_items: WatchlistItem[];
}) {
  const [adding, setAdding] = useState(watchlist_items.length === 0);

  return (
    <Layout title={`Watchlist · ${group.name}`} section="groups">
      <GroupHeader
        group={group}
        current="watchlist"
        actions={
          !adding && (
            <button
              className="btn btn-primary btn-sm"
              type="button"
              onClick={() => setAdding(true)}
            >
              Add a title
            </button>
          )
        }
      />

      {adding && (
        <AddTitleForm
          groupId={group.id}
          action={`/groups/${group.id}/watchlist`}
          submitLabel="Add to watchlist"
          onClose={watchlist_items.length > 0 ? () => setAdding(false) : undefined}
        />
      )}

      <section aria-labelledby="watchlist-titles">
        <h2 id="watchlist-titles" className="visually-hidden">
          Movies and shows
        </h2>
        {watchlist_items.length === 0 ? (
          <p className="muted">Nothing on the watchlist yet.</p>
        ) : (
          <ul className="poster-grid">
            {watchlist_items.map((item) => (
              <li key={item.id}>
                <Link className="poster-card" href={`/groups/${group.id}/watchlist/${item.id}`}>
                  <Poster title={item.title} poster_url={item.poster_url}>
                    {item.next_episode && !item.watched ? (
                      <EpisodeCode position={item.next_episode} next />
                    ) : item.watched ? (
                      <span className="chip">Watched</span>
                    ) : null}
                  </Poster>
                  <h3>{item.title}</h3>
                  <MediaMeta media={item} />
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>
    </Layout>
  );
}
