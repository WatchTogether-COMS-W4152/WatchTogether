import { useEffect, useRef, useState, type ReactNode } from "react";

export default function InlineConfirm({
  label,
  accessibleLabel,
  question,
  confirmLabel,
  pendingLabel,
  pending,
  onConfirm,
  flush = false,
}: {
  label: string;
  accessibleLabel?: string;
  question: ReactNode;
  confirmLabel: string;
  pendingLabel: string;
  pending: boolean;
  onConfirm: () => void;
  flush?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const cancel = useRef<HTMLButtonElement | null>(null);
  const wasOpen = useRef(false);

  useEffect(() => {
    if (open) cancel.current?.focus();
    else if (wasOpen.current) trigger.current?.focus();
    wasOpen.current = open;
  }, [open]);

  return open ? (
    <div className="confirm">
      <p>{question}</p>
      <div className="row">
        <button
          type="button"
          className="btn btn-danger btn-sm"
          disabled={pending}
          onClick={onConfirm}
        >
          {pending ? pendingLabel : confirmLabel}
        </button>
        <button
          type="button"
          className="btn btn-quiet btn-sm"
          ref={cancel}
          disabled={pending}
          onClick={() => setOpen(false)}
        >
          Cancel
        </button>
      </div>
    </div>
  ) : (
    <button
      type="button"
      className={`btn btn-quiet btn-sm is-danger${flush ? " is-flush" : ""}`}
      ref={trigger}
      aria-label={accessibleLabel}
      disabled={pending}
      onClick={() => setOpen(true)}
    >
      {label}
    </button>
  );
}
