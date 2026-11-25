import { useEffect, useRef } from "react";

import type { GroupDetails } from "../types";
import Avatar from "./avatar";

export type MemberPanel = { memberId: number; step: "actions" | "promote" | "remove" };

export default function GroupMembers({
  group,
  currentUserId,
  panel,
  onPanelChange,
  processing,
  onPromote,
  onRemove,
}: {
  group: GroupDetails;
  currentUserId?: number;
  panel: MemberPanel | null;
  onPanelChange: (panel: MemberPanel | null) => void;
  processing: boolean;
  onPromote: (memberId: number) => void;
  onRemove: (memberId: number) => void;
}) {
  const trigger = useRef<HTMLButtonElement | null>(null);
  const panelTitle = useRef<HTMLHeadingElement | null>(null);
  const panelCancel = useRef<HTMLButtonElement | null>(null);
  const listTitle = useRef<HTMLHeadingElement | null>(null);

  useEffect(() => {
    if (panel) {
      (panel.step === "actions" ? panelTitle : panelCancel).current?.focus();
    } else if (trigger.current && document.activeElement === document.body) {
      (trigger.current.isConnected ? trigger.current : listTitle.current)?.focus();
    }
  }, [panel]);

  return (
    <section className="card" aria-labelledby="members-title">
      <h2 id="members-title" ref={listTitle} tabIndex={-1}>
        Members
      </h2>
      <ul className="rows member-list">
        {group.members.map((member) => {
          const isActive = panel?.memberId === member.id;
          return (
            <li key={member.id}>
              <div className="person-row">
                <Avatar name={member.display_name} />
                <div className="member-identity">
                  <span className="who">
                    {member.display_name}
                    {member.id === currentUserId && <span className="muted"> (you)</span>}
                    {member.role === "owner" && <span className="chip">Owner</span>}
                  </span>
                  <p className="meta">
                    {member.services?.length ? member.services.join(", ") : "No services listed"}
                  </p>
                </div>
                {group.is_owner && member.id !== currentUserId && (
                  <button
                    type="button"
                    className="btn btn-quiet btn-sm"
                    aria-label={`Manage ${member.display_name}`}
                    aria-expanded={isActive}
                    aria-controls={isActive ? `member-panel-${member.id}` : undefined}
                    disabled={processing}
                    onClick={(event) => {
                      trigger.current = event.currentTarget;
                      onPanelChange(isActive ? null : { memberId: member.id, step: "actions" });
                    }}
                  >
                    Manage
                  </button>
                )}
              </div>
              {isActive && (
                // oxlint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- Escape dismisses the disclosure from any of its focused controls; the section remains a labeled region.
                <section
                  className="well"
                  id={`member-panel-${member.id}`}
                  aria-labelledby={`member-panel-title-${member.id}`}
                  onKeyDown={(event) => {
                    if (event.key === "Escape" && !processing) onPanelChange(null);
                  }}
                >
                  <h3 id={`member-panel-title-${member.id}`} ref={panelTitle} tabIndex={-1}>
                    {panel.step === "promote"
                      ? `Make ${member.display_name} an owner?`
                      : panel.step === "remove"
                        ? `Remove ${member.display_name} from the group?`
                        : `Manage ${member.display_name}`}
                  </h3>
                  {panel.step === "actions" ? (
                    <>
                      <div className="row">
                        {member.role === "member" && (
                          <button
                            type="button"
                            className="btn btn-secondary btn-sm"
                            onClick={() => onPanelChange({ memberId: member.id, step: "promote" })}
                          >
                            Make owner
                          </button>
                        )}
                        <button
                          type="button"
                          className="btn btn-quiet btn-sm is-danger"
                          onClick={() => onPanelChange({ memberId: member.id, step: "remove" })}
                        >
                          Remove from group
                        </button>
                        <button
                          type="button"
                          className="btn btn-quiet btn-sm"
                          onClick={() => onPanelChange(null)}
                        >
                          Done
                        </button>
                      </div>
                    </>
                  ) : (
                    <>
                      <p className="meta">
                        {panel.step === "promote"
                          ? "They'll be able to invite and remove people, and delete the group."
                          : "They'll lose access, their progress and ratings here will be deleted, and the invitation code will change."}
                      </p>
                      <div className="row">
                        <button
                          type="button"
                          className={`btn btn-sm ${panel.step === "remove" ? "btn-danger" : "btn-secondary"}`}
                          disabled={processing}
                          onClick={() =>
                            panel.step === "promote" ? onPromote(member.id) : onRemove(member.id)
                          }
                        >
                          {panel.step === "promote"
                            ? processing
                              ? "Promoting…"
                              : "Confirm promotion"
                            : processing
                              ? "Removing…"
                              : "Confirm removal"}
                        </button>
                        <button
                          type="button"
                          className="btn btn-quiet btn-sm"
                          ref={panelCancel}
                          disabled={processing}
                          onClick={() => onPanelChange(null)}
                        >
                          Cancel
                        </button>
                      </div>
                    </>
                  )}
                </section>
              )}
            </li>
          );
        })}
      </ul>
    </section>
  );
}
