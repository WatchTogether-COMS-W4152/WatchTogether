import { router } from "@inertiajs/react";
import { act, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";
import { beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import Group from "../pages/groups/show";
import Suggestions from "../pages/suggestions/index";
import type { SharedProps } from "../types";
import type { Suggestion, VotingGroup } from "../types/voting";

const page = vi.hoisted(() => ({
  props: { auth: { user: null }, flash: {} } as SharedProps,
}));

vi.mock("@inertiajs/react", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@inertiajs/react")>()),
  usePage: () => page,
  Head: () => null,
  Link: ({ children, ...props }: ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

type PostOptions = NonNullable<Parameters<typeof router.post>[2]>;
type Visit = Parameters<NonNullable<PostOptions["onFinish"]>>[0];
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- Inertia's callbacks do not inspect visit metadata; the request transport is stubbed.
const visit = {} as Visit;
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- onSuccess receives the next page, which these components ignore.
const nextPage = {} as Parameters<NonNullable<PostOptions["onSuccess"]>>[0];
let postRequest: MockInstance<typeof router.post>;
let putRequest: MockInstance<typeof router.put>;
let deleteRequest: MockInstance<typeof router.delete>;

const group: VotingGroup = { id: 7, name: "Friday Film Club", is_owner: false };
const suggestions: Suggestion[] = [
  {
    id: 11,
    title: "Paddington",
    score: 3,
    votes_count: 3,
    my_rating: "maybe",
    suggested_by: "Alice",
    can_remove: false,
  },
  {
    id: 12,
    title: "Up",
    score: 0,
    votes_count: 0,
    my_rating: null,
    suggested_by: "Bob",
    can_remove: true,
  },
  {
    id: 13,
    title: "Cats",
    score: -2,
    votes_count: 1,
    my_rating: "not_interested",
    suggested_by: null,
    can_remove: false,
  },
];

function renderPage(items: Suggestion[] = suggestions) {
  return render(<Suggestions group={group} member_count={3} suggestions={items} />);
}

function item(title: string) {
  const heading = screen.getByRole("heading", { name: title });
  const row = heading.closest("li");
  if (!row) throw new Error(`No list item for ${title}`);
  return within(row);
}

beforeEach(() => {
  vi.restoreAllMocks();
  page.props = {
    auth: { user: { id: 2, display_name: "Bob", email: "bob@example.com" } },
    flash: {},
  };
  postRequest = vi.spyOn(router, "post").mockImplementation(() => {});
  putRequest = vi.spyOn(router, "put").mockImplementation(() => {});
  deleteRequest = vi.spyOn(router, "delete").mockImplementation(() => {});
});

describe("group ranking", () => {
  it("lists titles in ranked order with scores, including negative ones", () => {
    renderPage();
    const titles = screen
      .getAllByRole("listitem")
      .map((row) => within(row).getByRole("heading").textContent);
    expect(titles).toEqual(["Paddington", "Up", "Cats"]);
    expect(item("Paddington").getByText("+3")).toBeInTheDocument();
    expect(item("Up").getByText("0")).toBeInTheDocument();
    expect(item("Cats").getByText("-2")).toHaveClass("is-negative");
  });

  it("shows how many members rated each title and who suggested it", () => {
    renderPage();
    expect(item("Paddington").getByText("Suggested by Alice · 3 of 3 rated")).toBeInTheDocument();
    expect(item("Up").getByText("Suggested by Bob · 0 of 3 rated")).toBeInTheDocument();
    expect(item("Cats").getByText("1 of 3 rated")).toBeInTheDocument();
  });

  it("explains the scoring and shows an empty state", () => {
    renderPage([]);
    expect(
      screen.getByText(/Love it adds 2, Maybe adds 1, and Not interested subtracts 2/),
    ).toBeInTheDocument();
    expect(screen.getByText(/No suggestions yet/)).toBeInTheDocument();
    expect(screen.queryByRole("list")).not.toBeInTheDocument();
  });

  it("links back to the group", () => {
    renderPage();
    expect(screen.getByRole("link", { name: "← Friday Film Club" })).toHaveAttribute(
      "href",
      "/groups/7",
    );
  });
});

describe("suggesting a title", () => {
  it("submits the title, disables the button while pending, and clears the field on success", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.type(screen.getByLabelText("Title"), "Spirited Away");
    await user.click(screen.getByRole("button", { name: "Add suggestion" }));
    const [url, data, options] = postRequest.mock.calls[0];
    expect(url).toBe("/groups/7/suggestions");
    expect(data).toEqual({ title: "Spirited Away" });
    expect(options?.preserveScroll).toBe(true);
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Adding…" })).toBeDisabled();
    act(() => {
      options?.onSuccess?.(nextPage);
      options?.onFinish?.(visit);
    });
    expect(screen.getByLabelText("Title")).toHaveValue("");
  });

  it("shows a server error beside the title field", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.type(screen.getByLabelText("Title"), "paddington");
    await user.click(screen.getByRole("button", { name: "Add suggestion" }));
    const options = postRequest.mock.calls[0][2];
    act(() => {
      options?.onError?.({ title: ["has already been suggested in this group"] });
      options?.onFinish?.(visit);
    });
    expect(screen.getByLabelText("Title")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByLabelText("Title")).toHaveValue("paddington");
    expect(screen.getByRole("alert")).toHaveTextContent("has already been suggested in this group");
  });
});

describe("rating", () => {
  it("offers exactly three options and highlights my current rating", () => {
    renderPage();
    const buttons = item("Paddington").getAllByRole("button", { pressed: false });
    const pressed = item("Paddington").getByRole("button", { pressed: true });
    expect(pressed).toHaveTextContent("Maybe");
    expect(buttons.map((button) => button.textContent)).toEqual(["Love it", "Not interested"]);
    expect(item("Up").queryByRole("button", { pressed: true })).not.toBeInTheDocument();
    expect(item("Cats").getByRole("button", { pressed: true })).toHaveTextContent("Not interested");
  });

  it("sends the chosen rating and disables the options while saving", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(item("Up").getByRole("button", { name: "Love it" }));
    const [url, data, options] = putRequest.mock.calls[0];
    expect(url).toBe("/groups/7/suggestions/12/vote");
    expect(data).toEqual({ rating: "love" });
    expect(options?.preserveScroll).toBe(true);
    act(() => options?.onStart?.(visit));
    for (const button of item("Up").getAllByRole("button", {
      name: /Love it|Maybe|Not interested/,
    })) {
      expect(button).toBeDisabled();
    }
    expect(item("Paddington").getByRole("button", { name: "Love it" })).toBeEnabled();
    act(() => options?.onFinish?.(visit));
    expect(item("Up").getByRole("button", { name: "Love it" })).toBeEnabled();
  });

  it("does not resend my current rating", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(item("Paddington").getByRole("button", { name: "Maybe" }));
    expect(putRequest).not.toHaveBeenCalled();
  });

  it("shows a rating error next to that title", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(item("Up").getByRole("button", { name: "Maybe" }));
    const options = putRequest.mock.calls[0][2];
    act(() => {
      options?.onStart?.(visit);
      options?.onError?.({ rating: ["Choose Love it, Maybe, or Not interested."] });
      options?.onFinish?.(visit);
    });
    expect(item("Up").getByRole("alert")).toHaveTextContent(
      "Choose Love it, Maybe, or Not interested.",
    );
    expect(item("Paddington").queryByRole("alert")).not.toBeInTheDocument();
  });
});

describe("removing a suggestion", () => {
  it("shows Remove only where I'm allowed to remove the title", () => {
    renderPage();
    expect(item("Up").getByRole("button", { name: "Remove Up" })).toBeInTheDocument();
    expect(item("Paddington").queryByRole("button", { name: /Remove/ })).not.toBeInTheDocument();
    expect(item("Cats").queryByRole("button", { name: /Remove/ })).not.toBeInTheDocument();
  });

  it("can be cancelled without sending a request", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(screen.getByRole("button", { name: "Remove Up" }));
    expect(
      screen.getByText(/Remove “Up”\? Everyone's ratings for it will be deleted\./),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Cancel" })).toHaveFocus();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(deleteRequest).not.toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Remove Up" })).toBeInTheDocument();
  });

  it("removes after confirmation and blocks repeated submissions", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(screen.getByRole("button", { name: "Remove Up" }));
    await user.click(screen.getByRole("button", { name: "Yes, remove" }));
    const [url, options] = deleteRequest.mock.calls[0];
    expect(url).toBe("/groups/7/suggestions/12");
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Removing…" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Cancel" })).toBeDisabled();
    await user.click(screen.getByRole("button", { name: "Removing…" }));
    expect(deleteRequest).toHaveBeenCalledTimes(1);
  });
});

describe("group page", () => {
  it("links to the group's ranking", () => {
    render(
      <Group
        group={{
          id: 7,
          name: "Friday Film Club",
          is_owner: false,
          members: [{ id: 2, display_name: "Bob", role: "member" }],
        }}
      />,
    );
    expect(screen.getByRole("link", { name: "What should we watch?" })).toHaveAttribute(
      "href",
      "/groups/7/suggestions",
    );
  });
});
