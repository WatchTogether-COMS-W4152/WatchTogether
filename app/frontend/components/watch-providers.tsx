import "../styles/watch-providers.css";

export type WatchProviders =
  | {
      status: "available";
      region: string;
      streaming: string[];
      rent: string[];
      buy: string[];
      free: string[];
      ads: string[];
    }
  | {
      status: "not_linked" | "unavailable";
    };

export default function WatchProvidersSection({ availability }: { availability?: WatchProviders }) {
  if (!availability) return null;

  const categories =
    availability.status === "available"
      ? [
          { label: "Streaming subscriptions", providers: availability.streaming },
          { label: "Free", providers: availability.free },
          { label: "Free with ads", providers: availability.ads },
          { label: "Rent", providers: availability.rent },
          { label: "Buy", providers: availability.buy },
        ].filter((category) => category.providers.length > 0)
      : [];

  return (
    <section className="watch-providers" aria-labelledby="watch-providers-heading">
      <div className="watch-providers-header">
        <h2 id="watch-providers-heading">Where to watch</h2>
        <span className="watch-providers-region">United States</span>
      </div>

      {availability.status === "not_linked" ? (
        <p>Streaming information is not available for manually added titles.</p>
      ) : availability.status === "unavailable" ? (
        <p>Streaming information is temporarily unavailable. Try again later.</p>
      ) : categories.length === 0 ? (
        <p>No watch providers are currently listed in the United States.</p>
      ) : (
        <div className="watch-providers-categories">
          {categories.map(({ label, providers }) => (
            <div className="watch-providers-category" key={label}>
              <h3>{label}</h3>
              <ul className="watch-providers-list">
                {providers.map((provider) => (
                  <li key={provider}>{provider}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      )}

      {availability.status === "available" && (
        <p className="watch-providers-credit">
          Availability may change. Data provided by JustWatch via TMDB.
        </p>
      )}
    </section>
  );
}
