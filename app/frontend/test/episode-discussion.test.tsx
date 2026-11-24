import { router } from "@inertiajs/react";
import { act, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";
import { afterEach, beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import EpisodeDiscussionSection from "../components/episode-discussion";
import type { SharedProps } from "../types";
import { formatCommentTime, type Discussion } from "../types/episodes";

const page = vi.hoisted(() => ({
  props: {} as Record<string, unknown>,
}));

vi.mock("@inertiajs/react", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@inertiajs/react")>()),
  usePage: () => page,
  Head: () => null,
  Link: ({ children, ...props }: ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

type PostOptions = NonNullable<Parameters<typeof router.post>[2]>;
type Visit = Parameters<NonNullable<PostOptions["onFinish"]>>[0];
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- Callbacks ignore visit metadata; the request transport is stubbed.
const visit = {} as Visit;
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- onSuccess receives the next page, which this form ignores.
const nextPage = {} as Parameters<NonNullable<PostOptions["onSuccess"]>>[0];
let postRequest: MockInstance<typeof router.post>;
let deleteRequest: MockInstance<typeof router.delete>;

const NOW = new Date("2026-11-23T12:00:00Z");
const shared: SharedProps = {
  auth: { user: { id: 2, display_name: "Larissa", email: "larissa@example.com" } },
  flash: {},
};

function discussion(overrides: Partial<Discussion> = {}): Discussion {
  return {
    viewer_position: { season: 1, episode: 4 },
    max_body_length: 1000,
    episodes: [
      {
        season: 1,
        episode: 2,
        hidden_count: 0,
        comments: [
          {
            id: 31,
            body: "The goats!",
            author: { id: 1, display_name: "David" },
            created_at: "2026-11-23T11:55:00Z",
            mine: false,
            can_delete: false,
          },
          {
            id: 32,
            body: "Right?",
            author: { id: 2, display_name: "Larissa" },
            created_at: "2026-11-23T11:59:30Z",
            mine: true,
            can_delete: true,
          },
        ],
      },
      { season: 1, episode: 8, hidden_count: 3, comments: [] },
      { season: 2, episode: 1, hidden_count: 1, comments: [] },
    ],
    ...overrides,
  };
}

function renderSection(data: Discussion | null = discussion()) {
  page.props = { ...shared, group: { id: 7 }, item: { id: 11 }, discussion: data ?? undefined };
  return render(<EpisodeDiscussionSection />);
}

function episode(label: string) {
  const element = screen.getByText(label).closest("li");
  if (!element) throw new Error(`No episode ${label}`);
  return within(element);
}

beforeEach(() => {
  vi.restoreAllMocks();
  vi.useFakeTimers({ now: NOW, toFake: ["Date"] });
  postRequest = vi.spyOn(router, "post").mockImplementation(() => {});
  deleteRequest = vi.spyOn(router, "delete").mockImplementation(() => {});
});

afterEach(() => {
  vi.useRealTimers();
});

describe("reading the discussion", () => {
  it("groups readable comments by episode and only counts comments beyond the viewer", () => {
    renderSection();

    expect(screen.getByRole("heading", { name: "Discussion", level: 2 })).toBeVisible();
    expect(screen.getByText("6 comments")).toBeVisible();
    expect(screen.getAllByRole("heading", { level: 3 }).map((h) => h.textContent)).toEqual([
      "S1 E2Season 1, Episode 2",
      "S1 E8Season 1, Episode 8",
      "S2 E1Season 2, Episode 1",
    ]);
    expect(screen.getByRole("heading", { name: "Season 1, Episode 2", level: 3 })).toBeVisible();
    const early = episode("S1 E2");
    expect(early.getAllByRole("listitem").map((li) => li.querySelector("p")?.textContent)).toEqual([
      "The goats!",
      "Right?",
    ]);
    expect(early.getByText("David")).toBeVisible();
    expect(early.getByText("Larissa (you)")).toBeVisible();
    expect(early.getByText("Larissa (you)").closest("li")).toHaveClass("is-mine");
    expect(early.getByText("David").closest("li")).not.toHaveClass("is-mine");
    expect(early.getByText("5m ago")).toHaveAttribute("datetime", "2026-11-23T11:55:00Z");
    expect(early.getByText("just now")).toBeVisible();
    expect(episode("S1 E8").getByText("3 comments hidden until you watch it")).toBeVisible();
    expect(episode("S1 E8").queryByRole("listitem")).not.toBeInTheDocument();
    expect(episode("S2 E1").getByText("1 comment hidden until you watch it")).toBeVisible();
  });

  it("shows an own comment and a locked count on the same episode, and former members", () => {
    renderSection(
      discussion({
        episodes: [
          {
            season: 3,
            episode: 1,
            hidden_count: 2,
            comments: [
              {
                id: 40,
                body: "Hello from the past",
                author: null,
                created_at: "2026-11-20T09:00:00Z",
                mine: false,
                can_delete: true,
              },
            ],
          },
        ],
      }),
    );

    expect(screen.getByText("3 comments")).toBeVisible();
    expect(screen.getByText("Former member")).toBeVisible();
    expect(screen.getByText("3d ago")).toBeVisible();
    expect(screen.getByText("2 comments hidden until you watch it")).toBeVisible();
  });

  it("explains an empty discussion and how to join without progress", () => {
    renderSection(discussion({ viewer_position: null, episodes: [] }));

    expect(screen.getByText("0 comments")).toBeVisible();
    expect(screen.getByText("No comments yet.")).toBeVisible();
    expect(screen.getByText("Mark an episode as watched to comment.")).toBeVisible();
    expect(screen.queryByRole("button", { name: "Post comment" })).not.toBeInTheDocument();
  });

  it("renders nothing when the page has no discussion", () => {
    const { container } = renderSection(null);
    expect(container).toBeEmptyDOMElement();
  });
});

describe("posting a comment", () => {
  it("defaults to the viewer's episode, submits, and clears the comment on success", async () => {
    const user = userEvent.setup();
    renderSection();

    expect(screen.getByLabelText("Season")).toHaveValue(1);
    expect(screen.getByLabelText("Episode")).toHaveValue(4);
    expect(screen.getByLabelText("Comment on S1 E4")).toHaveAttribute("maxlength", "1000");
    await user.clear(screen.getByLabelText("Episode"));
    await user.type(screen.getByLabelText("Episode"), "3");
    expect(screen.getByLabelText("Comment on S1 E3")).toBeInTheDocument();
    await user.type(screen.getByLabelText("Comment on S1 E3"), "Mark's office!");
    await user.click(screen.getByRole("button", { name: "Post comment" }));

    const [url, data, options] = postRequest.mock.calls[0];
    expect(url).toBe("/groups/7/watchlist_items/11/comments");
    expect(data).toEqual({ season: "1", episode: "3", body: "Mark's office!" });
    expect(options?.preserveScroll).toBe(true);
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Posting…" })).toBeDisabled();
    act(() => {
      options?.onSuccess?.(nextPage);
      options?.onFinish?.(visit);
    });
    expect(screen.getByLabelText(/^Comment/)).toHaveValue("");
    expect(screen.getByLabelText("Episode")).toHaveValue(3);
  });

  it("shows the server's explanation for an episode beyond the viewer's progress", async () => {
    const user = userEvent.setup();
    renderSection();
    await user.type(screen.getByLabelText(/^Comment/), "Spoiler");
    await user.click(screen.getByRole("button", { name: "Post comment" }));
    const options = postRequest.mock.calls[0][2];

    act(() => {
      options?.onError?.({
        episode: ["You're on S1 E4, so you can't comment on S1 E5."],
        body: ["Write something before posting."],
      });
      options?.onFinish?.(visit);
    });

    expect(screen.getByLabelText("Episode")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByLabelText(/^Comment/)).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByLabelText(/^Comment/)).toHaveValue("Spoiler");
    expect(screen.getAllByRole("alert").map((alert) => alert.textContent)).toEqual([
      "You're on S1 E4, so you can't comment on S1 E5.",
      "Write something before posting.",
    ]);
  });
});

describe("deleting a comment", () => {
  it("offers deletion only where allowed and asks for confirmation", async () => {
    const user = userEvent.setup();
    renderSection();

    expect(screen.getAllByRole("button", { name: /Delete comment/ })).toHaveLength(1);
    await user.click(screen.getByRole("button", { name: "Delete comment by Larissa" }));
    expect(screen.getByText("Delete this comment?")).toBeVisible();
    expect(screen.getByRole("button", { name: "Cancel" })).toHaveFocus();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.getByRole("button", { name: "Delete comment by Larissa" })).toHaveFocus();
    expect(deleteRequest).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Delete comment by Larissa" }));
    await user.click(screen.getByRole("button", { name: "Yes, delete" }));
    const [url, options] = deleteRequest.mock.calls[0];
    expect(url).toBe("/groups/7/watchlist_items/11/comments/32");
    expect(options?.preserveScroll).toBe(true);
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Deleting…" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Cancel" })).toBeDisabled();
    act(() => options?.onFinish?.(visit));
    expect(screen.getByRole("button", { name: "Yes, delete" })).toBeEnabled();
  });
});

describe("formatCommentTime", () => {
  it("uses short relative times, then dates", () => {
    expect(formatCommentTime("2026-11-23T11:59:30Z", NOW)).toBe("just now");
    expect(formatCommentTime("2026-11-23T11:01:00Z", NOW)).toBe("59m ago");
    expect(formatCommentTime("2026-11-23T02:00:00Z", NOW)).toBe("10h ago");
    expect(formatCommentTime("2026-11-17T12:00:00Z", NOW)).toBe("6d ago");
    expect(formatCommentTime("2026-10-02T12:00:00Z", NOW)).toMatch(/Oct/);
    expect(formatCommentTime("2025-10-02T12:00:00Z", NOW)).toMatch(/2025/);
  });
});
