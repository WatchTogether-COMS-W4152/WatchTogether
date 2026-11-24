import { useForm } from "@inertiajs/react";
import { useState } from "react";

import type { CatalogTitle } from "../types/catalog";
import MediaKind from "./media-kind";
import TitleSearch from "./title-search";

export default function AddTitleForm({
  groupId,
  action,
  submitLabel,
  onClose,
}: {
  groupId: number;
  action: string;
  submitLabel: string;
  onClose?: () => void;
}) {
  const form = useForm({ title: "", manual_media_type: "" });
  const [selected, setSelected] = useState<CatalogTitle | null>(null);

  return (
    <form
      className="card form read-width"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        form.transform((data) =>
          selected
            ? { title: data.title, tmdb_id: selected.tmdb_id, media_type: selected.media_type }
            : data,
        );
        form.post(action, {
          preserveScroll: true,
          onSuccess: () => {
            form.reset();
            setSelected(null);
          },
        });
      }}
    >
      <TitleSearch
        groupId={groupId}
        value={form.data.title}
        selected={selected}
        disabled={form.processing}
        onChange={(title) => {
          form.setData("title", title);
          setSelected(null);
        }}
        onSelect={(title) => {
          form.setData("title", title.title);
          setSelected(title);
        }}
        error={form.errors.title}
      />
      {!selected && form.data.title.trim() && (
        <MediaKind
          value={form.data.manual_media_type}
          disabled={form.processing}
          onChange={(kind) => form.setData("manual_media_type", kind)}
        />
      )}
      <div className="row">
        <button className="btn btn-primary" type="submit" disabled={form.processing}>
          {form.processing ? "Adding…" : submitLabel}
        </button>
        {onClose && (
          <button
            className="btn btn-quiet"
            type="button"
            disabled={form.processing}
            onClick={onClose}
          >
            Done
          </button>
        )}
      </div>
    </form>
  );
}
