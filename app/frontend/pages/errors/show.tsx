import { Link, usePage } from "@inertiajs/react";

import Layout from "../../components/layout";

export default function ErrorPage({ status, message }: { status: number; message: string }) {
  const { auth } = usePage().props;
  return (
    <Layout title={`Error ${status}`} narrow>
      <section className="empty-state">
        <p>Error {status}</p>
        <h1>{status === 404 ? "We couldn't find that page" : "We couldn't open that page"}</h1>
        <p>{message}</p>
        <Link className="button button-primary" href={auth.user ? "/groups" : "/sign-in"}>
          {auth.user ? "Back to my groups" : "Sign in"}
        </Link>
      </section>
    </Layout>
  );
}
