import { Link, useForm } from "@inertiajs/react";
import { useState } from "react";

import EpisodeCode from "../../components/episode-code";
import Layout, { PageHeader } from "../../components/layout";
import { MediaMeta, Poster, TmdbAttribution } from "../../components/media-details";
import TitleSearch from "../../components/title-search";
import type { CatalogTitle, MediaMetadata } from "../../types/catalog";
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
  const form = useForm({ title: "" });
  const [selected, setSelected] = useState<CatalogTitle | null>(null);

  return (
    <Layout title={`Watchlist · ${group.name}`} section="groups">
      <PageHeader
        title="Watchlist"
        back={{ href: `/groups/${group.id}`, label: group.name }}
        actions={
          <Link className="btn btn-secondary" href={`/groups/${group.id}/suggestions`}>
            What should we watch?
          </Link>
        }
      />

      <section className="card read-width" aria-labelledby="watchlist-add">
        <h2 id="watchlist-add">Add a movie or show</h2>
        <form
          className="form"
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
          <div className="row">
            <button className="btn btn-primary" type="submit" disabled={form.processing}>
              {form.processing ? "Adding…" : "Add to watchlist"}
            </button>
          </div>
        </form>
      </section>

      <section aria-labelledby="watchlist-titles">
        <h2 id="watchlist-titles" className="visually-hidden">
          Movies and shows
        </h2>
        {watchlist_items.length === 0 ? (
          <p className="muted">Your watchlist is empty. Add your first movie.</p>
        ) : (
          <ul className="poster-grid">
            {watchlist_items.map((item) => (
              <li key={item.id}>
                <Link
                  className="poster-card"
                  href={`/groups/${group.id}/watchlist_items/${item.id}`}
                >
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
      <TmdbAttribution />
    </Layout>
  );
}
