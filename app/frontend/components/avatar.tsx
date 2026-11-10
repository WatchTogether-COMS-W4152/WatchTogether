const COLORS = [
  "#e5484d",
  "#f76b15",
  "#ca8a04",
  "#30a46c",
  "#12a594",
  "#0090ff",
  "#6e56cf",
  "#d6409f",
];

function avatarColor(name: string) {
  let hash = 0;
  for (const char of name) hash = (hash * 31 + (char.codePointAt(0) ?? 0)) % 2_147_483_647;
  return COLORS[hash % COLORS.length];
}

export default function Avatar({
  name,
  size,
  square = false,
}: {
  name: string;
  size?: "small" | "large";
  square?: boolean;
}) {
  return (
    <span
      className={square ? "group-avatar" : `avatar${size ? ` avatar-${size}` : ""}`}
      style={{ background: avatarColor(name) }}
      aria-hidden="true"
    >
      {name.slice(0, 1).toUpperCase()}
    </span>
  );
}
