import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getPaper, neighbours, paperContent, published, SERIES } from "@/lib/papers";
import { Toc } from "@/components/Toc";
import { DownloadIcon } from "@/components/Icons";

export function generateStaticParams() {
  return published.map((p) => ({ slug: p.slug }));
}
export const dynamicParams = false;

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const paper = getPaper(slug);
  if (!paper) return {};
  const description = paper.abstract.length > 280 ? paper.abstract.slice(0, 277).replace(/\s+\S*$/, "") + "…" : paper.abstract;
  const title = `${paper.short}: ${paper.title}`;
  return {
    title: paper.title,
    description,
    openGraph: { title, description, type: "article", url: `/papers/${paper.slug}/`, images: [{ url: paper.og, width: 1200, height: 630 }] },
    twitter: { card: "summary_large_image", title, description, images: [paper.og] },
  };
}

export default async function PaperPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const paper = getPaper(slug);
  if (!paper || paper.status !== "published") notFound();
  const { html, toc } = paperContent(slug);
  const { prev, next } = neighbours(slug);
  const NavCard = ({ p, dir }: { p: NonNullable<typeof prev>; dir: "Previous" | "Next" }) =>
    p.status === "published" ? (
      <Link href={`/papers/${p.slug}/`} className={`pn pn-${dir.toLowerCase()}`}>
        <small>{dir}</small><strong>{p.short}</strong><span>{p.title}</span>
      </Link>
    ) : (
      <div className={`pn pn-${dir.toLowerCase()} disabled`}>
        <small>{dir}</small><strong>{p.short} &middot; In review</strong><span>{p.title}</span>
      </div>
    );

  return (
    <div className="page paper-page">
      <header className="paper-head">
        <span className="chip">{paper.part}</span>
        <h1>{paper.title}</h1>
        <p className="paper-series">{paper.subtitle || `Part of ${SERIES}`}</p>
        <p className="paper-meta">{paper.author} &middot; {paper.date} &middot; {paper.pages} pages</p>
        <div className="abstract">
          <h2>Abstract</h2>
          <div dangerouslySetInnerHTML={{ __html: paper.abstractHtml }} />
        </div>
        <a className="btn primary" href={paper.pdf!}><DownloadIcon /> Download PDF</a>
      </header>
      <div className="paper-layout">
        <Toc headings={toc} />
        <article className="paper-content" dangerouslySetInnerHTML={{ __html: html }} />
      </div>
      <nav className="pn-row" aria-label="Series navigation">
        {prev ? <NavCard p={prev} dir="Previous" /> : <span />}
        {next ? <NavCard p={next} dir="Next" /> : <span />}
      </nav>
      <a className="pdf-fab" href={paper.pdf!} aria-label="Download PDF"><DownloadIcon /> PDF</a>
    </div>
  );
}
