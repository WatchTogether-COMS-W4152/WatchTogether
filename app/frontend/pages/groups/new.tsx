import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function NewGroup() {
  const form = useForm({ name: "" });
  return (
    <Layout title="Create a group" narrow>
      <Link className="back-link" href="/groups">
        ← Groups
      </Link>
      <PageHeader title="New group" description="You can invite people once it's created." />
      <section>
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
            hint="Groups are private. People join with an invitation code."
          />
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
