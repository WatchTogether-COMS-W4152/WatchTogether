import { Link, useForm, usePage } from "@inertiajs/react";
import { useEffect, useRef, useState } from "react";

import GroupMembers, { type MemberPanel } from "../../components/group-members";
import Layout, { PageHeader } from "../../components/layout";
import type { GroupDetails } from "../../types";

export default function Group({ group }: { group: GroupDetails }) {
  const { auth } = usePage().props;
  const action = useForm({});
  const [memberPanel, setMemberPanel] = useState<MemberPanel | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [copyMessage, setCopyMessage] = useState("");
  const [copyError, setCopyError] = useState("");
  const isOwner = group.is_owner;
  const resetCancel = useRef<HTMLButtonElement | null>(null);
  const deleteCancel = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    if (confirmReset) resetCancel.current?.focus();
    if (confirmDelete) deleteCancel.current?.focus();
  }, [confirmReset, confirmDelete]);

  function finishMemberAction() {
    setMemberPanel(null);
    setCopyMessage("");
    setCopyError("");
  }

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
        actions={
          <Link className="button button-primary" href={`/groups/${group.id}/suggestions`}>
            What should we watch?
          </Link>
        }
      />
      <div className="details-grid">
        <GroupMembers
          group={group}
          currentUserId={auth.user?.id}
          panel={memberPanel}
          processing={action.processing}
          onPanelChange={(panel) => {
            setMemberPanel(panel);
            setConfirmReset(false);
            setConfirmDelete(false);
          }}
          onPromote={(memberId) =>
            action.post(`/groups/${group.id}/members/${memberId}/promote`, {
              preserveScroll: true,
              onSuccess: finishMemberAction,
            })
          }
          onRemove={(memberId) =>
            action.delete(`/groups/${group.id}/members/${memberId}`, {
              preserveScroll: true,
              onSuccess: finishMemberAction,
            })
          }
        />
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
                disabled={action.processing}
                onClick={() => void copyInvitation()}
              >
                Copy code
              </button>
              {typeof navigator.share === "function" && (
                <button
                  className="button button-secondary"
                  type="button"
                  disabled={action.processing}
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
                      disabled={action.processing}
                      onClick={() =>
                        action.post(`/groups/${group.id}/invitation/reset`, {
                          preserveScroll: true,
                          onSuccess: () => {
                            setConfirmReset(false);
                            setCopyMessage("");
                            setCopyError("");
                          },
                        })
                      }
                    >
                      {action.processing ? "Replacing…" : "Replace code"}
                    </button>
                    <button
                      type="button"
                      className="text-button"
                      ref={resetCancel}
                      disabled={action.processing}
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
                  disabled={action.processing}
                  onClick={() => {
                    setConfirmReset(true);
                    setConfirmDelete(false);
                    setMemberPanel(null);
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
              Want to bring a friend? Ask a group owner for an invitation code.
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
                  disabled={action.processing}
                  onClick={() => action.delete(`/groups/${group.id}`)}
                >
                  {action.processing ? "Deleting…" : "Yes, delete group"}
                </button>
                <button
                  type="button"
                  className="text-button"
                  ref={deleteCancel}
                  disabled={action.processing}
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
              disabled={action.processing}
              onClick={() => {
                setConfirmDelete(true);
                setConfirmReset(false);
                setMemberPanel(null);
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
