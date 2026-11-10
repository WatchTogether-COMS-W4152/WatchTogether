
import { Link, router, useForm } from "@inertiajs/react";

import Field from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

type WatchlistItem = {
  id: number;
  title: string;
  watched: boolean;
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

  return (
    <Layout title={`Watchlist · ${group.name}`}>
      <Link className="back-link" href={`/groups/${group.id}`}>
        ← {group.name}
      </Link>

      <PageHeader
        eyebrow={group.name}
        title="Our Watchlist"
        description="Keep track of movies and shows your group wants to watch."
      />

      <section className="card">
        <h2>Add a movie or show</h2>

        <form
          noValidate
          onSubmit={(event) => {
            event.preventDefault();

            form.post(`/groups/${group.id}/watchlist_items`, {
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
            placeholder="Titanic"
            value={form.data.title}
            onChange={(event) => form.setData("title", event.target.value)}
            error={form.errors.title}
          />

          <button
            className="button button-primary"
            type="submit"
            disabled={form.processing}
          >
            {form.processing ? "Adding…" : "Add to Watchlist"}
          </button>
        </form>
      </section>

      <section className="card">
        <h2>Movies & Shows</h2>

        {watchlist_items.length === 0 ? (
          <p className="muted">
            Your watchlist is empty. Add your first movie!
          </p>
        ) : (
          <ul>
            {watchlist_items.map((item) => (
              <li key={item.id}>
                <strong>{item.title}</strong>
                {" — "}
                {item.watched ? "Watched ✓" : "Not watched"}

                <button
                  className="button"
                  type="button"
                  style={{ marginLeft: "12px" }}
                  onClick={() => {
                    router.patch(
                      `/groups/${group.id}/watchlist_items/${item.id}`,
                      {},
                      { preserveScroll: true }
                    );
                  }}
                >
                  {item.watched ? "Mark as Unwatched" : "Mark as Watched"}
                </button>
<button
  className="button"
  type="button"
  style={{ marginLeft: "8px" }}
  onClick={() => {
    if (window.confirm(`Remove "${item.title}" from the watchlist?`)) {
      router.delete(
        `/groups/${group.id}/watchlist_items/${item.id}`,
        { preserveScroll: true }
      );
    }
  }}
>
  Remove
</button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </Layout>
  );
}

