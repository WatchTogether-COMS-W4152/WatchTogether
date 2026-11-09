import { useEffect, useRef } from "react";

import type { GroupDetails } from "../types";

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
  const listTitle = useRef<HTMLHeadingElement | null>(null);

  useEffect(() => {
    if (panel) {
      panelTitle.current?.focus();
    } else if (trigger.current && document.activeElement === document.body) {
      // Restore focus when a panel control disappears, but don't steal it
      // when the user has deliberately moved to another part of the page.
      (trigger.current.isConnected ? trigger.current : listTitle.current)?.focus();
    }
  }, [panel]);

  return (
    <section className="card members-card" aria-labelledby="members-title">
      <div className="section-label">
        <h2 id="members-title" ref={listTitle} tabIndex={-1}>
          The crew
        </h2>
        <span>
          {group.members.length} {group.members.length === 1 ? "member" : "members"}
        </span>
      </div>
      {group.is_owner && (
        <p className="member-help muted">
          Owners share group management. Choose Manage to change someone's access.
        </p>
      )}
      <ul className="member-list">
        {group.members.map((member) => {
          const isActive = panel?.memberId === member.id;
          return (
            <li key={member.id}>
              <div className="member-row">
                <span className="avatar" aria-hidden="true">
                  {member.display_name.slice(0, 1).toUpperCase()}
                </span>
                <div className="member-identity">
                  <span className="member-name">
                    {member.display_name}
                    {member.id === currentUserId && <span className="muted"> (you)</span>}
                  </span>
                  {member.role === "owner" && <span className="badge">Owner</span>}
                </div>
                {group.is_owner && member.id !== currentUserId && (
                  <button
                    type="button"
                    className="button button-secondary manage-member"
                    aria-label={`Manage ${member.display_name}`}
                    aria-expanded={isActive}
                    aria-controls={isActive ? `member-panel-${member.id}` : undefined}
                    disabled={processing}
                    onClick={(event) => {
                      trigger.current = event.currentTarget;
                      onPanelChange(isActive ? null : { memberId: member.id, step: "actions" });
                    }}
                  >
                    Manage <span aria-hidden="true">{isActive ? "−" : "+"}</span>
                  </button>
                )}
              </div>
              {isActive && (
                // oxlint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- Escape dismisses the disclosure from any of its focused controls; the section remains a labeled region.
                <section
                  className="member-management"
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
                      <p className="muted">
                        {member.role === "owner"
                          ? "This owner has the same permissions as you."
                          : "This member can view the group and its members."}
                      </p>
                      {member.role === "member" && (
                        <button
                          type="button"
                          className="button button-secondary"
                          onClick={() => onPanelChange({ memberId: member.id, step: "promote" })}
                        >
                          Make owner
                        </button>
                      )}
                      <div className="member-removal-option">
                        <button
                          type="button"
                          className="text-button danger-text"
                          onClick={() => onPanelChange({ memberId: member.id, step: "remove" })}
                        >
                          Remove from group
                        </button>
                        <button
                          type="button"
                          className="text-button"
                          onClick={() => onPanelChange(null)}
                        >
                          Done
                        </button>
                      </div>
                    </>
                  ) : (
                    <>
                      <p className="muted">
                        {panel.step === "promote"
                          ? "They will have the same permissions as you: invite people, make other members owners, remove members (including other owners), and delete the group. You will stay an owner."
                          : `${member.role === "owner" ? "They will also lose their owner permissions. " : ""}They will lose access to this group. Their account will be kept. The invitation code will change so their saved code cannot be reused. Other members will stay; share the new code for any pending invitations.`}
                      </p>
                      <div className="invite-actions">
                        <button
                          type="button"
                          className="button button-secondary"
                          disabled={processing}
                          onClick={() => onPanelChange(null)}
                        >
                          Cancel
                        </button>
                        <button
                          type="button"
                          className={`button ${panel.step === "remove" ? "button-danger" : "button-primary"}`}
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
