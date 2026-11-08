import type { ReactNode } from "react";

export default function AuthPanel({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <div className="auth-grid">
      <section className="auth-intro" aria-label="About WatchTogether">
        <p className="eyebrow">Your people. Your watch night.</p>
        <h2>
          Better <br />
          together.
        </h2>
        <p>
          A private place for your favorite people to get together around what you love watching.
        </p>
        <div className="watch-night-art" aria-hidden="true">
          <div className="movie-frame">
            <span>▶</span>
            <div className="movie-frame-line" />
          </div>
          <div className="friend-bubbles">
            <span>A</span>
            <span>J</span>
            <span>M</span>
            <span>+ you</span>
          </div>
          <p>Make room for your crew.</p>
        </div>
      </section>
      <section className="card auth-card">
        <h1>{title}</h1>
        <p className="muted">{description}</p>
        {children}
      </section>
    </div>
  );
}
