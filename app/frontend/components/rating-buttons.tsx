import { router } from "@inertiajs/react";
import { useState } from "react";

import { RATING_OPTIONS, type Suggestion } from "../types/voting";

export default function RatingButtons({
  groupId,
  suggestion,
}: {
  groupId: number;
  suggestion: Suggestion;
}) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");

  return (
    <div className="rating-control">
      <fieldset className="rating-buttons">
        <legend className="visually-hidden">Your rating for {suggestion.title}</legend>
        {RATING_OPTIONS.map((option) => {
          const active = suggestion.my_rating === option.value;
          return (
            <button
              key={option.value}
              type="button"
              className={`rating-button rating-${option.value}${active ? " is-active" : ""}`}
              aria-pressed={active}
              disabled={pending}
              onClick={() => {
                if (active) return;
                router.put(
                  `/groups/${groupId}/suggestions/${suggestion.id}/vote`,
                  { rating: option.value },
                  {
                    preserveScroll: true,
                    onStart: () => {
                      setPending(true);
                      setError("");
                    },
                    onError: (errors) => setError(errors.rating?.join(". ") ?? "Please try again."),
                    onFinish: () => setPending(false),
                  },
                );
              }}
            >
              {option.label}
            </button>
          );
        })}
      </fieldset>
      {error && (
        <p className="field-error" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
