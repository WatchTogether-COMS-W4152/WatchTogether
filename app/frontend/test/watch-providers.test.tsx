import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import WatchProvidersSection, { type WatchProviders } from "../components/watch-providers";

const providers: WatchProviders = {
  status: "available",
  region: "US",
  streaming: ["Netflix"],
  rent: ["Amazon Video"],
  buy: ["Apple TV Store"],
  free: ["Plex"],
  ads: ["Tubi"],
};

describe("streaming availability", () => {
  it("shows providers grouped by availability type", () => {
    render(<WatchProvidersSection availability={providers} />);

    expect(screen.getByRole("heading", { name: "Where to watch" })).toBeVisible();
    expect(screen.getByText("United States")).toBeVisible();

    expect(screen.getByText("Streaming subscriptions")).toBeVisible();
    expect(screen.getByText("Netflix")).toBeVisible();

    expect(screen.getByText("Rent")).toBeVisible();
    expect(screen.getByText("Amazon Video")).toBeVisible();

    expect(screen.getByText("Buy")).toBeVisible();
    expect(screen.getByText("Apple TV Store")).toBeVisible();

    expect(screen.getByText("Free", { exact: true })).toBeVisible();
    expect(screen.getByText("Plex")).toBeVisible();

    expect(screen.getByText("Free with ads")).toBeVisible();
    expect(screen.getByText("Tubi")).toBeVisible();
  });

  it("hides categories without providers", () => {
    render(
      <WatchProvidersSection
        availability={{
          ...providers,
          rent: [],
          buy: [],
          free: [],
          ads: [],
        }}
      />,
    );

    expect(screen.getByText("Netflix")).toBeVisible();
    expect(screen.queryByText("Rent")).not.toBeInTheDocument();
    expect(screen.queryByText("Buy")).not.toBeInTheDocument();
    expect(screen.queryByText("Free", { exact: true })).not.toBeInTheDocument();
    expect(screen.queryByText("Free with ads")).not.toBeInTheDocument();
  });

  it("explains when no US providers are listed", () => {
    render(
      <WatchProvidersSection
        availability={{
          ...providers,
          streaming: [],
          rent: [],
          buy: [],
          free: [],
          ads: [],
        }}
      />,
    );

    expect(
      screen.getByText("No watch providers are currently listed in the United States."),
    ).toBeVisible();
  });

  it("explains why manually added titles have no availability", () => {
    render(<WatchProvidersSection availability={{ status: "not_linked" }} />);

    expect(
      screen.getByText("Streaming information is not available for manually added titles."),
    ).toBeVisible();
  });

  it("shows a friendly message when availability is temporarily unavailable", () => {
    render(<WatchProvidersSection availability={{ status: "unavailable" }} />);

    expect(
      screen.getByText("Streaming information is temporarily unavailable. Try again later."),
    ).toBeVisible();
  });

  it("credits JustWatch and TMDB", () => {
    render(<WatchProvidersSection availability={providers} />);

    expect(screen.getByText(/Data provided by JustWatch via TMDB/)).toBeVisible();
  });

  it("renders nothing when availability has not been provided", () => {
    const { container } = render(<WatchProvidersSection />);

    expect(container).toBeEmptyDOMElement();
  });
});
