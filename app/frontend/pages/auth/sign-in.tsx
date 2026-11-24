import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function SignIn() {
  const form = useForm({ email: "", password: "" });
  return (
    <Layout title="Sign in" narrow>
      <PageHeader title="Sign in" />
      <form
        className="card"
        noValidate
        onSubmit={(event) => {
          event.preventDefault();
          form.post("/sign-in", { onFinish: () => form.reset("password") });
        }}
      >
        <FormError errors={form.errors} />
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
          autoComplete="current-password"
          required
          value={form.data.password}
          onChange={(event) => form.setData("password", event.target.value)}
          error={form.errors.password}
        />
        <div className="row">
          <button className="btn btn-primary" type="submit" disabled={form.processing}>
            {form.processing ? "Signing in…" : "Sign in"}
          </button>
        </div>
      </form>
      <p className="form-footer meta">
        Don't have an account? <Link href="/sign-up">Sign up</Link>
      </p>
    </Layout>
  );
}
