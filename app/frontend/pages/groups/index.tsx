import { Link, usePage } from "@inertiajs/react";

import Layout, { PageHeader } from "../../components/layout";
import type { GroupSummary } from "../../types";

export default function Groups({ groups }: { groups: GroupSummary[] }) {
  const { auth } = usePage().props;
  return (
    <Layout title="My groups">
      <PageHeader
        eyebrow="Your circle"
        title="My groups"
        description="A good watch night starts with good company."
        actions={
          <>
            <Link className="button button-secondary" href="/groups/join">
              Join a group
            </Link>
            <Link className="button button-primary" href="/groups/new">
              <span aria-hidden="true">＋</span> Create a group
            </Link>
          </>
        }
      />
      <div className="section-label">
        <h2>Your watch crews</h2>
        <span>
          {groups.length} {groups.length === 1 ? "group" : "groups"}
        </span>
      </div>
      {groups.length ? (
        <div className="group-grid">
          {groups.map((group, index) => (
            <Link className="card group-card" href={`/groups/${group.id}`} key={group.id}>
              <div className={`group-cover cover-${index % 3}`} aria-hidden="true">
                <span>▶</span>
                <div className="cover-orbit" />
              </div>
              <div className="group-card-content">
                <div className="group-card-heading">
                  <h3>{group.name}</h3>
                  <span aria-hidden="true">↗</span>
                </div>
                <div className="group-card-meta">
                  <span>
                    {group.member_count} {group.member_count === 1 ? "member" : "members"}
                  </span>
                  <span className="badge">
                    {group.owner_id === auth.user?.id ? "Owner" : "Member"}
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <section className="card empty-state">
          <span className="empty-icon" aria-hidden="true">
            ✦
          </span>
          <h2>Your next watch night starts here</h2>
          <p>Create a private group and invite your friends, or join one with a code.</p>
          <Link className="button button-primary" href="/groups/new">
            Create your first group
          </Link>
        </section>
      )}
    </Layout>
  );
}
