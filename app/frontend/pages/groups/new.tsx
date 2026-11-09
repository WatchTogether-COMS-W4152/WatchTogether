import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function NewGroup() {
  const form = useForm({ name: "" });
  return (
    <Layout title="Create a group" narrow>
      <Link className="back-link" href="/groups">
        ← My groups
      </Link>
      <PageHeader
        eyebrow="Make it a group thing"
        title="Create a group"
        description="Give your crew a name. Invite your friends next."
      />
      <section className="card form-card">
        <form
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            form.post("/groups");
          }}
        >
          <FormError errors={form.errors} />
          <Field
            label="Group name"
            name="name"
            autoComplete="off"
            required
            maxLength={80}
            placeholder="Friday Night Film Club"
            value={form.data.name}
            onChange={(event) => form.setData("name", event.target.value)}
            error={form.errors.name}
          />
          <div className="info-note">
            <span aria-hidden="true">◇</span>
            <p>Your group is private. People can join only with your invitation code.</p>
          </div>
          <div className="form-actions">
            <Link className="button button-secondary" href="/groups">
              Cancel
            </Link>
            <button className="button button-primary" type="submit" disabled={form.processing}>
              {form.processing ? "Creating…" : "Create group"}
            </button>
          </div>
        </form>
      </section>
    </Layout>
  );
}
