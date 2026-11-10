import { router } from "@inertiajs/react";
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";
import { beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import Group from "../pages/groups/show";
import Watchlist from "../pages/watchlist_items/index";
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
  const element = screen.getByText(title, { exact: true }).closest("li");
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
    expect(screen.getByRole("heading", { name: "Our Watchlist", level: 1 })).toBeVisible();
    expect(screen.getByText("Your watchlist is empty. Add your first movie!")).toBeVisible();
    expect(screen.queryByRole("list")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Title")).toBeRequired();
    expect(screen.getByLabelText("Title")).toHaveAttribute("maxlength", "120");
    expect(screen.getByRole("button", { name: "Add to Watchlist" })).toBeEnabled();
  });

  it("shows each title's watched state and the appropriate action", () => {
    renderPage();
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
    expect(row("Paddington").getByText(/Not watched/)).toBeVisible();
    expect(row("Paddington").getByRole("button", { name: "Mark as Watched" })).toBeEnabled();
    expect(row("Up").getByText(/Watched ✓/)).toBeVisible();
    expect(row("Up").getByRole("button", { name: "Mark as Unwatched" })).toBeEnabled();
    expect(row("Paddington").getByRole("button", { name: "Remove" })).toBeEnabled();
    expect(row("Up").getByRole("button", { name: "Remove" })).toBeEnabled();
  });

  it("links back to the current group", () => {
    renderPage();
    expect(screen.getByRole("link", { name: "← Friday Film Club" })).toHaveAttribute(
      "href",
      "/groups/7",
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
    expect(screen.getByRole("link", { name: "Our Watchlist" })).toHaveAttribute(
      "href",
      "/groups/7/watchlist_items",
    );
  });
});

describe("adding a watchlist title", () => {
  it("submits to this group, prevents another pending submission, and clears the title on success", async () => {
    const user = userEvent.setup();
    renderPage([]);
    await user.type(screen.getByLabelText("Title"), "Spirited Away");
    await user.click(screen.getByRole("button", { name: "Add to Watchlist" }));

    const [url, data, options] = postRequest.mock.calls[0];
    expect(url).toBe("/groups/7/watchlist_items");
    expect(data).toEqual({ title: "Spirited Away" });
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
    expect(screen.getByRole("button", { name: "Add to Watchlist" })).toBeEnabled();
  });

  it("shows server validation, retains the rejected value, and allows a corrected retry", async () => {
    const user = userEvent.setup();
    renderPage([]);
    await user.type(screen.getByLabelText("Title"), "   ");
    await user.click(screen.getByRole("button", { name: "Add to Watchlist" }));
    const options = postRequest.mock.calls[0][2];
    act(() => {
      options?.onStart?.(visit);
      options?.onError?.({ title: ["can't be blank"] });
      options?.onFinish?.(visit);
    });
    expect(screen.getByRole("alert")).toHaveTextContent("can't be blank");
    expect(screen.getByLabelText("Title")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByLabelText("Title")).toHaveValue("   ");
    expect(screen.getByRole("button", { name: "Add to Watchlist" })).toBeEnabled();

    await user.clear(screen.getByLabelText("Title"));
    await user.type(screen.getByLabelText("Title"), "Arrival");
    await user.click(screen.getByRole("button", { name: "Add to Watchlist" }));
    expect(postRequest).toHaveBeenCalledTimes(2);
    expect(postRequest.mock.calls[1][1]).toEqual({ title: "Arrival" });
    const retryOptions = postRequest.mock.calls[1][2];
    act(() => {
      retryOptions?.onSuccess?.(nextPage);
      retryOptions?.onFinish?.(visit);
    });
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Title")).toHaveValue("");
  });
});

describe("watching a title", () => {
  it.each([
    { title: "Paddington", id: 11, action: "Mark as Watched", nextWatched: true },
    { title: "Up", id: 12, action: "Mark as Unwatched", nextWatched: false },
  ])("sends $action only for the selected title", async ({ title, id, action, nextWatched }) => {
    const user = userEvent.setup();
    const { rerender } = renderPage();
    await user.click(row(title).getByRole("button", { name: action }));
    expect(patchRequest).toHaveBeenCalledTimes(1);
    expect(patchRequest).toHaveBeenCalledWith(
      `/groups/7/watchlist_items/${id}`,
      {},
      { preserveScroll: true },
    );
    expect(deleteRequest).not.toHaveBeenCalled();

    rerender(
      <Watchlist
        group={group}
        watchlist_items={items.map((item) =>
          item.id === id ? { ...item, watched: nextWatched } : item,
        )}
      />,
    );
    expect(
      row(title).getByRole("button", {
        name: nextWatched ? "Mark as Unwatched" : "Mark as Watched",
      }),
    ).toBeEnabled();
  });

  it("shows a failed-request message without losing the title and lets the member retry", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(row("Paddington").getByRole("button", { name: "Mark as Watched" }));
    fireEvent(
      document,
      new CustomEvent("inertia:networkError", {
        cancelable: true,
        detail: { error: new Error("Offline") },
      }),
    );
    expect(screen.getByRole("alert")).toHaveTextContent("Check your connection and try again");
    expect(row("Paddington").getByText(/Not watched/)).toBeVisible();
    await user.click(row("Paddington").getByRole("button", { name: "Mark as Watched" }));
    expect(patchRequest).toHaveBeenCalledTimes(2);
  });
});

describe("removing a watchlist title", () => {
  it("names the selected title and cancels without a request", async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderPage();
    await user.click(row("Up").getByRole("button", { name: "Remove" }));
    expect(confirm).toHaveBeenCalledWith('Remove "Up" from the watchlist?');
    expect(deleteRequest).not.toHaveBeenCalled();
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
  });

  it("removes only the confirmed title from the current group", async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(true);
    renderPage();
    await user.click(row("Up").getByRole("button", { name: "Remove" }));
    expect(confirm).toHaveBeenCalledWith('Remove "Up" from the watchlist?');
    expect(deleteRequest).toHaveBeenCalledExactlyOnceWith("/groups/7/watchlist_items/12", {
      preserveScroll: true,
    });
    expect(patchRequest).not.toHaveBeenCalled();
  });
});
