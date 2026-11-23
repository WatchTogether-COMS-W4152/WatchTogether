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
  return (
    <div>
      <button
        type="button"
        className="button button-secondary"
        disabled={form.processing || suggestion.in_watchlist}
        aria-label={
          suggestion.in_watchlist
            ? `${suggestion.title} is on the watchlist`
            : `Add ${suggestion.title} to watchlist`
        }
        onClick={() =>
          form.post(`/groups/${groupId}/suggestions/${suggestion.id}/watchlist`, {
            preserveScroll: true,
          })
        }
      >
        {suggestion.in_watchlist
          ? "On watchlist ✓"
          : form.processing
            ? "Adding…"
            : "Add to watchlist"}
      </button>
      {Object.entries(form.errors).map(([field, messages]) =>
        Array.isArray(messages) ? (
          <p key={field} className="field-error" role="alert">
            {messages.join(". ")}
          </p>
        ) : null,
      )}
    </div>
  );
}
