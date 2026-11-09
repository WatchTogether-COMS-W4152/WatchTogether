import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function JoinGroup() {
  const form = useForm({ code: "" });
  return (
    <Layout title="Join a group" narrow>
      <Link className="back-link" href="/groups">
        ← My groups
      </Link>
      <PageHeader
        eyebrow="Your seat is waiting"
        title="Join a group"
        description="Have an invitation? You're one step away."
      />
      <section className="card form-card">
        <form
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            form.post("/groups/join");
          }}
        >
          <FormError errors={form.errors} />
          <Field
            className="code-input"
            label="Invitation code"
            name="code"
            autoComplete="off"
            autoCapitalize="characters"
            spellCheck={false}
            required
            value={form.data.code}
            onChange={(event) => form.setData("code", event.target.value)}
            error={form.errors.code}
            hint="Ask the group owner for a code, then paste it here."
          />
          <div className="form-actions">
            <Link className="button button-secondary" href="/groups">
              Cancel
            </Link>
            <button className="button button-primary" type="submit" disabled={form.processing}>
              {form.processing ? "Joining…" : "Join group"}
            </button>
          </div>
        </form>
      </section>
    </Layout>
  );
}
