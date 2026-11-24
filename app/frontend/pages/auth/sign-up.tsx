import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function SignUp() {
  const form = useForm({ display_name: "", email: "", password: "", password_confirmation: "" });
  return (
    <Layout title="Create an account" narrow>
      <PageHeader title="Create your account" />
      <form
        className="card"
        noValidate
        onSubmit={(event) => {
          event.preventDefault();
          form.post("/sign-up", {
            onFinish: () => form.reset("password", "password_confirmation"),
          });
        }}
      >
        <FormError errors={form.errors} />
        <Field
          label="Display name"
          name="display_name"
          autoComplete="nickname"
          required
          maxLength={50}
          value={form.data.display_name}
          onChange={(event) => form.setData("display_name", event.target.value)}
          error={form.errors.display_name}
        />
        <Field
          label="Email"
          name="email"
          type="email"
          autoComplete="email"
          required
          maxLength={254}
          value={form.data.email}
          onChange={(event) => form.setData("email", event.target.value)}
          error={form.errors.email}
        />
        <Field
          label="Password"
          name="password"
          type="password"
          autoComplete="new-password"
          required
          value={form.data.password}
          onChange={(event) => form.setData("password", event.target.value)}
          error={form.errors.password}
          hint="At least 8 characters."
        />
        <Field
          label="Confirm password"
          name="password_confirmation"
          type="password"
          autoComplete="new-password"
          required
          value={form.data.password_confirmation}
          onChange={(event) => form.setData("password_confirmation", event.target.value)}
          error={form.errors.password_confirmation}
        />
        <div className="row">
          <button className="btn btn-primary" type="submit" disabled={form.processing}>
            {form.processing ? "Creating account…" : "Create account"}
          </button>
        </div>
      </form>
      <p className="form-footer meta">
        Already have an account? <Link href="/sign-in">Sign in</Link>
      </p>
    </Layout>
  );
}
