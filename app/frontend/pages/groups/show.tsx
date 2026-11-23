import { Link, useForm, usePage } from "@inertiajs/react";
import { useEffect, useRef, useState } from "react";

import { AvatarStack } from "../../components/avatar";
import GroupMembers, { type MemberPanel } from "../../components/group-members";
import Layout, { PageHeader } from "../../components/layout";
import { useToast } from "../../components/toast-context";
import { memberCount, type GroupDetails } from "../../types";

export default function Group({ group }: { group: GroupDetails }) {
  const { auth } = usePage().props;
  const action = useForm({});
  const [memberPanel, setMemberPanel] = useState<MemberPanel | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const deleteCancel = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    if (confirmDelete) deleteCancel.current?.focus();
  }, [confirmDelete]);

  return (
    <Layout title={group.name} section="groups">
      <PageHeader
        title={group.name}
        back={{ href: "/groups", label: "Groups" }}
        meta={
          <>
            <AvatarStack
              names={group.members.map((member) => member.display_name)}
              count={group.members.length}
            />
            <span>{memberCount(group.members.length)}</span>
          </>
        }
        actions={
          <>
            <Link className="btn btn-secondary" href={`/groups/${group.id}/watchlist_items`}>
              Watchlist
            </Link>
            <Link className="btn btn-primary" href={`/groups/${group.id}/suggestions`}>
              What should we watch?
            </Link>
          </>
        }
      />
      <div className="group-layout">
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
              onSuccess: () => setMemberPanel(null),
            })
          }
          onRemove={(memberId) =>
            action.delete(`/groups/${group.id}/members/${memberId}`, {
              preserveScroll: true,
              onSuccess: () => setMemberPanel(null),
            })
          }
        />
        {group.is_owner && group.invitation_code ? (
          <InviteCard
            group={group}
            code={group.invitation_code}
            processing={action.processing}
            confirming={confirmReset}
            onConfirmingChange={(confirming) => {
              setConfirmReset(confirming);
              setConfirmDelete(false);
              setMemberPanel(null);
            }}
            onReset={() =>
              action.post(`/groups/${group.id}/invitation/reset`, {
                preserveScroll: true,
                onSuccess: () => setConfirmReset(false),
              })
            }
          />
        ) : (
          <section className="card" aria-labelledby="invitation-title">
            <h2 id="invitation-title">Invite people</h2>
            <p className="muted">Ask a group owner for the invitation code.</p>
          </section>
        )}
      </div>
      {group.is_owner && (
        <section className="danger-zone" aria-labelledby="delete-group-title">
          <h2 id="delete-group-title" className="visually-hidden">
            Delete this group
          </h2>
          {confirmDelete ? (
            <div className="confirm">
              <p>
                Delete “{group.name}”? Everyone will lose access and its invitation code will stop
                working. This cannot be undone.
              </p>
              <div className="row">
                <button
                  type="button"
                  className="btn btn-danger btn-sm"
                  disabled={action.processing}
                  onClick={() => action.delete(`/groups/${group.id}`)}
                >
                  {action.processing ? "Deleting…" : "Yes, delete group"}
                </button>
                <button
                  type="button"
                  className="btn btn-quiet btn-sm"
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
              className="btn btn-quiet btn-sm is-danger is-flush"
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

function InviteCard({
  group,
  code,
  processing,
  confirming,
  onConfirmingChange,
  onReset,
}: {
  group: GroupDetails;
  code: string;
  processing: boolean;
  confirming: boolean;
  onConfirmingChange: (confirming: boolean) => void;
  onReset: () => void;
}) {
  const toast = useToast();
  const cancel = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    if (confirming) cancel.current?.focus();
  }, [confirming]);

  async function copy() {
    try {
      await navigator.clipboard.writeText(code);
      toast({ message: "Invitation code copied.", tone: "success" });
    } catch {
      toast({ message: "Couldn't copy the code. Select and copy it manually.", tone: "error" });
    }
  }

  async function share() {
    try {
      await navigator.share({
        title: `Join ${group.name} on WatchTogether`,
        text: `Join my WatchTogether group, ${group.name}. Sign in and enter this invitation code: ${code}`,
        url: `${window.location.origin}/groups/join`,
      });
    } catch (error) {
      if (!(error instanceof DOMException && error.name === "AbortError")) {
        toast({
          message: "Sharing isn't available right now. Copy the invitation code instead.",
          tone: "error",
        });
      }
    }
  }

  return (
    <section className="card" aria-labelledby="invitation-title">
      <h2 id="invitation-title">Invite people</h2>
      <p className="muted">Anyone with this code can join the group.</p>
      <code className="code-well">{code}</code>
      {confirming ? (
        <div className="confirm">
          <p>
            Replace this invitation code? The old code will stop working. Current members will stay
            in the group.
          </p>
          <div className="row">
            <button
              type="button"
              className="btn btn-danger btn-sm"
              disabled={processing}
              onClick={onReset}
            >
              {processing ? "Replacing…" : "Yes, replace code"}
            </button>
            <button
              type="button"
              className="btn btn-quiet btn-sm"
              ref={cancel}
              disabled={processing}
              onClick={() => onConfirmingChange(false)}
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <div className="row">
          <button
            className="btn btn-secondary btn-sm"
            type="button"
            disabled={processing}
            onClick={() => void copy()}
          >
            Copy code
          </button>
          {typeof navigator.share === "function" && (
            <button
              className="btn btn-quiet btn-sm"
              type="button"
              disabled={processing}
              onClick={() => void share()}
            >
              Share
            </button>
          )}
          <button
            className="btn btn-quiet btn-sm"
            type="button"
            disabled={processing}
            onClick={() => onConfirmingChange(true)}
          >
            Replace code
          </button>
        </div>
      )}
    </section>
  );
}
