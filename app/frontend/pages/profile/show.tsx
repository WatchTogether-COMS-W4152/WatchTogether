import { useForm, usePage } from "@inertiajs/react";

import Avatar from "../../components/avatar";
import Field, { FormError } from "../../components/field";
import Layout, { PageHeader } from "../../components/layout";
import { TmdbAttribution } from "../../components/media-details";

export type StreamingServiceOption = {
  id: number;
  name: string;
};

export default function Profile({
  services = [],
  selected_service_ids: selectedServiceIds = [],
}: {
  services?: StreamingServiceOption[];
  selected_service_ids?: number[];
}) {
  const { auth } = usePage().props;
  const form = useForm({ display_name: auth.user?.display_name ?? "" });
  const servicesForm = useForm({
    streaming_services: true,
    provider_ids: selectedServiceIds,
  });

  function toggleService(id: number) {
    const selected = servicesForm.data.provider_ids;
    servicesForm.setData(
      "provider_ids",
      selected.includes(id) ? selected.filter((value) => value !== id) : [...selected, id],
    );
  }

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
      {services.length > 0 && (
        <section className="card" aria-labelledby="streaming-services-heading">
          <h2 id="streaming-services-heading">Streaming services you pay for</h2>
          <p className="meta">These apply to every group you belong to.</p>
          <form
            className="form"
            onSubmit={(event) => {
              event.preventDefault();
              servicesForm.patch("/profile", { preserveScroll: true });
            }}
          >
            <fieldset className="service-choices">
              <legend className="visually-hidden">Streaming services you pay for</legend>
              {services.map((service) => (
                <label key={service.id}>
                  <input
                    type="checkbox"
                    name="provider_ids"
                    value={service.id}
                    checked={servicesForm.data.provider_ids.includes(service.id)}
                    onChange={() => toggleService(service.id)}
                  />
                  {service.name}
                </label>
              ))}
            </fieldset>
            <div className="row">
              <button className="btn btn-primary" type="submit" disabled={servicesForm.processing}>
                {servicesForm.processing ? "Saving…" : "Save services"}
              </button>
            </div>
          </form>
        </section>
      )}
      <TmdbAttribution />
    </Layout>
  );
}
