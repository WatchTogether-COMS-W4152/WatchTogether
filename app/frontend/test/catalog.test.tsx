import { router } from "@inertiajs/react";
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import { useState, type ComponentProps } from "react";
import { afterEach, beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import TitleSearch from "../components/title-search";
import Suggestions from "../pages/suggestions/index";
import Watchlist from "../pages/watchlist_items/index";
import type { SharedProps } from "../types";
import type { CatalogTitle } from "../types/catalog";
import type { Suggestion } from "../types/voting";

const page = vi.hoisted(() => ({
  props: { auth: { user: null }, flash: {} } as SharedProps,
}));
vi.mock("@inertiajs/react", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@inertiajs/react")>()),
  usePage: () => page,
  Head: () => null,
  Link: ({ children, ...props }: ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

const dune: CatalogTitle = {
  title: "Dune",
  tmdb_id: 438631,
  media_type: "movie",
  release_year: 2021,
  tmdb_rating: 7.8,
  age_rating: null,
  poster_url: "https://image.tmdb.org/t/p/w500/dune.jpg",
  overview: "A young man must travel to a dangerous planet to protect his family.",
};
const tv: CatalogTitle = {
  title: "Dune: Prophecy",
  tmdb_id: 90228,
  media_type: "tv",
  release_year: 2024,
  tmdb_rating: 7.4,
  age_rating: null,
  poster_url: null,
  overview: "Two sisters shape the future of humanity.",
};
const group = { id: 7, name: "Friday Film Club", is_owner: false };
const suggestion: Suggestion = {
  ...dune,
  age_rating: "PG-13",
  id: 11,
  score: 3,
  votes_count: 2,
  my_rating: "love",
  suggested_by: "Alice",
  can_remove: false,
  in_watchlist: false,
};
const fetchMock = vi.fn<typeof fetch>();
let postRequest: MockInstance<typeof router.post>;

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function Harness() {
  const [value, setValue] = useState("");
  const [selected, setSelected] = useState<CatalogTitle | null>(null);
  return (
    <TitleSearch
      groupId={7}
      value={value}
      selected={selected}
      onChange={(text) => {
        setValue(text);
        setSelected(null);
      }}
      onSelect={(title) => {
        setValue(title.title);
        setSelected(title);
      }}
    />
  );
}

async function typeQuery(value: string) {
  fireEvent.focus(screen.getByRole("combobox"));
  fireEvent.change(screen.getByRole("combobox"), { target: { value } });
  await act(async () => {
    await vi.advanceTimersByTimeAsync(300);
  });
}

beforeEach(() => {
  vi.useFakeTimers();
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
  postRequest = vi.spyOn(router, "post").mockImplementation(() => {});
  fetchMock.mockResolvedValue(response({ results: [dune, tv] }));
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("TMDB title search", () => {
  it("debounces current input and shows poster, year, type, and score", async () => {
    render(<Harness />);
    fireEvent.focus(screen.getByRole("combobox"));
    fireEvent.change(screen.getByRole("combobox"), { target: { value: "Du" } });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(200);
    });
    expect(fetchMock).not.toHaveBeenCalled();
    fireEvent.change(screen.getByRole("combobox"), { target: { value: "Dune" } });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock.mock.calls[0][0]).toBe("/groups/7/catalog/search?q=Dune");
    expect(screen.getAllByRole("option")).toHaveLength(2);
    expect(screen.getAllByRole("option")[0].querySelector("img")).toHaveAttribute(
      "src",
      dune.poster_url,
    );
    expect(screen.getByText("2021")).toBeVisible();
    expect(screen.getByText("TV show")).toBeVisible();
    expect(screen.getByText("TMDB 7.8")).toBeVisible();
  });

  it("ignores stale searches even if the old transport finishes after the new result", async () => {
    let finishOld: ((value: Response) => void) | undefined;
    fetchMock.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finishOld = resolve;
        }),
    );
    fetchMock.mockResolvedValueOnce(response({ results: [tv] }));
    render(<Harness />);
    await typeQuery("Dune");
    const oldSignal = fetchMock.mock.calls[0][1]?.signal;
    await typeQuery("Prophecy");
    expect(oldSignal?.aborted).toBe(true);
    await act(async () => {
      finishOld?.(response({ results: [dune] }));
    });
    expect(screen.getAllByRole("option")).toHaveLength(1);
    expect(screen.getByRole("option")).toHaveTextContent("Dune: Prophecy");
  });

  it("finishes searching after whitespace edits that keep the same trimmed query", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(response({ results: [dune] })));
    render(<Harness />);
    await typeQuery("Dune");
    expect(screen.getByRole("option")).toHaveTextContent("Dune");
    await typeQuery("Dune ");
    expect(screen.getByRole("option")).toHaveTextContent("Dune");
    expect(screen.getByRole("status")).toHaveTextContent("1 results");
    expect(fetchMock.mock.calls[1][0]).toBe("/groups/7/catalog/search?q=Dune");
  });

  it("selects with keyboard without submitting, loads age certification, and closes with Escape", async () => {
    fetchMock.mockResolvedValueOnce(response({ results: [dune, tv] }));
    fetchMock.mockResolvedValueOnce(response({ title: { ...tv, age_rating: "TV-MA" } }));
    const submit = vi.fn((event: React.SubmitEvent<HTMLFormElement>) => event.preventDefault());
    render(
      <form onSubmit={submit}>
        <Harness />
        <button type="submit">Add</button>
      </form>,
    );
    await typeQuery("Dune");
    const input = screen.getByRole("combobox");
    fireEvent.keyDown(input, { key: "ArrowDown" });
    expect(input).toHaveAttribute("aria-activedescendant", screen.getAllByRole("option")[0].id);
    fireEvent.keyDown(input, { key: "Escape" });
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    fireEvent.keyDown(input, { key: "ArrowUp" });
    await act(async () => {
      fireEvent.keyDown(input, { key: "Enter" });
    });
    expect(input).toHaveValue("Dune: Prophecy");
    expect(screen.getByText("TV-MA (US)")).toBeVisible();
    expect(fetchMock.mock.calls[1][0]).toBe("/groups/7/catalog/tv/90228");
    expect(submit).not.toHaveBeenCalled();
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
  });

  it("does not overwrite newer input with a delayed selection's details", async () => {
    let finishDetails: ((value: Response) => void) | undefined;
    fetchMock.mockResolvedValueOnce(response({ results: [dune] }));
    fetchMock.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finishDetails = resolve;
        }),
    );
    render(<Harness />);
    await typeQuery("Dune");
    fireEvent.click(screen.getByRole("option"));
    fireEvent.change(screen.getByRole("combobox"), { target: { value: "Arrival" } });
    await act(async () => {
      finishDetails?.(response({ title: { ...dune, age_rating: "PG-13" } }));
    });
    expect(screen.getByRole("combobox")).toHaveValue("Arrival");
    expect(screen.queryByLabelText("Selected title")).not.toBeInTheDocument();
  });

  it("shows no results and unavailable states while retaining manual entry", async () => {
    fetchMock.mockResolvedValueOnce(response({ results: [] }));
    fetchMock.mockResolvedValueOnce(response({ error: "Unavailable" }, 503));
    render(<Harness />);
    await typeQuery("unmatched");
    expect(screen.getByRole("status")).toHaveTextContent("No matches found");
    await typeQuery("another title");
    expect(screen.getByRole("status")).toHaveTextContent("Search is unavailable");
    expect(screen.getByRole("combobox")).toHaveValue("another title");
  });

  it("does not search one character or blank input and closes when focus leaves", async () => {
    render(
      <>
        <Harness />
        <button>Elsewhere</button>
      </>,
    );
    await typeQuery("D");
    expect(fetchMock).not.toHaveBeenCalled();
    await typeQuery("  ");
    expect(fetchMock).not.toHaveBeenCalled();
    await typeQuery("Dune");
    fireEvent.blur(screen.getByRole("combobox"), { relatedTarget: screen.getByRole("button") });
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
  });
});

describe("catalog titles in voting and watchlist", () => {
  it.each(["voting", "watchlist"])(
    "submits selected TMDB identity in %s, then clears it when edited",
    async (area) => {
      fetchMock.mockResolvedValueOnce(response({ results: [dune] }));
      fetchMock.mockResolvedValueOnce(response({ title: { ...dune, age_rating: "PG-13" } }));
      if (area === "voting")
        render(<Suggestions group={group} member_count={2} suggestions={[]} />);
      else render(<Watchlist group={group} watchlist_items={[]} />);
      await typeQuery("Dune");
      await act(async () => {
        fireEvent.click(screen.getByRole("option"));
      });
      fireEvent.click(
        screen.getByRole("button", {
          name: area === "voting" ? "Add suggestion" : "Add to watchlist",
        }),
      );
      expect(postRequest).toHaveBeenLastCalledWith(
        `/groups/7/${area === "voting" ? "suggestions" : "watchlist_items"}`,
        { title: "Dune", tmdb_id: 438631, media_type: "movie" },
        expect.objectContaining({ preserveScroll: true }),
      );
      fireEvent.change(screen.getByRole("combobox"), { target: { value: "My custom title" } });
      fireEvent.click(
        screen.getByRole("button", {
          name: area === "voting" ? "Add suggestion" : "Add to watchlist",
        }),
      );
      expect(postRequest.mock.calls[1][1]).toEqual({ title: "My custom title" });
    },
  );

  it("renders TMDB metadata and keeps group score separate from TMDB rating", () => {
    render(<Suggestions group={group} member_count={2} suggestions={[suggestion]} />);
    expect(screen.getByText("TMDB 7.8")).toBeVisible();
    expect(screen.getByText("+3")).toHaveTextContent("Score +3");
    expect(screen.getByText(/not endorsed or certified by TMDB/)).toBeVisible();
  });

  it("adds a suggestion to the watchlist and shows pending and already-added states", () => {
    const { rerender } = render(
      <Suggestions group={group} member_count={2} suggestions={[suggestion]} />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Add Dune to watchlist" }));
    const [url, data, options] = postRequest.mock.calls[0];
    expect(url).toBe("/groups/7/suggestions/11/watchlist");
    expect(data).toEqual({});
    // oxlint-disable-next-line typescript/no-unsafe-type-assertion -- Inertia callbacks do not inspect transport metadata.
    act(() => options?.onStart?.({} as Parameters<NonNullable<typeof options.onStart>>[0]));
    expect(screen.getByRole("button", { name: "Add Dune to watchlist" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Add Dune to watchlist" })).toHaveTextContent(
      "Adding…",
    );
    rerender(
      <Suggestions
        group={group}
        member_count={2}
        suggestions={[{ ...suggestion, in_watchlist: true }]}
      />,
    );
    expect(screen.queryByRole("button", { name: "Add Dune to watchlist" })).not.toBeInTheDocument();
    expect(screen.getByText("On watchlist")).toHaveClass("chip");
  });

  it("shows metadata and graceful missing-data/poster fallbacks in the watchlist", () => {
    render(
      <Watchlist
        group={group}
        watchlist_items={[
          { ...dune, age_rating: "PG-13", id: 11, watched: false },
          { ...tv, overview: null, release_year: null, tmdb_rating: null, id: 12, watched: true },
        ]}
      />,
    );
    const rows = screen.getAllByRole("listitem");
    expect(within(rows[0]).getByText("Movie")).toBeVisible();
    expect(within(rows[0]).getByText("2021")).toBeVisible();
    const poster = rows[0].querySelector("img");
    expect(poster).toHaveAttribute("src", dune.poster_url);
    fireEvent.error(poster!);
    expect(rows[0].querySelector("img")).toBeNull();
    expect(rows[0].querySelector(".poster-blank")).toHaveTextContent("Dune");
    expect(within(rows[1]).getByText("Year unavailable")).toBeVisible();
    expect(within(rows[1]).getByText("Not yet rated")).toBeVisible();
    expect(within(rows[1]).getByText("Watched")).toBeVisible();
    expect(screen.getByText(/not endorsed or certified by TMDB/)).toBeVisible();
  });
});
