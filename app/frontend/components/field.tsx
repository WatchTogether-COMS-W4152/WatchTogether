import type { InputHTMLAttributes } from "react";

type FieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  name: string;
  error?: string[];
  hint?: string;
};

export default function Field({ label, name, error, hint, ...input }: FieldProps) {
  const descriptionId = error?.length ? `${name}-error` : hint ? `${name}-hint` : undefined;
  return (
    <div className="field">
      <label htmlFor={name}>{label}</label>
      <input
        {...input}
        id={name}
        name={name}
        aria-invalid={Boolean(error?.length)}
        aria-describedby={descriptionId}
      />
      {error?.length ? (
        <p className="field-error" id={`${name}-error`} role="alert">
          {error.join(". ")}
        </p>
      ) : hint ? (
        <p className="field-hint" id={`${name}-hint`}>
          {hint}
        </p>
      ) : null}
    </div>
  );
}

export function FormError({ errors }: { errors: Record<string, string[] | undefined> }) {
  return errors.base?.length ? (
    <p className="banner banner-error" role="alert">
      {errors.base.join(". ")}
    </p>
  ) : null;
}
