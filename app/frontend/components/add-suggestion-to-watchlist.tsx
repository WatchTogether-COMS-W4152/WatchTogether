import { useForm } from "@inertiajs/react";

import type { Suggestion } from "../types/voting";

export default function AddSuggestionToWatchlist({
  groupId,
  suggestion,
}: {
  groupId: number;
  suggestion: Suggestion;
}) {
  const form = useForm({});
  if (suggestion.in_watchlist) return <span className="chip">On watchlist</span>;
  return (
    <>
      <button
        type="button"
        className="btn btn-secondary btn-sm"
        disabled={form.processing}
        aria-label={`Add ${suggestion.title} to watchlist`}
        onClick={() =>
          form.post(`/groups/${groupId}/suggestions/${suggestion.id}/watchlist`, {
            preserveScroll: true,
          })
        }
      >
        {form.processing ? "Adding…" : "Add to watchlist"}
      </button>
      {Object.entries(form.errors).map(([field, messages]) =>
        Array.isArray(messages) ? (
          <p key={field} className="field-error" role="alert">
            {messages.join(". ")}
          </p>
        ) : null,
      )}
    </>
  );
}
