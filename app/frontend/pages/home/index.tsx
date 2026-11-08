import { Head } from "@inertiajs/react";

type Props = {
  environment: string;
};

export default function Home({ environment }: Props) {
  return (
    <main>
      <Head title="WatchTogether" />
      <h1>WatchTogether</h1>
      <p>Rails + Inertia + React ({environment})</p>
    </main>
  );
}
