import { useForm, usePage } from "@inertiajs/react";

import Avatar from "../../components/avatar";
import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";
import { TmdbAttribution } from "../../components/media-details";

export default function Profile() {
  const { auth } = usePage().props;
  const form = useForm({ display_name: auth.user?.display_name ?? "" });
  return (
    <Layout title="My profile" section="profile" narrow>
      <PageHeader title="Profile" />
      <section className="card" aria-label="Your profile">
        <div className="profile-summary">
          <Avatar name={auth.user?.display_name ?? ""} size="lg" />
          <div>
            <h2>{auth.user?.display_name}</h2>
            <p className="meta">{auth.user?.email}</p>
          </div>
        </div>
        <form
          className="form"
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
          <div className="row">
            <button className="btn btn-primary" type="submit" disabled={form.processing}>
              {form.processing ? "Saving…" : "Save changes"}
            </button>
          </div>
        </form>
      </section>
      <TmdbAttribution />
    </Layout>
  );
}
