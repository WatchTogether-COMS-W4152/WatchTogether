import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function NewGroup() {
  const form = useForm({ name: "" });
  return (
    <Layout title="Create a group" section="groups" narrow>
      <PageHeader title="New group" back={{ href: "/groups", label: "Groups" }} />
      <form
        className="card"
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
        <div className="row">
          <button className="btn btn-primary" type="submit" disabled={form.processing}>
            {form.processing ? "Creating…" : "Create group"}
          </button>
          <Link className="btn btn-quiet" href="/groups">
            Cancel
          </Link>
        </div>
      </form>
    </Layout>
  );
}
