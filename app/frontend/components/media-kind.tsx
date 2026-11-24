const KINDS = [
  { value: "movie", label: "Movie" },
  { value: "tv", label: "TV show" },
] as const;

export default function MediaKind({
  value,
  disabled,
  onChange,
}: {
  value: string;
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <fieldset className="field media-kind">
      <legend>Type</legend>
      <div className="rating">
        {KINDS.map((kind) => (
          <button
            key={kind.value}
            type="button"
            aria-pressed={value === kind.value}
            disabled={disabled}
            onClick={() => onChange(kind.value)}
          >
            {kind.label}
          </button>
        ))}
      </div>
    </fieldset>
  );
}
