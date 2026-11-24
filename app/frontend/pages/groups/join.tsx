import { Link, useForm } from "@inertiajs/react";

import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";

export default function JoinGroup() {
  const form = useForm({ code: "" });
  return (
    <Layout title="Join a group" section="groups" narrow>
      <PageHeader title="Join a group" back={{ href: "/groups", label: "Groups" }} />
      <form
        className="card"
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
        />
        <div className="row">
          <button className="btn btn-primary" type="submit" disabled={form.processing}>
            {form.processing ? "Joining…" : "Join group"}
          </button>
          <Link className="btn btn-quiet" href="/groups">
            Cancel
          </Link>
        </div>
      </form>
    </Layout>
  );
}
