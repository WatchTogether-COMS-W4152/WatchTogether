import { Link, useForm } from "@inertiajs/react";

import AuthPanel from "../../components/auth-panel";
import Field, { FormError } from "../../components/field";
import Layout from "../../components/layout";

export default function SignIn() {
  const form = useForm({ email: "", password: "" });
  return (
    <Layout title="Sign in">
      <AuthPanel title="Welcome back" description="Sign in to find your people.">
        <form
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
          <button
            className="button button-primary button-full"
            type="submit"
            disabled={form.processing}
          >
            {form.processing ? "Signing in…" : "Sign in"}
          </button>
        </form>
        <p className="form-footer">
          New here? <Link href="/sign-up">Create an account</Link>
        </p>
      </AuthPanel>
    </Layout>
  );
}
