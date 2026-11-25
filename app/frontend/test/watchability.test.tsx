import { router } from "@inertiajs/react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";
import { beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import Profile from "../pages/profile/show";
import Suggestions from "../pages/suggestions/index";
import Watchlist from "../pages/watchlist_items/index";
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

let getRequest: MockInstance<typeof router.get>;
let patchRequest: MockInstance<typeof router.patch>;

const group = { id: 7, name: "Friday Film Club" };
const votingGroup: VotingGroup = { ...group, is_owner: false };

beforeEach(() => {
  vi.restoreAllMocks();
  page.props = {
    auth: { user: { id: 2, display_name: "Bob", email: "bob@example.com" } },
    flash: {},
  };
  getRequest = vi.spyOn(router, "get").mockImplementation(() => {});
  patchRequest = vi.spyOn(router, "patch").mockImplementation(() => {});
});

describe("streaming services on the profile", () => {
  it("saves the checked services and can clear them", async () => {
    const user = userEvent.setup();
    render(
      <Profile
        services={[
          { id: 8, name: "Netflix" },
          { id: 15, name: "Hulu" },
        ]}
        selected_service_ids={[8]}
      />,
    );

    expect(screen.getByRole("checkbox", { name: "Netflix" })).toBeChecked();
    expect(screen.getByRole("checkbox", { name: "Hulu" })).not.toBeChecked();
    await user.click(screen.getByRole("checkbox", { name: "Netflix" }));
    await user.click(screen.getByRole("checkbox", { name: "Hulu" }));
    await user.click(screen.getByRole("button", { name: "Save services" }));

    expect(patchRequest).toHaveBeenCalledWith(
      "/profile",
      { streaming_services: true, provider_ids: [15] },
      expect.objectContaining({ preserveScroll: true }),
    );
  });
});

describe("where everyone can watch", () => {
  it("shows who can watch each watchlist title and filters the list", async () => {
    const user = userEvent.setup();
    const { rerender } = render(
      <Watchlist
        group={group}
        watchlist_items={[
          {
            id: 1,
            title: "Arrival",
            watched: false,
            watchability: { included: true, label: "On everyone's services" },
          },
          {
            id: 2,
            title: "Paper Moons",
            watched: false,
            watchability: { included: false, label: "Sam needs a rental" },
          },
        ]}
      />,
    );

    expect(screen.getByText("On everyone's services")).toBeVisible();
    expect(screen.getByText("Sam needs a rental")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Where can we all watch?" }));
    expect(getRequest).toHaveBeenCalledWith(
      "/groups/7/watchlist",
      { where: "everyone" },
      expect.objectContaining({ preserveScroll: true }),
    );

    rerender(<Watchlist group={group} filtering watchlist_items={[]} />);
    expect(screen.getByText("Nothing everyone can watch without paying extra.")).toBeVisible();
    await user.click(
      screen.getByRole("button", { name: "Where can we all watch?", pressed: true }),
    );
    expect(getRequest).toHaveBeenLastCalledWith(
      "/groups/7/watchlist",
      {},
      expect.objectContaining({ preserveScroll: true }),
    );
  });

  it("shows the same label and filter on ranked picks", async () => {
    const user = userEvent.setup();
    const suggestion: Suggestion = {
      id: 11,
      title: "Arrival",
      score: 2,
      votes_count: 1,
      my_rating: null,
      suggested_by: "Alice",
      can_remove: false,
      watchability: { included: true, label: "On everyone's services" },
    };
    render(<Suggestions group={votingGroup} member_count={2} suggestions={[suggestion]} />);

    expect(screen.getByText("On everyone's services")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Where can we all watch?" }));
    expect(getRequest).toHaveBeenCalledWith(
      "/groups/7/picks",
      { where: "everyone" },
      expect.objectContaining({ preserveScroll: true }),
    );
  });
});
