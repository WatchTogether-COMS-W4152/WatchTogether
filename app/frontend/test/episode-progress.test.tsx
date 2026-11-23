import { router } from "@inertiajs/react";
import { act, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";
import { beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import EpisodeProgressSection, { EpisodeProgressPanel } from "../components/episode-progress";
import Watchlist from "../pages/watchlist_items/index";
import type { EpisodeProgressData } from "../types/episodes";

const page = vi.hoisted(() => ({ props: {} as Record<string, unknown> }));

vi.mock("@inertiajs/react", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@inertiajs/react")>()),
  usePage: () => page,
  Head: () => null,
  Link: ({ children, ...props }: ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

type PutOptions = NonNullable<Parameters<typeof router.put>[2]>;
type Visit = Parameters<NonNullable<PutOptions["onFinish"]>>[0];
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- Form callbacks do not inspect visit metadata; the request transport is stubbed.
const visit = {} as Visit;
let putRequest: MockInstance<typeof router.put>;
let deleteRequest: MockInstance<typeof router.delete>;

const PATH = "/groups/7/watchlist_items/11/progress";

const progress: EpisodeProgressData = {
  members: [
    { id: 1, display_name: "Alice", position: { season: 2, episode: 4 }, caught_up: true },
    { id: 2, display_name: "Bob", position: { season: 2, episode: 1 }, caught_up: false },
    { id: 3, display_name: "Carol", position: null, caught_up: false },
  ],
  my_position: { season: 2, episode: 1 },
  next_episode: { season: 1, episode: 1 },
  everyone_caught_up: false,
};

function renderPanel(data: EpisodeProgressData = progress) {
  return render(<EpisodeProgressPanel path={PATH} progress={data} currentUserId={2} />);
}

function memberRow(name: string) {
  const element = screen.getByText(name, { exact: true }).closest("li");
  if (!element) throw new Error(`No progress row for ${name}`);
  return within(element);
}

beforeEach(() => {
  vi.restoreAllMocks();
  putRequest = vi.spyOn(router, "put").mockImplementation(() => {});
  deleteRequest = vi.spyOn(router, "delete").mockImplementation(() => {});
});

describe("seeing where everyone is", () => {
  it("lists each member's position, who is caught up, and the next episode", () => {
    renderPanel();
    expect(screen.getByRole("heading", { name: "Episode progress" })).toBeVisible();
    expect(screen.getByText("Next episode for everyone: S1 E1")).toBeVisible();
    const rows = within(screen.getByRole("list", { name: "Where everyone is" })).getAllByRole(
      "listitem",
    );
    expect(rows.map((row) => row.textContent)).toEqual([
      "AAliceCaught upS2 E4",
      "BBob (you)S2 E1",
      "CCarolNot started",
    ]);
    expect(memberRow("Alice").getByText("Caught up")).toBeVisible();
    expect(memberRow("Carol").queryByText("Caught up")).not.toBeInTheDocument();
    expect(screen.getByText("You've watched up to S2 E1.")).toBeVisible();
  });

  it("explains when nobody has started", () => {
    renderPanel({
      members: [{ id: 2, display_name: "Bob", position: null, caught_up: false }],
      my_position: null,
      next_episode: { season: 1, episode: 1 },
      everyone_caught_up: false,
    });
    expect(screen.getByText("Nobody has started yet. Start together with S1 E1.")).toBeVisible();
    expect(screen.getByText("You haven't started yet.")).toBeVisible();
    expect(screen.getByLabelText("Season")).toHaveValue(1);
    expect(screen.getByLabelText("Episode")).toHaveValue(null);
    expect(screen.queryByRole("button", { name: "Clear my progress" })).not.toBeInTheDocument();
  });

  it("celebrates when everyone is caught up", () => {
    renderPanel({
      members: [
        { id: 1, display_name: "Alice", position: { season: 1, episode: 5 }, caught_up: true },
        { id: 2, display_name: "Bob", position: { season: 1, episode: 5 }, caught_up: true },
      ],
      my_position: { season: 1, episode: 5 },
      next_episode: { season: 1, episode: 6 },
      everyone_caught_up: true,
    });
    expect(screen.getByText("Everyone is caught up. Next up together: S1 E6.")).toBeVisible();
  });
});

describe("recording my progress", () => {
  it("saves the season and episode I enter", async () => {
    const user = userEvent.setup();
    renderPanel();
    expect(screen.getByLabelText("Season")).toHaveValue(2);
    expect(screen.getByLabelText("Episode")).toHaveValue(1);
    await user.clear(screen.getByLabelText("Episode"));
    await user.type(screen.getByLabelText("Episode"), "6");
    await user.click(screen.getByRole("button", { name: "Save progress" }));

    const [url, data, options] = putRequest.mock.calls[0];
    expect(url).toBe(PATH);
    expect(data).toEqual({ season: "2", episode: "6" });
    expect(options?.preserveScroll).toBe(true);
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Save progress" })).toBeDisabled();
    expect(screen.getByRole("button", { name: /Watched next episode/ })).toBeDisabled();
  });

  it("shows server validation next to the field", async () => {
    const user = userEvent.setup();
    renderPanel();
    await user.clear(screen.getByLabelText("Season"));
    await user.type(screen.getByLabelText("Season"), "0");
    await user.click(screen.getByRole("button", { name: "Save progress" }));
    const options = putRequest.mock.calls[0][2];
    act(() => {
      options?.onError?.({ season: ["Enter a season number of 1 or more."] });
      options?.onFinish?.(visit);
    });
    expect(screen.getByRole("alert")).toHaveTextContent("Enter a season number of 1 or more.");
    expect(screen.getByLabelText("Season")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByLabelText("Season")).toHaveValue(0);
  });

  it("advances one episode with a single click", async () => {
    const user = userEvent.setup();
    renderPanel();
    await user.click(screen.getByRole("button", { name: "Watched next episode (S2 E2)" }));

    const [url, data] = putRequest.mock.calls[0];
    expect(url).toBe(PATH);
    expect(data).toEqual({ next: "1" });
    expect(screen.getByLabelText("Season")).toHaveValue(2);
    expect(screen.getByLabelText("Episode")).toHaveValue(2);
  });

  it("starts at the first episode when I have not started", async () => {
    const user = userEvent.setup();
    renderPanel({ ...progress, my_position: null });
    await user.click(screen.getByRole("button", { name: "Watched next episode (S1 E1)" }));
    expect(putRequest.mock.calls[0][1]).toEqual({ next: "1" });
    expect(screen.getByLabelText("Episode")).toHaveValue(1);
  });

  it("clears my progress", async () => {
    const user = userEvent.setup();
    renderPanel();
    await user.click(screen.getByRole("button", { name: "Clear my progress" }));
    expect(deleteRequest).toHaveBeenCalledWith(PATH, { preserveScroll: true });
    expect(screen.getByLabelText("Episode")).toHaveValue(null);
  });
});

describe("the watchlist item page section", () => {
  it("reads progress from the page and renders nothing without it", () => {
    page.props = {
      auth: { user: { id: 2, display_name: "Bob", email: "bob@example.com" } },
      flash: {},
      group: { id: 7, name: "Friday" },
      item: { id: 11 },
      episode_progress: progress,
    };
    const { unmount } = render(<EpisodeProgressSection />);
    expect(screen.getByText("Bob", { exact: true }).parentElement).toHaveTextContent("(you)");
    unmount();

    page.props = { auth: { user: null }, flash: {}, group: { id: 7 }, item: { id: 11 } };
    const { container } = render(<EpisodeProgressSection />);
    expect(container).toBeEmptyDOMElement();
  });

  it("hints at the group's next episode on the watchlist", () => {
    page.props = { auth: { user: null }, flash: {} };
    render(
      <Watchlist
        group={{ id: 7, name: "Friday" }}
        watchlist_items={[
          { id: 11, title: "Severance", watched: false, next_episode: { season: 1, episode: 3 } },
          { id: 12, title: "Dark", watched: false, next_episode: null },
        ]}
      />,
    );
    expect(screen.getByText("Next together: S1 E3")).toBeVisible();
    expect(screen.getAllByText(/Next together/)).toHaveLength(1);
  });
});
