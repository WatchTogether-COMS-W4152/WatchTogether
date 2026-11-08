import { Link, useForm, usePage } from "@inertiajs/react";
import { useState } from "react";

import Layout, { PageHeader } from "../../components/layout";
import type { GroupDetails } from "../../types";

export default function Group({ group }: { group: GroupDetails }) {
  const { auth } = usePage().props;
  const reset = useForm({});
  const deletion = useForm({});
  const [confirmReset, setConfirmReset] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [copyMessage, setCopyMessage] = useState("");
  const [copyError, setCopyError] = useState("");
  const isOwner = auth.user?.id === group.owner_id;

  async function copyInvitation() {
    setCopyMessage("");
    setCopyError("");
    try {
      if (!navigator.clipboard || !group.invitation_code) throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText(group.invitation_code);
      setCopyMessage("Invitation code copied.");
    } catch {
      setCopyError("Couldn't copy the code. Select and copy it manually.");
    }
  }

  async function shareInvitation() {
    setCopyMessage("");
    setCopyError("");
    try {
      await navigator.share({
        title: `Join ${group.name} on WatchTogether`,
        text: `Join my WatchTogether group, ${group.name}. Sign in and enter this invitation code: ${group.invitation_code}`,
        url: `${window.location.origin}/groups/join`,
      });
    } catch (error) {
      if (!(error instanceof DOMException && error.name === "AbortError")) {
        setCopyError("Sharing isn't available right now. Copy the invitation code instead.");
      }
    }
  }

  return (
    <Layout title={group.name}>
      <Link className="back-link" href="/groups">
        ← My groups
      </Link>
      <PageHeader
        eyebrow="Private group"
        title={group.name}
        description="Your people, all in one place."
      />
      <div className="details-grid">
        <section className="card members-card">
          <div className="section-label">
            <h2>The crew</h2>
            <span>
              {group.members.length} {group.members.length === 1 ? "member" : "members"}
            </span>
          </div>
          <ul className="member-list">
            {group.members.map((member) => (
              <li key={member.id}>
                <span className="avatar" aria-hidden="true">
                  {member.display_name.slice(0, 1).toUpperCase()}
                </span>
                <span className="member-name">
                  {member.display_name}
                  {member.id === auth.user?.id && <span className="muted"> (you)</span>}
                </span>
                {member.id === group.owner_id && <span className="badge">Owner</span>}
              </li>
            ))}
          </ul>
        </section>
        {isOwner && group.invitation_code ? (
          <section className="card invitation-card" aria-labelledby="invitation-title">
            <span className="eyebrow">Save them a seat</span>
            <h2 id="invitation-title">Invite your friends</h2>
            <p className="muted">Share this code with people you'd like in your group.</p>
            <p className="code-label">Invitation code</p>
            <code className="invite-code">{group.invitation_code}</code>
            <div className="invite-actions">
              <button
                className="button button-primary"
                type="button"
                onClick={() => void copyInvitation()}
              >
                Copy code
              </button>
              {typeof navigator.share === "function" && (
                <button
                  className="button button-secondary"
                  type="button"
                  onClick={() => void shareInvitation()}
                >
                  Share
                </button>
              )}
            </div>
            {copyMessage && <output className="inline-success">{copyMessage}</output>}
            {copyError && (
              <p className="field-error" role="alert">
                {copyError}
              </p>
            )}
            <p className="field-hint">
              This code stays valid until you replace it. Anyone with the code can join.
            </p>
            <div className="reset-invitation">
              {confirmReset ? (
                <div className="confirmation">
                  <p>
                    Replace this invitation code? The old code will stop working. Current members
                    will stay in the group.
                  </p>
                  <div className="invite-actions">
                    <button
                      type="button"
                      className="button button-danger"
                      disabled={reset.processing}
                      onClick={() =>
                        reset.post(`/groups/${group.id}/invitation/reset`, {
                          preserveScroll: true,
                          onSuccess: () => {
                            setConfirmReset(false);
                            setCopyMessage("");
                            setCopyError("");
                          },
                        })
                      }
                    >
                      {reset.processing ? "Replacing…" : "Replace code"}
                    </button>
                    <button
                      type="button"
                      className="text-button"
                      disabled={reset.processing}
                      onClick={() => setConfirmReset(false)}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              ) : (
                <button
                  className="text-button"
                  type="button"
                  disabled={deletion.processing}
                  onClick={() => {
                    setConfirmReset(true);
                    setConfirmDelete(false);
                  }}
                >
                  Replace invitation code
                </button>
              )}
            </div>
          </section>
        ) : (
          <aside className="card invitation-card member-note">
            <span className="eyebrow">Just for your crew</span>
            <h2>A private place to gather</h2>
            <p className="muted">
              Want to bring a friend? Ask your group owner for an invitation code.
            </p>
          </aside>
        )}
      </div>
      {isOwner && (
        <section className="card group-danger" aria-labelledby="delete-group-title">
          <h2 id="delete-group-title">Delete this group</h2>
          <p className="muted">
            Permanently remove this group for everyone. Member accounts will be kept.
          </p>
          {confirmDelete ? (
            <div className="confirmation">
              <p className="delete-warning">
                Delete “{group.name}”? Everyone will lose access and its invitation code will stop
                working. This cannot be undone.
              </p>
              <div className="invite-actions">
                <button
                  type="button"
                  className="button button-danger"
                  disabled={deletion.processing}
                  onClick={() => deletion.delete(`/groups/${group.id}`)}
                >
                  {deletion.processing ? "Deleting…" : "Yes, delete group"}
                </button>
                <button
                  type="button"
                  className="text-button"
                  disabled={deletion.processing}
                  onClick={() => setConfirmDelete(false)}
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <button
              type="button"
              className="button button-danger delete-trigger"
              disabled={reset.processing}
              onClick={() => {
                setConfirmDelete(true);
                setConfirmReset(false);
              }}
            >
              Delete group
            </button>
          )}
        </section>
      )}
    </Layout>
  );
}
