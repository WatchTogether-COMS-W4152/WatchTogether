import { Link } from "@inertiajs/react";

import Avatar from "../../components/avatar";
import Layout, { PageHeader } from "../../components/layout";
import type { GroupSummary } from "../../types";

export default function Groups({ groups }: { groups: GroupSummary[] }) {
  return (
    <Layout title="Groups">
      <PageHeader
        title="Groups"
        actions={
          <>
            <Link className="button button-secondary" href="/groups/join">
              Join a group
            </Link>
            <Link className="button button-primary" href="/groups/new">
              New group
            </Link>
          </>
        }
      />
      {groups.length ? (
        <ul className="list">
          {groups.map((group) => (
            <li key={group.id}>
              <Link className="group-row" href={`/groups/${group.id}`}>
                <Avatar name={group.name} square />
                <div className="group-row-text">
                  <h3>{group.name}</h3>
                  <p>
                    {group.member_count} {group.member_count === 1 ? "member" : "members"}
                    {group.is_owner ? " · Owner" : ""}
                  </p>
                </div>
                <span className="chevron" aria-hidden="true">
                  ›
                </span>
              </Link>
            </li>
          ))}
        </ul>
      ) : (
        <section className="empty-state">
          <h2>No groups yet</h2>
          <p>Create a group for the people you watch with, or join one with an invitation code.</p>
          <Link className="button button-primary" href="/groups/new">
            Create a group
          </Link>
        </section>
      )}
    </Layout>
  );
}
