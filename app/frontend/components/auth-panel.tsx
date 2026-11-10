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
    <div className="auth-page">
      <h1>{title}</h1>
      <p className="muted">{description}</p>
      {children}
    </div>
  );
}
