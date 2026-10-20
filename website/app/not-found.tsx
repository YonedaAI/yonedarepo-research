import Link from "next/link";

export const metadata = { title: "Page not found" };

export default function NotFound() {
  return (
    <div className="page">
      <section className="hero">
        <h1>Page not found.</h1>
        <p className="hero-sub">The page you asked for does not exist. The papers are listed on the overview.</p>
        <Link className="btn primary" href="/">Back to the overview</Link>
      </section>
    </div>
  );
}
