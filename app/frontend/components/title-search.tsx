import { useEffect, useId, useRef, useState } from "react";

import type { CatalogTitle } from "../types/catalog";
import { MediaMeta, SmallPoster } from "./media-details";

type SearchResponse = { results: CatalogTitle[] };
type DetailResponse = { title: CatalogTitle };

export default function TitleSearch({
  groupId,
  value,
  selected,
  error,
  disabled,
  onChange,
  onSelect,
}: {
  groupId: number;
  value: string;
  selected: CatalogTitle | null;
  error?: string[];
  disabled?: boolean;
  onChange: (value: string) => void;
  onSelect: (title: CatalogTitle) => void;
}) {
  const id = useId();
  const listId = `${id}-results`;
  const [search, setSearch] = useState<{
    query: string;
    groupId: number;
    results: CatalogTitle[];
    status: "ready" | "error";
  } | null>(null);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState(false);
  const detailRequest = useRef<AbortController | null>(null);
  const input = useRef<HTMLInputElement | null>(null);
  const resultList = useRef<HTMLDivElement | null>(null);
  const selectionVersion = useRef(0);
  const searchVersion = useRef(0);
  const trimmedValue = value.trim();
  const selectedId = selected?.tmdb_id;
  const currentSearch =
    search?.query === trimmedValue && search.groupId === groupId ? search : null;
  const results = currentSearch?.results ?? [];
  const status = currentSearch?.status ?? "loading";

  useEffect(() => {
    const version = ++searchVersion.current;
    const query = value.trim();
    if (query.length < 2 || selectedId) {
      return undefined;
    }
    const controller = new AbortController();
    const timer = window.setTimeout(async () => {
      try {
        const response = await fetch(
          `/groups/${groupId}/catalog/search?q=${encodeURIComponent(query)}`,
          {
            headers: { Accept: "application/json" },
            signal: controller.signal,
          },
        );
        if (!response.ok) throw new Error("Search unavailable");
        const data: SearchResponse = await response.json();
        if (controller.signal.aborted || version !== searchVersion.current) return;
        setSearch({ query, groupId, results: data.results, status: "ready" });
      } catch {
        if (!controller.signal.aborted && version === searchVersion.current)
          setSearch({ query, groupId, results: [], status: "error" });
      }
    }, 300);
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [groupId, value, selectedId]);

  useEffect(() => () => detailRequest.current?.abort(), []);

  useEffect(() => {
    if (!selectedId) {
      ++selectionVersion.current;
      detailRequest.current?.abort();
    }
  }, [selectedId]);

  useEffect(() => {
    resultList.current?.children[active]?.scrollIntoView?.({ block: "nearest" });
  }, [active]);

  async function selectTitle(title: CatalogTitle) {
    ++searchVersion.current;
    const version = ++selectionVersion.current;
    detailRequest.current?.abort();
    const controller = new AbortController();
    detailRequest.current = controller;
    setOpen(false);
    setActive(-1);
    setDetailsLoading(true);
    setDetailsError(false);
    onSelect(title);
    input.current?.focus();
    try {
      const response = await fetch(
        `/groups/${groupId}/catalog/${title.media_type}/${title.tmdb_id}`,
        {
          headers: { Accept: "application/json" },
          signal: controller.signal,
        },
      );
      if (!response.ok) throw new Error("Details unavailable");
      const data: DetailResponse = await response.json();
      if (!controller.signal.aborted && selectionVersion.current === version) onSelect(data.title);
    } catch {
      if (!controller.signal.aborted && selectionVersion.current === version) setDetailsError(true);
    } finally {
      if (!controller.signal.aborted && selectionVersion.current === version)
        setDetailsLoading(false);
    }
  }

  const expanded = open && !selected && trimmedValue.length >= 2;
  return (
    <div
      className="title-search"
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) setOpen(false);
      }}
    >
      <div className="field">
        <label htmlFor={id}>Title</label>
        <div className="combo">
          <input
            id={id}
            ref={input}
            name="title"
            role="combobox"
            aria-autocomplete="list"
            aria-expanded={expanded}
            aria-controls={expanded ? listId : undefined}
            aria-activedescendant={expanded && active >= 0 ? `${id}-option-${active}` : undefined}
            aria-invalid={Boolean(error?.length)}
            aria-describedby={error?.length ? `${id}-error` : undefined}
            autoComplete="off"
            required
            maxLength={120}
            disabled={disabled}
            placeholder="Search movies and TV shows"
            value={value}
            onFocus={() => setOpen(true)}
            onChange={(event) => {
              ++searchVersion.current;
              ++selectionVersion.current;
              detailRequest.current?.abort();
              setDetailsLoading(false);
              setDetailsError(false);
              setSearch(null);
              setActive(-1);
              setOpen(true);
              onChange(event.target.value);
            }}
            onKeyDown={(event) => {
              if (event.nativeEvent.isComposing) return;
              if (event.key === "Escape") {
                event.preventDefault();
                setOpen(false);
                setActive(-1);
              } else if ((event.key === "ArrowDown" || event.key === "ArrowUp") && results.length) {
                event.preventDefault();
                setOpen(true);
                setActive((current) =>
                  event.key === "ArrowDown"
                    ? (current + 1) % results.length
                    : current <= 0
                      ? results.length - 1
                      : current - 1,
                );
              } else if (event.key === "Enter" && expanded && active >= 0) {
                event.preventDefault();
                void selectTitle(results[active]);
              }
            }}
          />
          {expanded && (
            <div className="popover">
              <div
                id={listId}
                // oxlint-disable-next-line jsx-a11y/prefer-tag-over-role -- Rich posters and descriptions cannot be rendered in a native datalist.
                role="listbox"
                aria-label="Movies and TV shows"
                className="options"
                ref={resultList}
              >
                {results.map((title, index) => (
                  <div
                    id={`${id}-option-${index}`}
                    key={`${title.media_type}-${title.tmdb_id}`}
                    // oxlint-disable-next-line jsx-a11y/prefer-tag-over-role -- Rich combobox options are navigated from the text input.
                    role="option"
                    tabIndex={-1}
                    aria-selected={active === index}
                    className="option"
                    onMouseDown={(event) => event.preventDefault()}
                    onMouseMove={() => setActive(index)}
                    onClick={() => void selectTitle(title)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") {
                        event.preventDefault();
                        void selectTitle(title);
                      }
                    }}
                  >
                    <SmallPoster poster_url={title.poster_url} />
                    <div className="option-text">
                      <strong>{title.title}</strong>
                      <MediaMeta media={title} />
                    </div>
                  </div>
                ))}
              </div>
              <output className="popover-status">
                {status === "loading"
                  ? "Searching TMDB…"
                  : status === "error"
                    ? "Search is unavailable. Try again, or add the title manually."
                    : status === "ready" && !results.length
                      ? "No matches found. Try another title, or add it manually."
                      : `${results.length} results. Use ↑ and ↓ to browse, Enter to select.`}
              </output>
            </div>
          )}
        </div>
        {error?.length ? (
          <p className="field-error" role="alert" id={`${id}-error`}>
            {error.join(". ")}
          </p>
        ) : null}
      </div>
      {selected && (
        <div className="well selected-title" aria-label="Selected title">
          <SmallPoster poster_url={selected.poster_url} />
          <div className="option-text">
            <strong>{selected.title}</strong>
            <MediaMeta media={selected} withAgeRating />
            {selected.overview && <p className="meta">{selected.overview}</p>}
            {detailsLoading && <output className="field-hint">Loading age rating…</output>}
            {detailsError && <output className="field-hint">Age rating unavailable.</output>}
          </div>
        </div>
      )}
    </div>
  );
}
