import { router } from "@inertiajs/react";

export type Watchability = {
  included: boolean;
  label: string;
};

export const EMPTY_FILTER_MESSAGE = "Nothing everyone can watch without paying extra.";

export function WatchabilityFilter({ filtering, path }: { filtering: boolean; path: string }) {
  return (
    <div className="watchability-filter">
      <button
        className={`btn btn-sm ${filtering ? "btn-primary" : "btn-secondary"}`}
        type="button"
        aria-pressed={filtering}
        onClick={() =>
          router.get(path, filtering ? {} : { where: "everyone" }, { preserveScroll: true })
        }
      >
        Where can we all watch?
      </button>
    </div>
  );
}

export function WatchabilityLabel({ watchability }: { watchability?: Watchability }) {
  if (!watchability) return null;
  return <p className="meta">{watchability.label}</p>;
}
