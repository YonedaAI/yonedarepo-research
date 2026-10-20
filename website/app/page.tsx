import type { Metadata } from "next";
import Link from "next/link";
import { papers, excerpt, SERIES, THESIS } from "@/lib/papers";
import { ArrowIcon, BranchIcon, CheckIcon, DownloadIcon, LayersIcon, LogIcon } from "@/components/Icons";

export const metadata: Metadata = {
  title: SERIES,
  description: THESIS,
  openGraph: { title: SERIES, description: THESIS, type: "website", url: "/", images: [{ url: "/og/home.png", width: 1200, height: 630 }] },
  twitter: { card: "summary_large_image", title: SERIES, description: THESIS, images: ["/og/home.png"] },
};

const steps = [
  { Icon: LogIcon, name: "Log", text: "Every ref change is one hash-chained entry in an append-only log." },
  { Icon: CheckIcon, name: "Validate", text: "A landing is checked against every entry written since its base." },
  { Icon: LayersIcon, name: "Derive", text: "Indexes, symbols and Git commits are views maintained from the log." },
];

const results = [
  { value: "1,000 of 1,000", label: "landed in each of 6 hosted bursts at 1,000 writers" },
  { value: "714–1,673 ms", label: "commit p95 (per-writer tokens)" },
  { value: "3.2–5.4 s", label: "Git projection delay p95" },
];

export default function Home() {
  return (
    <div className="page">
      <section className="hero">
        <div className="hero-icon"><BranchIcon size={30} /></div>
        <h1>Source Code as a Transactional Abstraction.</h1>
        <p className="hero-sub">
          {THESIS} Data lakes made the same move when Delta Lake and Spark turned files on object stores into tables with a
          transaction log, snapshots and optimistic concurrency; this series builds that foundation for source control.
        </p>
        <ol className="steps" aria-label="Log, Validate, Derive">
          {steps.map(({ Icon, name, text }, i) => (
            <li key={name} className="step">
              <span className="step-icon"><Icon /></span>
              <span className="step-body"><strong>{name}</strong><small>{text}</small></span>
              {i < steps.length - 1 && <ArrowIcon className="step-arrow" />}
            </li>
          ))}
        </ol>
      </section>

      <section aria-labelledby="results-h" className="block">
        <h2 id="results-h" className="block-title">Key results</h2>
        <div className="results">
          {results.map((r) => (
            <div key={r.value} className="result">
              <div className="result-value">{r.value}</div>
              <div className="result-label">{r.label}</div>
              <div className="result-note">measured, see Part III</div>
            </div>
          ))}
        </div>
      </section>

      <section aria-labelledby="papers-h" className="block">
        <h2 id="papers-h" className="block-title">Papers</h2>
        <div className="cards">
          {papers.map((p) => {
            const live = p.status === "published";
            return (
              <article key={p.slug} className="card">
                <div className="card-top">
                  <span className="chip">{p.part}</span>
                  {!live && <span className="chip chip-muted">In review</span>}
                </div>
                <h3>{p.title}</h3>
                <p className="card-abs">{excerpt(p.abstract)}</p>
                <div className="card-foot">
                  <span className="meta">{p.pages ? `${p.pages} pages` : "In review"}</span>
                  {live && (
                    <span className="actions">
                      <Link className="btn primary" href={`/papers/${p.slug}/`}>Read</Link>
                      <a className="btn outline" href={p.pdf!}><DownloadIcon /> PDF</a>
                    </span>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <section id="how-it-works" aria-labelledby="how-h" className="block how">
        <h2 id="how-h" className="block-title">How it works</h2>
        <div className="how-grid">
          <div className="how-item">
            <span className="chip">Part I</span>
            <h3>The transaction model</h3>
            <p>
              A repository is a database, a change is a transaction with a read set and a write set, and a version is a snapshot.
              Commits are built on the server and recorded without moving any ref. A landing validates against every log entry
              written since its base and appends one hash-chained entry in the same atomic step as the ref update.
            </p>
          </div>
          <div className="how-item">
            <span className="chip">Part II</span>
            <h3>Derived data as views</h3>
            <p>
              Search indexes, symbol tables, blame and work plans are views over the log, maintained by partitioned jobs over
              immutable snapshots. A view is consistent at a snapshot whenever the key of each stored partition result determines
              that result.
            </p>
          </div>
          <div className="how-item">
            <span className="chip">Part III</span>
            <h3>Serverless realization</h3>
            <p>
              An object store, one serialized authority per repository, a durable queue and stateless compute are enough. The
              reference implementation runs on Cloudflare, and the paper measures where the authority saturates.
            </p>
          </div>
          <div className="how-item">
            <span className="chip">Overview</span>
            <h3>Git built after landing</h3>
            <p>
              Composed, the three parts let a branch&apos;s Git commit be a deterministic function of the log prefix, so Git is built
              after landing without weakening the log&apos;s guarantees.
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
