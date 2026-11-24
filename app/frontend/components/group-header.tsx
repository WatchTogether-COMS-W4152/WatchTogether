import { Link } from "@inertiajs/react";
import type { ReactNode } from "react";

export type GroupTab = "watchlist" | "picks" | "members";

const TABS: { key: GroupTab; label: string }[] = [
  { key: "watchlist", label: "Watchlist" },
  { key: "picks", label: "Picks" },
  { key: "members", label: "Members" },
];

export default function GroupHeader({
  group,
  current,
  nested = false,
  actions,
}: {
  group: { id: number; name: string };
  current: GroupTab;
  nested?: boolean;
  actions?: ReactNode;
}) {
  return (
    <header className="group-header">
      {nested ? (
        <Link className="group-name" href={`/groups/${group.id}/watchlist`}>
          {group.name}
        </Link>
      ) : (
        <h1 className="group-name">{group.name}</h1>
      )}
      <div className="group-bar">
        <nav className="group-tabs" aria-label={group.name}>
          {TABS.map((tab) => (
            <Link
              key={tab.key}
              href={`/groups/${group.id}/${tab.key}`}
              className="group-tab"
              aria-current={current === tab.key ? (nested ? "true" : "page") : undefined}
            >
              {tab.label}
            </Link>
          ))}
        </nav>
        {actions && <div className="row">{actions}</div>}
      </div>
    </header>
  );
}
