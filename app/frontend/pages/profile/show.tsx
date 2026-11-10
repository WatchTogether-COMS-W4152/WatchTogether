import { Link, useForm, usePage } from "@inertiajs/react";

import Avatar from "../../components/avatar";
import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function Profile() {
  const { auth } = usePage().props;
  const form = useForm({ display_name: auth.user?.display_name ?? "" });
  return (
    <Layout title="My profile" narrow>
      <Link className="back-link" href="/groups">
        ← Groups
      </Link>
      <PageHeader title="Profile" />
      <section className="panel">
        <div className="profile-summary">
          <Avatar name={auth.user?.display_name ?? ""} size="large" />
          <div>
            <h2>{auth.user?.display_name}</h2>
            <p className="muted">{auth.user?.email}</p>
          </div>
        </div>
        <form
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            form.patch("/profile", { preserveScroll: true });
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
          <p className="field-hint">Your email is never shown to other members.</p>
          <div className="form-actions">
            <button className="button button-primary" type="submit" disabled={form.processing}>
              {form.processing ? "Saving…" : "Save changes"}
            </button>
          </div>
        </form>
      </section>
    </Layout>
  );
}
