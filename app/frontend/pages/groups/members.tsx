import { useForm, usePage } from "@inertiajs/react";
import { useEffect, useRef, useState } from "react";

import GroupHeader from "../../components/group-header";
import GroupMembers, { type MemberPanel } from "../../components/group-members";
import InlineConfirm from "../../components/inline-confirm";
import Layout from "../../components/layout";
import { useToast } from "../../components/toast-context";
import type { GroupDetails } from "../../types";

export default function Members({ group }: { group: GroupDetails }) {
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
    <Layout title={`Members · ${group.name}`} section="groups">
      <GroupHeader group={group} current="members" />
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
        ) : null}
      </div>
      <section className="danger-zone" aria-label="Leave or delete this group">
        <InlineConfirm
          label="Leave group"
          question={`Leave “${group.name}”? Your progress and ratings in this group will be deleted.`}
          confirmLabel="Yes, leave"
          pendingLabel="Leaving…"
          pending={action.processing}
          onConfirm={() => action.delete(`/groups/${group.id}/membership`)}
          flush
        />
        {group.is_owner && (
          <>
            {confirmDelete ? (
              <div className="confirm">
                <p>Delete “{group.name}” for everyone? This cannot be undone.</p>
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
                className="btn btn-quiet btn-sm is-danger"
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
          </>
        )}
      </section>
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

  const link = `${window.location.origin}/join/${code}`;

  async function copy() {
    try {
      await navigator.clipboard.writeText(link);
      toast({ message: "Invite link copied.", tone: "success" });
    } catch {
      toast({ message: "Couldn't copy the link.", tone: "error" });
    }
  }

  async function share() {
    try {
      await navigator.share({
        title: `Join ${group.name} on WatchTogether`,
        url: link,
      });
    } catch (error) {
      if (!(error instanceof DOMException && error.name === "AbortError")) {
        toast({
          message: "Couldn't share. Copy the link instead.",
          tone: "error",
        });
      }
    }
  }

  return (
    <section className="card" aria-labelledby="invitation-title">
      <h2 id="invitation-title">Invite people</h2>
      <code className="code-well">{code}</code>
      {confirming ? (
        <div className="confirm">
          <p>Replace this code? The old code will stop working.</p>
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
            Copy invite link
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
