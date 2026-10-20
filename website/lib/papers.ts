import fs from "node:fs";
import path from "node:path";
import manifest from "../papers.json";

export type Paper = {
  slug: string;
  part: string;
  short: string;
  title: string;
  subtitle: string;
  author: string;
  date: string;
  abstract: string;
  abstractHtml: string;
  pages: number | null;
  status: "published" | "in-review";
  pdf: string | null;
  og: string;
};

export type Heading = { id: string; num: string; text: string; level: number };

export const papers = manifest as Paper[];
export const published = papers.filter((p) => p.status === "published");

export const SERIES = "Source Code as a Transactional Abstraction";
export const THESIS = "Source code and source control are now transactional abstractions.";
export const REPO_URL = "https://github.com/YonedaAI/yonedarepo-research";

export function getPaper(slug: string) {
  return papers.find((p) => p.slug === slug);
}

export function neighbours(slug: string) {
  const i = papers.findIndex((p) => p.slug === slug);
  return { prev: i > 0 ? papers[i - 1] : null, next: i >= 0 && i < papers.length - 1 ? papers[i + 1] : null };
}

export function paperContent(slug: string): { html: string; toc: Heading[] } {
  const dir = path.join(process.cwd(), "content");
  return {
    html: fs.readFileSync(path.join(dir, `${slug}.html`), "utf8"),
    toc: JSON.parse(fs.readFileSync(path.join(dir, `${slug}.toc.json`), "utf8")),
  };
}

// Skips the shared thesis sentence so each card shows its own contribution.
export function excerpt(text: string, max = 180) {
  text = text.replace(/^.*?\.\s+(?=[A-Z])/, "");
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  return cut.slice(0, cut.lastIndexOf(" ")).replace(/[,;:.]$/, "") + "…";
}
