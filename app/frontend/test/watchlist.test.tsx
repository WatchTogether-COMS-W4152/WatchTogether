import { router } from "@inertiajs/react";
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";
import { beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import Group from "../pages/groups/members";
import Watchlist from "../pages/watchlist_items/index";
import WatchlistItemPage from "../pages/watchlist_items/show";
import type { SharedProps } from "../types";

const page = vi.hoisted(() => ({
  props: { auth: { user: null }, flash: {} } as SharedProps,
}));

// Keep real form state and event handlers; replace only Inertia's page context,
// document head, links, and request transport.
vi.mock("@inertiajs/react", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@inertiajs/react")>()),
  usePage: () => page,
  Head: () => null,
  Link: ({ children, ...props }: ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

type PostOptions = NonNullable<Parameters<typeof router.post>[2]>;
type Visit = Parameters<NonNullable<PostOptions["onFinish"]>>[0];
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- Form callbacks do not inspect visit metadata; the request transport is stubbed.
const visit = {} as Visit;
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- onSuccess receives the next page, which this form ignores.
const nextPage = {} as Parameters<NonNullable<PostOptions["onSuccess"]>>[0];
let postRequest: MockInstance<typeof router.post>;
let patchRequest: MockInstance<typeof router.patch>;
let deleteRequest: MockInstance<typeof router.delete>;

const group = { id: 7, name: "Friday Film Club" };
const items = [
  { id: 11, title: "Paddington", watched: false },
  { id: 12, title: "Up", watched: true },
];

function renderPage(watchlistItems = items) {
  return render(<Watchlist group={group} watchlist_items={watchlistItems} />);
}

function row(title: string) {
  const element = screen.getByRole("heading", { name: title }).closest("li");
  if (!element) throw new Error(`No watchlist row for ${title}`);
  return within(element);
}

beforeEach(() => {
  vi.restoreAllMocks();
  page.props = {
    auth: { user: { id: 2, display_name: "Bob", email: "bob@example.com" } },
    flash: {},
  };
  postRequest = vi.spyOn(router, "post").mockImplementation(() => {});
  patchRequest = vi.spyOn(router, "patch").mockImplementation(() => {});
  deleteRequest = vi.spyOn(router, "delete").mockImplementation(() => {});
});

describe("viewing the watchlist", () => {
  it("explains an empty watchlist and offers an accessible title field", () => {
    renderPage([]);
    expect(screen.getByRole("heading", { name: "Friday Film Club", level: 1 })).toBeVisible();
    expect(screen.getByText("Nothing on the watchlist yet.")).toBeVisible();
    expect(screen.queryByRole("list")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Title")).toBeRequired();
    expect(screen.getByLabelText("Title")).toHaveAttribute("maxlength", "120");
    expect(screen.getByRole("button", { name: "Add to watchlist" })).toBeEnabled();
  });

  it("keeps the add form closed until asked once the list has titles", async () => {
    const user = userEvent.setup();
    renderPage();
    expect(screen.queryByLabelText("Title")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Add a title" }));
    expect(screen.getByLabelText("Title")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Done" }));
    expect(screen.queryByLabelText("Title")).not.toBeInTheDocument();
  });

  it("shows each title as a poster card linking to its page, marking watched titles", () => {
    renderPage();
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
    expect(screen.getByRole("link", { name: /Paddington/ })).toHaveAttribute(
      "href",
      "/groups/7/watchlist/11",
    );
    expect(row("Up").getByText("Watched")).toHaveClass("chip");
    expect(row("Paddington").queryByText("Watched")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Mark as/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Remove" })).not.toBeInTheDocument();
  });

  it("shows the group's tabs with this page selected", () => {
    renderPage();
    const tabs = screen.getByRole("navigation", { name: "Friday Film Club" });
    expect(within(tabs).getByRole("link", { name: "Watchlist" })).toHaveAttribute(
      "href",
      "/groups/7/watchlist",
    );
    expect(within(tabs).getByRole("link", { name: "Picks" })).toHaveAttribute(
      "href",
      "/groups/7/picks",
    );
    expect(within(tabs).getByRole("link", { name: "Members" })).toHaveAttribute(
      "href",
      "/groups/7/members",
    );
    expect(within(tabs).getByRole("link", { current: "page" })).toHaveAttribute(
      "href",
      "/groups/7/watchlist",
    );
  });

  it("lets an ordinary member open the watchlist from the group page", () => {
    render(
      <Group
        group={{
          ...group,
          is_owner: false,
          members: [{ id: 2, display_name: "Bob", role: "member" }],
        }}
      />,
    );
    expect(screen.getByRole("link", { name: "Watchlist" })).toHaveAttribute(
      "href",
      "/groups/7/watchlist",
    );
  });
});

describe("adding a watchlist title", () => {
  it("submits to this group, prevents another pending submission, and clears the title on success", async () => {
    const user = userEvent.setup();
    renderPage([]);
    await user.type(screen.getByLabelText("Title"), "Spirited Away");
    await user.click(screen.getByRole("button", { name: "Movie" }));
    expect(screen.getByRole("button", { name: "Movie" })).toHaveAttribute("aria-pressed", "true");
    await user.click(screen.getByRole("button", { name: "Add to watchlist" }));

    const [url, data, options] = postRequest.mock.calls[0];
    expect(url).toBe("/groups/7/watchlist");
    expect(data).toEqual({ title: "Spirited Away", manual_media_type: "movie" });
    expect(options?.preserveScroll).toBe(true);
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Adding…" })).toBeDisabled();
    await user.click(screen.getByRole("button", { name: "Adding…" }));
    expect(postRequest).toHaveBeenCalledTimes(1);

    act(() => {
      options?.onSuccess?.(nextPage);
      options?.onFinish?.(visit);
    });
    expect(screen.getByLabelText("Title")).toHaveValue("");
    expect(screen.getByRole("button", { name: "Add to watchlist" })).toBeEnabled();
  });

  it("shows server validation, retains the rejected value, and allows a corrected retry", async () => {
    const user = userEvent.setup();
    renderPage([]);
    await user.type(screen.getByLabelText("Title"), "   ");
    await user.click(screen.getByRole("button", { name: "Add to watchlist" }));
    const options = postRequest.mock.calls[0][2];
    act(() => {
      options?.onStart?.(visit);
      options?.onError?.({ title: ["can't be blank"] });
      options?.onFinish?.(visit);
    });
    expect(screen.getByRole("alert")).toHaveTextContent("can't be blank");
    expect(screen.getByLabelText("Title")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByLabelText("Title")).toHaveValue("   ");
    expect(screen.getByRole("button", { name: "Add to watchlist" })).toBeEnabled();

    await user.clear(screen.getByLabelText("Title"));
    await user.type(screen.getByLabelText("Title"), "Arrival");
    await user.click(screen.getByRole("button", { name: "Add to watchlist" }));
    expect(postRequest).toHaveBeenCalledTimes(2);
    expect(postRequest.mock.calls[1][1]).toEqual({ title: "Arrival", manual_media_type: "" });
    const retryOptions = postRequest.mock.calls[1][2];
    act(() => {
      retryOptions?.onSuccess?.(nextPage);
      retryOptions?.onFinish?.(visit);
    });
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Title")).toHaveValue("");
  });
});

function renderTitle(item: { id: number; title: string; watched: boolean }) {
  return render(<WatchlistItemPage group={group} item={{ ...item, episodic: false }} />);
}

describe("watching a title", () => {
  it.each([
    { item: items[0], action: "Mark as watched", nextWatched: true },
    { item: items[1], action: "Mark as unwatched", nextWatched: false },
  ])("sends $action only for this title", async ({ item, action, nextWatched }) => {
    const user = userEvent.setup();
    const { rerender } = renderTitle(item);
    await user.click(screen.getByRole("button", { name: action }));
    expect(patchRequest).toHaveBeenCalledTimes(1);
    expect(patchRequest.mock.calls[0][0]).toBe(`/groups/7/watchlist/${item.id}`);
    expect(patchRequest.mock.calls[0][1]).toEqual({ watched: nextWatched });
    expect(deleteRequest).not.toHaveBeenCalled();

    rerender(
      <WatchlistItemPage group={group} item={{ ...item, watched: nextWatched, episodic: false }} />,
    );
    expect(
      screen.getByRole("button", {
        name: nextWatched ? "Mark as unwatched" : "Mark as watched",
      }),
    ).toBeEnabled();
  });

  it("shows a failed-request message and lets the member retry", async () => {
    const user = userEvent.setup();
    renderTitle(items[0]);
    await user.click(screen.getByRole("button", { name: "Mark as watched" }));
    fireEvent(
      document,
      new CustomEvent("inertia:networkError", {
        cancelable: true,
        detail: { error: new Error("Offline") },
      }),
    );
    expect(screen.getByRole("alert")).toHaveTextContent("Couldn't connect. Try again.");
    await user.click(screen.getByRole("button", { name: "Close" }));
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Mark as watched" }));
    expect(patchRequest).toHaveBeenCalledTimes(2);
  });
});

describe("removing a watchlist title", () => {
  it("asks inline, focuses Cancel, and cancels without a request", async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, "confirm");
    renderTitle(items[1]);
    await user.click(screen.getByRole("button", { name: "Remove" }));
    expect(screen.getByText("Remove “Up” from the watchlist?")).toBeVisible();
    expect(screen.getByRole("button", { name: "Cancel" })).toHaveFocus();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.getByRole("button", { name: "Remove" })).toHaveFocus();
    expect(deleteRequest).not.toHaveBeenCalled();
    expect(confirm).not.toHaveBeenCalled();
  });

  it("removes only the confirmed title from the current group", async () => {
    const user = userEvent.setup();
    renderTitle(items[1]);
    await user.click(screen.getByRole("button", { name: "Remove" }));
    await user.click(screen.getByRole("button", { name: "Yes, remove" }));
    expect(deleteRequest).toHaveBeenCalledTimes(1);
    const [url, options] = deleteRequest.mock.calls[0];
    expect(url).toBe("/groups/7/watchlist/12");
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Removing…" })).toBeDisabled();
    expect(patchRequest).not.toHaveBeenCalled();
  });
});
