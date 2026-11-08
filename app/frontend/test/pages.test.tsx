import { router } from "@inertiajs/react";
import { act, fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { ComponentProps } from "react";
import { beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";

import SignIn from "../pages/auth/sign-in";
import SignUp from "../pages/auth/sign-up";
import ErrorPage from "../pages/errors/show";
import Groups from "../pages/groups/index";
import JoinGroup from "../pages/groups/join";
import NewGroup from "../pages/groups/new";
import Group from "../pages/groups/show";
import Profile from "../pages/profile/show";
import type { GroupDetails, SharedProps } from "../types";

const page = vi.hoisted(() => ({
  props: { auth: { user: null }, flash: {} } as SharedProps,
}));

// Keep Inertia's real useForm: only the page context, head renderer, links,
// and request transport are replaced. Typing and form state run normally.
vi.mock("@inertiajs/react", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@inertiajs/react")>()),
  usePage: () => page,
  Head: () => null,
  Link: ({ children, ...props }: ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

type PostOptions = NonNullable<Parameters<typeof router.post>[2]>;
type Visit = Parameters<NonNullable<PostOptions["onFinish"]>>[0];
// oxlint-disable-next-line typescript/no-unsafe-type-assertion -- Inertia's form callbacks do not inspect visit metadata; the request transport is stubbed.
const visit = {} as Visit;
let postRequest: MockInstance<typeof router.post>;
let patchRequest: MockInstance<typeof router.patch>;
let deleteRequest: MockInstance<typeof router.delete>;
const owner = { id: 1, display_name: "Alice", email: "alice@example.com" };
const group: GroupDetails = {
  id: 7,
  name: "Friday Film Club",
  is_owner: true,
  members: [
    { id: 1, display_name: "Alice", role: "owner" },
    { id: 2, display_name: "Bob", role: "member" },
  ],
  invitation_code: "ABCDEF1234567890",
};

function lastPost() {
  const call = postRequest.mock.calls.at(-1);
  if (!call) throw new Error("Expected an Inertia POST");
  return call;
}

beforeEach(() => {
  vi.restoreAllMocks();
  page.props = { auth: { user: owner }, flash: {} };
  postRequest = vi.spyOn(router, "post").mockImplementation(() => {});
  patchRequest = vi.spyOn(router, "patch").mockImplementation(() => {});
  deleteRequest = vi.spyOn(router, "delete").mockImplementation(() => {});
  Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
});

describe("accounts", () => {
  it("submits a new profile and disables the button while registration is pending", async () => {
    page.props.auth.user = null;
    const user = userEvent.setup();
    render(<SignUp />);
    await user.type(screen.getByLabelText("Display name"), "Alice");
    await user.type(screen.getByLabelText("Email"), "alice@example.com");
    await user.type(screen.getByLabelText("Password", { exact: true }), "WatchTogether123!");
    await user.type(screen.getByLabelText("Confirm password"), "WatchTogether123!");
    await user.click(screen.getByRole("button", { name: "Create account" }));
    const [url, data, options] = lastPost();
    expect(url).toBe("/sign-up");
    expect(data).toEqual({
      display_name: "Alice",
      email: "alice@example.com",
      password: "WatchTogether123!",
      password_confirmation: "WatchTogether123!",
    });
    act(() => {
      options?.onStart?.(visit);
    });
    expect(screen.getByRole("button", { name: "Creating account…" })).toBeDisabled();
  });

  it("shows server validation beside the field, preserves email, and clears passwords", async () => {
    page.props.auth.user = null;
    const user = userEvent.setup();
    render(<SignUp />);
    await user.type(screen.getByLabelText("Email"), "alice@example.com");
    await user.type(screen.getByLabelText("Password", { exact: true }), "WatchTogether123!");
    await user.type(screen.getByLabelText("Confirm password"), "WatchTogether123!");
    await user.click(screen.getByRole("button", { name: "Create account" }));
    const options = lastPost()[2];
    act(() => {
      options?.onError?.({ email: ["has already been taken"] });
      options?.onFinish?.(visit);
    });
    expect(screen.getByLabelText("Email")).toHaveValue("alice@example.com");
    expect(screen.getByLabelText("Email")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByRole("alert")).toHaveTextContent("has already been taken");
    expect(screen.getByLabelText("Password", { exact: true })).toHaveValue("");
    expect(screen.getByLabelText("Confirm password")).toHaveValue("");
  });

  it("submits sign-in credentials and shows invalid-credentials feedback", async () => {
    page.props.auth.user = null;
    const user = userEvent.setup();
    render(<SignIn />);
    await user.type(screen.getByLabelText("Email"), "alice@example.com");
    await user.type(screen.getByLabelText("Password"), "wrong-password");
    await user.click(screen.getByRole("button", { name: "Sign in" }));
    const [url, data, options] = lastPost();
    expect(url).toBe("/sign-in");
    expect(data).toEqual({ email: "alice@example.com", password: "wrong-password" });
    act(() => {
      options?.onError?.({ email: ["Email or password is incorrect."] });
      options?.onFinish?.(visit);
    });
    expect(screen.getByRole("alert")).toHaveTextContent("Email or password is incorrect.");
    expect(screen.getByLabelText("Password")).toHaveValue("");
  });

  it("explains an expired session on the signed-out page", () => {
    page.props = {
      auth: { user: null },
      flash: { alert: "Your session has expired. Please sign in again." },
    };
    render(<SignIn />);
    expect(screen.getByRole("alert")).toHaveTextContent("Your session has expired");
    expect(screen.queryByRole("button", { name: "Sign out" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sign in" })).toBeEnabled();
  });

  it("updates the display name without sending the email", async () => {
    const user = userEvent.setup();
    render(<Profile />);
    await user.clear(screen.getByLabelText("Display name"));
    await user.type(screen.getByLabelText("Display name"), "Alice Movie Fan");
    await user.click(screen.getByRole("button", { name: "Save changes" }));
    expect(patchRequest).toHaveBeenCalledWith(
      "/profile",
      { display_name: "Alice Movie Fan" },
      expect.any(Object),
    );
    expect(screen.getByText("alice@example.com")).toBeVisible();
  });

  it("signs out through the server and prevents repeated logout clicks", async () => {
    const user = userEvent.setup();
    render(<Groups groups={[]} />);
    await user.click(screen.getByRole("button", { name: "Sign out" }));
    const [url, options] = deleteRequest.mock.calls[0];
    expect(url).toBe("/session");
    act(() => {
      options?.onStart?.(visit);
    });
    expect(screen.getByRole("button", { name: "Signing out…" })).toBeDisabled();
  });
});

describe("group flows", () => {
  it("offers clear create/join actions when the user has no groups", () => {
    render(<Groups groups={[]} />);
    expect(screen.getByText("Your next watch night starts here")).toBeVisible();
    expect(screen.getByRole("link", { name: "Create your first group" })).toHaveAttribute(
      "href",
      "/groups/new",
    );
    expect(screen.getByRole("link", { name: "Join a group" })).toHaveAttribute(
      "href",
      "/groups/join",
    );
  });

  it("links to the member's groups and labels ownership", () => {
    render(
      <Groups groups={[{ id: 7, name: "Friday Film Club", is_owner: true, member_count: 2 }]} />,
    );
    expect(screen.getByRole("link", { name: /Friday Film Club/ })).toHaveAttribute(
      "href",
      "/groups/7",
    );
    expect(screen.getByText("2 members")).toBeVisible();
    expect(screen.getByText("Owner")).toBeVisible();
  });

  it("submits a group name and presents a rejected name", async () => {
    const user = userEvent.setup();
    render(<NewGroup />);
    await user.type(screen.getByLabelText("Group name"), "Friday Film Club");
    await user.click(screen.getByRole("button", { name: "Create group" }));
    const [url, data, options] = lastPost();
    expect(url).toBe("/groups");
    expect(data).toEqual({ name: "Friday Film Club" });
    act(() => {
      options?.onError?.({ name: ["is too long"] });
    });
    expect(screen.getByRole("alert")).toHaveTextContent("is too long");
    expect(screen.getByLabelText("Group name")).toHaveValue("Friday Film Club");
  });

  it("submits a pasted invitation code and shows an invalid-code error", async () => {
    const user = userEvent.setup();
    render(<JoinGroup />);
    await user.click(screen.getByLabelText("Invitation code"));
    await user.paste(" old-code ");
    await user.click(screen.getByRole("button", { name: "Join group" }));
    const [url, data, options] = lastPost();
    expect(url).toBe("/groups/join");
    expect(data).toEqual({ code: " old-code " });
    act(() => {
      options?.onError?.({ code: ["That invitation code is invalid."] });
    });
    expect(screen.getByRole("alert")).toHaveTextContent("That invitation code is invalid.");
    expect(screen.getByLabelText("Invitation code")).toHaveAttribute("aria-invalid", "true");
  });

  it("shows member names and hides all invitation controls from ordinary members", () => {
    page.props.auth.user = { id: 2, display_name: "Bob", email: "bob@example.com" };
    const { invitation_code: _code, ...memberGroup } = group;
    render(<Group group={{ ...memberGroup, is_owner: false }} />);
    expect(screen.getByText("Alice")).toBeVisible();
    expect(screen.getByText("Bob")).toBeVisible();
    expect(screen.queryByText(group.invitation_code!)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Copy code" })).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Replace invitation code" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("alice@example.com")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Delete group" })).not.toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Delete this group" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /^Manage / })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Make owner" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Remove from group" })).not.toBeInTheDocument();
  });

  it("copies the owner's invitation code", async () => {
    const user = userEvent.setup();
    const writeText = vi.spyOn(navigator.clipboard, "writeText");
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Copy code" }));
    expect(writeText).toHaveBeenCalledWith(group.invitation_code);
    expect(screen.getByRole("status")).toHaveTextContent("Invitation code copied.");
  });

  it("keeps the code visible and gives a manual fallback if clipboard access fails", async () => {
    const user = userEvent.setup();
    vi.spyOn(navigator.clipboard, "writeText").mockRejectedValue(new Error("Permission denied"));
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Copy code" }));
    expect(screen.getByRole("alert")).toHaveTextContent("Select and copy it manually");
    expect(screen.getByText(group.invitation_code!)).toBeVisible();
  });

  it("shares the group name, code, and join URL when native sharing is available", async () => {
    const user = userEvent.setup();
    const share = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "share", { configurable: true, value: share });
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Share" }));
    expect(share).toHaveBeenCalledWith(
      expect.objectContaining({
        text: expect.stringContaining(group.invitation_code!),
        url: `${window.location.origin}/groups/join`,
      }),
    );
  });

  it("requires confirmation before replacing a code and blocks repeated submissions", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Replace invitation code" }));
    expect(postRequest).not.toHaveBeenCalled();
    expect(screen.getByText(/The old code will stop working/)).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Replace code" }));
    const [url, data, options] = lastPost();
    expect(url).toBe("/groups/7/invitation/reset");
    expect(data).toEqual({});
    act(() => {
      options?.onStart?.(visit);
    });
    expect(screen.getByRole("button", { name: "Replacing…" })).toBeDisabled();
  });

  it("lets the owner cancel deletion without sending a request", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Delete group" }));
    expect(screen.getByText(/Delete “Friday Film Club”/)).toHaveTextContent(
      "This cannot be undone",
    );
    expect(deleteRequest).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.queryByRole("button", { name: "Yes, delete group" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Delete group" })).toBeEnabled();
    expect(deleteRequest).not.toHaveBeenCalled();
  });

  it("deletes only after confirmation and blocks repeated submissions", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Delete group" }));
    expect(deleteRequest).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Yes, delete group" }));
    const [url, options] = deleteRequest.mock.calls[0];
    expect(url).toBe("/groups/7");
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Deleting…" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Cancel" })).toBeDisabled();
    await user.click(screen.getByRole("button", { name: "Deleting…" }));
    expect(deleteRequest).toHaveBeenCalledTimes(1);
  });

  it("allows retrying a failed deletion while keeping its confirmation visible", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Delete group" }));
    await user.click(screen.getByRole("button", { name: "Yes, delete group" }));
    const options = deleteRequest.mock.calls[0][1];
    act(() => options?.onStart?.(visit));
    fireEvent(
      document,
      new CustomEvent("inertia:networkError", {
        cancelable: true,
        detail: { error: new Error("Offline") },
      }),
    );
    act(() => options?.onFinish?.(visit));
    expect(screen.getByRole("alert")).toHaveTextContent("Check your connection and try again");
    expect(screen.getByRole("button", { name: "Yes, delete group" })).toBeEnabled();
    expect(screen.getByText(/Delete “Friday Film Club”/)).toBeVisible();
  });
});

describe("member management", () => {
  it("keeps member actions behind Manage and never offers self-removal", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    const manage = screen.getByRole("button", { name: "Manage Bob" });
    expect(manage).toHaveAttribute("aria-expanded", "false");
    expect(screen.queryByRole("button", { name: "Manage Alice" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Make owner" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Remove from group" })).not.toBeInTheDocument();
    await user.click(manage);
    expect(manage).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByRole("heading", { name: "Manage Bob" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Make owner" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Remove from group" })).toBeEnabled();
    expect(postRequest).not.toHaveBeenCalled();
    expect(deleteRequest).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Done" }));
    expect(screen.queryByRole("heading", { name: "Manage Bob" })).not.toBeInTheDocument();
    expect(manage).toHaveFocus();
  });

  it("explains promotion and lets the owner cancel without changing access", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Manage Bob" }));
    await user.click(screen.getByRole("button", { name: "Make owner" }));
    expect(screen.getByRole("heading", { name: "Make Bob an owner?" })).toBeVisible();
    expect(screen.getByRole("region", { name: "Make Bob an owner?" })).toHaveTextContent(
      "delete the group",
    );
    expect(postRequest).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.queryByRole("button", { name: "Confirm promotion" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Manage Bob" })).toHaveFocus();
    expect(postRequest).not.toHaveBeenCalled();
  });

  it("promotes the selected member only after confirmation and prevents overlapping changes", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Manage Bob" }));
    await user.click(screen.getByRole("button", { name: "Make owner" }));
    await user.click(screen.getByRole("button", { name: "Confirm promotion" }));
    const [url, data, options] = lastPost();
    expect(url).toBe("/groups/7/members/2/promote");
    expect(data).toEqual({});
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Promoting…" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Cancel" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Manage Bob" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Replace invitation code" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Delete group" })).toBeDisabled();
    await user.click(screen.getByRole("button", { name: "Promoting…" }));
    expect(postRequest).toHaveBeenCalledTimes(1);
  });

  it("shows every owner badge and gives a promoted owner the same controls", async () => {
    page.props.auth.user = { id: 2, display_name: "Bob", email: "bob@example.com" };
    const coownedGroup: GroupDetails = {
      ...group,
      members: group.members.map((member) => ({ ...member, role: "owner" })),
    };
    const user = userEvent.setup();
    render(<Group group={coownedGroup} />);
    expect(screen.getAllByText("Owner")).toHaveLength(2);
    expect(screen.getByRole("button", { name: "Copy code" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Delete group" })).toBeEnabled();
    expect(screen.queryByRole("button", { name: "Manage Bob" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Manage Alice" }));
    expect(screen.queryByRole("button", { name: "Make owner" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Remove from group" }));
    expect(screen.getByRole("heading", { name: "Remove Alice from the group?" })).toBeVisible();
    expect(screen.getByRole("region", { name: "Remove Alice from the group?" })).toHaveTextContent(
      "lose their owner permissions",
    );
    expect(deleteRequest).not.toHaveBeenCalled();
  });

  it("explains removal and invitation replacement before allowing cancellation", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Manage Bob" }));
    await user.click(screen.getByRole("button", { name: "Remove from group" }));
    expect(screen.getByRole("heading", { name: "Remove Bob from the group?" })).toBeVisible();
    const confirmation = screen.getByRole("region", { name: "Remove Bob from the group?" });
    expect(confirmation).toHaveTextContent("invitation code will change");
    expect(confirmation).toHaveTextContent("Their account will be kept");
    expect(confirmation).toHaveTextContent("Other members will stay");
    expect(deleteRequest).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.queryByRole("button", { name: "Confirm removal" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Manage Bob" })).toHaveFocus();
    expect(screen.getByText("Bob")).toBeVisible();
    expect(deleteRequest).not.toHaveBeenCalled();
  });

  it("removes only the selected membership and blocks repeated submissions", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Manage Bob" }));
    await user.click(screen.getByRole("button", { name: "Remove from group" }));
    await user.click(screen.getByRole("button", { name: "Confirm removal" }));
    const [url, options] = deleteRequest.mock.calls[0];
    expect(url).toBe("/groups/7/members/2");
    act(() => options?.onStart?.(visit));
    expect(screen.getByRole("button", { name: "Removing…" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Cancel" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Replace invitation code" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Delete group" })).toBeDisabled();
    await user.click(screen.getByRole("button", { name: "Removing…" }));
    expect(deleteRequest).toHaveBeenCalledTimes(1);
  });

  it("keeps the removal target visible and allows retry after a network failure", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Manage Bob" }));
    await user.click(screen.getByRole("button", { name: "Remove from group" }));
    await user.click(screen.getByRole("button", { name: "Confirm removal" }));
    const options = deleteRequest.mock.calls[0][1];
    act(() => options?.onStart?.(visit));
    fireEvent(
      document,
      new CustomEvent("inertia:networkError", {
        cancelable: true,
        detail: { error: new Error("Offline") },
      }),
    );
    act(() => options?.onFinish?.(visit));
    expect(screen.getByRole("alert")).toHaveTextContent("Check your connection and try again");
    expect(screen.getByRole("heading", { name: "Remove Bob from the group?" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Confirm removal" })).toBeEnabled();
    await user.click(screen.getByRole("button", { name: "Confirm removal" }));
    expect(deleteRequest).toHaveBeenCalledTimes(2);
    expect(deleteRequest.mock.calls[1][0]).toBe("/groups/7/members/2");
  });

  it("closes a pending member confirmation when switching to invitation settings", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Manage Bob" }));
    await user.click(screen.getByRole("button", { name: "Remove from group" }));
    await user.click(screen.getByRole("button", { name: "Replace invitation code" }));
    expect(screen.queryByRole("button", { name: "Confirm removal" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Replace code" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Cancel" })).toHaveFocus();
    expect(deleteRequest).not.toHaveBeenCalled();
    expect(postRequest).not.toHaveBeenCalled();
  });

  it("supports keyboard dismissal and returns focus to the member's Manage button", async () => {
    const user = userEvent.setup();
    render(<Group group={group} />);
    await user.click(screen.getByRole("button", { name: "Manage Bob" }));
    await user.click(screen.getByRole("button", { name: "Make owner" }));
    expect(screen.getByRole("heading", { name: "Make Bob an owner?" })).toHaveFocus();
    await user.keyboard("{Escape}");
    expect(screen.queryByRole("region", { name: "Make Bob an owner?" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Manage Bob" })).toHaveFocus();
    expect(postRequest).not.toHaveBeenCalled();
  });
});

describe("recovery", () => {
  it("preserves typed input and displays a useful connection error", async () => {
    const user = userEvent.setup();
    render(<NewGroup />);
    await user.type(screen.getByLabelText("Group name"), "Friday Film Club");
    const event = new CustomEvent("inertia:networkError", {
      cancelable: true,
      detail: { error: new Error("Offline") },
    });
    fireEvent(document, event);
    expect(event.defaultPrevented).toBe(true);
    expect(screen.getByRole("alert")).toHaveTextContent("Check your connection and try again");
    expect(screen.getByLabelText("Group name")).toHaveValue("Friday Film Club");
    expect(screen.getByRole("button", { name: "Create group" })).toBeEnabled();
  });

  it("renders a safe recovery page for inaccessible groups", () => {
    render(<ErrorPage status={404} message="This group is unavailable." />);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "We couldn't find that page",
    );
    expect(screen.getByRole("link", { name: "Back to my groups" })).toHaveAttribute(
      "href",
      "/groups",
    );
  });
});
