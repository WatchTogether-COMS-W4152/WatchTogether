import { Head, Link, router, useForm, usePage } from "@inertiajs/react";
import { useEffect, useState, type ReactNode } from "react";

import Avatar from "./avatar";

export default function Layout({
  title,
  children,
  narrow = false,
}: {
  title: string;
  children: ReactNode;
  narrow?: boolean;
}) {
  const { auth, flash } = usePage().props;
  const logout = useForm({});
  const [requestError, setRequestError] = useState("");

  useEffect(() => {
    const removeStart = router.on("start", () => setRequestError(""));
    const removeNetworkError = router.on("networkError", (event) => {
      event.preventDefault();
      setRequestError("We couldn't connect. Check your connection and try again.");
    });
    const removeHttpException = router.on("httpException", (event) => {
      event.preventDefault();
      setRequestError("We couldn't complete that request. Please try again.");
    });
    return () => {
      removeStart();
      removeNetworkError();
      removeHttpException();
    };
  }, []);

  return (
    <div className="app-shell">
      <Head title={`${title} · WatchTogether`} />
      <header className="site-header">
        <div className="header-inner">
          <Link href={auth.user ? "/groups" : "/sign-in"} className="brand">
            Watch<span>Together</span>
          </Link>
          <nav aria-label="Main navigation">
            {auth.user ? (
              <>
                <Link href="/groups" className="nav-link">
                  Groups
                </Link>
                <Link href="/profile" className="nav-link profile-link">
                  <Avatar name={auth.user.display_name} size="small" />
                  <span>Profile</span>
                </Link>
                <button
                  className="text-button"
                  type="button"
                  disabled={logout.processing}
                  onClick={() => logout.delete("/session")}
                >
                  {logout.processing ? "Signing out…" : "Sign out"}
                </button>
              </>
            ) : (
              <>
                <Link href="/sign-in" className="nav-link">
                  Sign in
                </Link>
                <Link href="/sign-up" className="button button-primary">
                  Sign up
                </Link>
              </>
            )}
          </nav>
        </div>
      </header>
      <main className={`main-content${narrow ? " main-narrow" : ""}`}>
        {flash?.notice && <output className="banner banner-success">{flash.notice}</output>}
        {flash?.alert && (
          <p className="banner banner-error" role="alert">
            {flash.alert}
          </p>
        )}
        {requestError && (
          <p className="banner banner-error" role="alert">
            {requestError}
          </p>
        )}
        {children}
      </main>
    </div>
  );
}

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="page-header">
      <div>
        <h1>{title}</h1>
        {description && <p className="page-description">{description}</p>}
      </div>
      {actions && <div className="header-actions">{actions}</div>}
    </div>
  );
}
