import { Head, Link, router, useForm, usePage } from "@inertiajs/react";
import { useEffect, useState, type ReactNode } from "react";

import type { FlashData } from "../types";
import { ToastContext, type ToastMessage } from "./toast-context";

const TOAST_DURATION = 4000;

export default function Layout({
  title,
  section,
  narrow = false,
  children,
}: {
  title: string;
  section?: "groups" | "profile";
  narrow?: boolean;
  children: ReactNode;
}) {
  const { auth, flash } = usePage().props;
  const logout = useForm({});
  const [requestError, setRequestError] = useState("");
  const [toast, setToast] = useState<ToastMessage | null>(null);
  const [closedNotice, setClosedNotice] = useState<FlashData | null>(null);
  const [closedAlert, setClosedAlert] = useState<FlashData | null>(null);

  useEffect(() => {
    const removeStart = router.on("start", () => setRequestError(""));
    const removeNetworkError = router.on("networkError", (event) => {
      event.preventDefault();
      setRequestError("Couldn't connect. Try again.");
    });
    const removeHttpException = router.on("httpException", (event) => {
      event.preventDefault();
      setRequestError("Something went wrong. Try again.");
    });
    return () => {
      removeStart();
      removeNetworkError();
      removeHttpException();
    };
  }, []);

  useEffect(() => {
    if (!flash?.notice) return undefined;
    const timer = window.setTimeout(() => setClosedNotice(flash), TOAST_DURATION);
    return () => window.clearTimeout(timer);
  }, [flash]);

  useEffect(() => {
    if (!toast || toast.tone === "error") return undefined;
    const timer = window.setTimeout(() => setToast(null), TOAST_DURATION);
    return () => window.clearTimeout(timer);
  }, [toast]);

  return (
    <ToastContext value={setToast}>
      <Head title={`${title} · WatchTogether`} />
      <header className="topbar">
        <div className="topbar-inner">
          <Link href={auth.user ? "/groups" : "/sign-in"} className="wordmark">
            WatchTogether
          </Link>
          {auth.user ? (
            <>
              <nav className="tabs" aria-label="Main">
                <Link
                  href="/groups"
                  className="tab"
                  aria-current={section === "groups" ? "page" : undefined}
                >
                  Groups
                </Link>
                <Link
                  href="/profile"
                  className="tab"
                  aria-current={section === "profile" ? "page" : undefined}
                >
                  Profile
                </Link>
              </nav>
              <button
                className="btn btn-quiet btn-sm"
                type="button"
                disabled={logout.processing}
                onClick={() => logout.delete("/session")}
              >
                {logout.processing ? "Signing out…" : "Sign out"}
              </button>
            </>
          ) : (
            <div className="topbar-actions">
              <Link href="/sign-in" className="btn btn-quiet btn-sm">
                Sign in
              </Link>
              <Link href="/sign-up" className="btn btn-secondary btn-sm">
                Sign up
              </Link>
            </div>
          )}
        </div>
      </header>
      <main className={narrow ? "page is-narrow" : "page"}>{children}</main>
      <div className="toasts">
        {flash?.notice && closedNotice !== flash && (
          <output className="toast toast-plain">{flash.notice}</output>
        )}
        {flash?.alert && closedAlert !== flash && (
          <ErrorToast message={flash.alert} onClose={() => setClosedAlert(flash)} />
        )}
        {requestError && <ErrorToast message={requestError} onClose={() => setRequestError("")} />}
        {toast &&
          (toast.tone === "error" ? (
            <ErrorToast message={toast.message} onClose={() => setToast(null)} />
          ) : (
            <output className={`toast toast-${toast.tone}`}>{toast.message}</output>
          ))}
      </div>
    </ToastContext>
  );
}

function ErrorToast({ message, onClose }: { message: string; onClose: () => void }) {
  return (
    <div className="toast toast-error" role="alert">
      <span>{message}</span>
      <button className="toast-close" type="button" onClick={onClose}>
        Close
      </button>
    </div>
  );
}

export function PageHeader({
  title,
  back,
  meta,
  actions,
  children,
}: {
  title: string;
  back?: { href: string; label: string };
  meta?: ReactNode;
  actions?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <header className="page-header">
      {back && (
        <Link className="back" href={back.href}>
          ← {back.label}
        </Link>
      )}
      <div className="page-title">
        <h1>{title}</h1>
        {actions && <div className="row">{actions}</div>}
      </div>
      {meta && <div className="page-meta">{meta}</div>}
      {children}
    </header>
  );
}
