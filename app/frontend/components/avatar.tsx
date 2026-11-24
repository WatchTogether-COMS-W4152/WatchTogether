function avatarSlot(name: string) {
  let hash = 0;
  for (const char of name) hash = (hash * 31 + (char.codePointAt(0) ?? 0)) % 2_147_483_647;
  return (hash % 8) + 1;
}

export default function Avatar({ name, size }: { name: string; size?: "sm" | "lg" }) {
  return (
    <span
      className={`avatar av-${avatarSlot(name)}${size ? ` avatar-${size}` : ""}`}
      aria-hidden="true"
    >
      {name.slice(0, 1).toUpperCase()}
    </span>
  );
}

export function AvatarStack({
  names,
  count,
  max = 3,
}: {
  names: string[];
  count: number;
  max?: number;
}) {
  const shown = names.slice(0, max);
  return (
    <span className="stack" aria-hidden="true">
      {shown.map((name, index) => (
        <Avatar key={`${index}-${name}`} name={name} size="sm" />
      ))}
      {count > shown.length && (
        <span className="avatar avatar-sm stack-more">+{count - shown.length}</span>
      )}
    </span>
  );
}
