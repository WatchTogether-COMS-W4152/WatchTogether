import { Link, router, useForm } from "@inertiajs/react";
import { useState } from "react";

import Layout, { PageHeader } from "../../components/layout";
import MediaDetails, { MediaPoster, TmdbAttribution } from "../../components/media-details";
import TitleSearch from "../../components/title-search";
import type { CatalogTitle, MediaMetadata } from "../../types/catalog";
import { formatEpisode, type EpisodePosition } from "../../types/episodes";

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
  const form = useForm({ title: "" });
  const [selected, setSelected] = useState<CatalogTitle | null>(null);

  return (
    <Layout title={`Watchlist · ${group.name}`}>
      <Link className="back-link" href={`/groups/${group.id}`}>
        ← {group.name}
      </Link>

      <PageHeader
        title="Our Watchlist"
        description="Keep track of movies and shows your group wants to watch."
        actions={
          <Link className="button button-secondary" href={`/groups/${group.id}/suggestions`}>
            What should we watch? →
          </Link>
        }
      />

      <section className="panel watchlist-add">
        <h2>Add a movie or show</h2>

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
            form.post(`/groups/${group.id}/watchlist_items`, {
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
            {form.processing ? "Adding…" : "Add to Watchlist"}
          </button>
        </form>
      </section>

      <section aria-labelledby="watchlist-titles">
        <div className="section-label">
          <h2 id="watchlist-titles">Movies & Shows</h2>
          <span>
            {watchlist_items.length} {watchlist_items.length === 1 ? "title" : "titles"}
          </span>
        </div>

        {watchlist_items.length === 0 ? (
          <p className="muted">Your watchlist is empty. Add your first movie!</p>
        ) : (
          <ul className="list">
            {watchlist_items.map((item) => (
              <li key={item.id} className="watchlist-entry">
                {item.tmdb_id && <MediaPoster {...item} />}
                <div className="media-copy">
                  <h3>
                    <Link href={`/groups/${group.id}/watchlist_items/${item.id}`}>
                      {item.title}
                    </Link>
                  </h3>
                  <MediaDetails media={item} />
                  {item.next_episode && (
                    <span className="watchlist-next">
                      Next together: {formatEpisode(item.next_episode)}
                    </span>
                  )}
                  <span className={`watchlist-state${item.watched ? " is-watched" : ""}`}>
                    {item.watched ? "Watched ✓" : "Not watched"}
                  </span>
                  <div className="watchlist-entry-actions">
                    <button
                      className="button button-secondary"
                      type="button"
                      onClick={() => {
                        router.patch(
                          `/groups/${group.id}/watchlist_items/${item.id}`,
                          {},
                          { preserveScroll: true },
                        );
                      }}
                    >
                      {item.watched ? "Mark as Unwatched" : "Mark as Watched"}
                    </button>
                    <button
                      className="text-button danger-text"
                      type="button"
                      onClick={() => {
                        if (window.confirm(`Remove "${item.title}" from the watchlist?`)) {
                          router.delete(`/groups/${group.id}/watchlist_items/${item.id}`, {
                            preserveScroll: true,
                          });
                        }
                      }}
                    >
                      Remove
                    </button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
      <TmdbAttribution />
    </Layout>
  );
}
