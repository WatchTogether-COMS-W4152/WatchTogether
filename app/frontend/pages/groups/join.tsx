import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function JoinGroup() {
  const form = useForm({ code: "" });
  return (
    <Layout title="Join a group" narrow>
      <Link className="back-link" href="/groups">
        ← Groups
      </Link>
      <PageHeader
        title="Join a group"
        description="Enter the invitation code someone shared with you."
      />
      <section>
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
            hint="Group owners can find this on the group page."
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
