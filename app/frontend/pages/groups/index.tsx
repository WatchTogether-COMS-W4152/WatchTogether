import { Link } from "@inertiajs/react";

import { AvatarStack } from "../../components/avatar";
import EpisodeCode from "../../components/episode-code";
import Layout, { PageHeader } from "../../components/layout";
import { memberCount, type GroupSummary } from "../../types";

export default function Groups({ groups }: { groups: GroupSummary[] }) {
  return (
    <Layout title="Groups" section="groups">
      <PageHeader
        title="Groups"
        actions={
          <>
            <Link className="btn btn-secondary" href="/groups/join">
              Join a group
            </Link>
            {groups.length > 0 && (
              <Link className="btn btn-primary" href="/groups/new">
                New group
              </Link>
            )}
          </>
        }
      />
      {groups.length ? (
        <ul className="group-list">
          {groups.map((group) => (
            <li key={group.id}>
              <Link className="group-card" href={`/groups/${group.id}`}>
                <div>
                  <h2 className="item-title">{group.name}</h2>
                  <p className="meta">
                    {memberCount(group.member_count)}
                    {group.is_owner ? " · Owner" : ""}
                  </p>
                </div>
                <AvatarStack names={group.member_names} count={group.member_count} />
                {group.show_in_progress && (
                  <p className="next">
                    {group.show_in_progress.title}
                    <EpisodeCode position={group.show_in_progress.next_episode} next />
                  </p>
                )}
              </Link>
            </li>
          ))}
        </ul>
      ) : (
        <section className="empty">
          <h2>No groups yet</h2>
          <Link className="btn btn-primary" href="/groups/new">
            Create a group
          </Link>
        </section>
      )}
    </Layout>
  );
}
