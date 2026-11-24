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
      <fieldset className="rating">
        <legend className="visually-hidden">Your rating for {suggestion.title}</legend>
        {RATING_OPTIONS.map((option) => {
          const active = suggestion.my_rating === option.value;
          return (
            <button
              key={option.value}
              type="button"
              aria-pressed={active}
              disabled={pending}
              onClick={() => {
                const path = `/groups/${groupId}/picks/${suggestion.id}/vote`;
                const options = {
                  preserveScroll: true,
                  onStart: () => {
                    setPending(true);
                    setError("");
                  },
                  onError: (errors: Record<string, string[] | undefined>) =>
                    setError(errors.rating?.join(". ") ?? "Couldn't save your rating."),
                  onFinish: () => setPending(false),
                };
                if (active) router.delete(path, options);
                else router.put(path, { rating: option.value }, options);
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
