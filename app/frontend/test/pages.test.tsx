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
  owner_id: 1,
  members: [
    { id: 1, display_name: "Alice" },
    { id: 2, display_name: "Bob" },
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
    render(<Groups groups={[{ id: 7, name: "Friday Film Club", owner_id: 1, member_count: 2 }]} />);
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
    render(<Group group={memberGroup} />);
    expect(screen.getByText("Alice")).toBeVisible();
    expect(screen.getByText("Bob")).toBeVisible();
    expect(screen.queryByText(group.invitation_code!)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Copy code" })).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Replace invitation code" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("alice@example.com")).not.toBeInTheDocument();
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
