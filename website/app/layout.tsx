import type { Metadata } from "next";
import "katex/dist/katex.min.css";
import "./globals.css";
import { Shell } from "@/components/Shell";
import { papers, SERIES, THESIS, REPO_URL } from "@/lib/papers";

const siteUrl = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : process.env.NEXT_PUBLIC_SITE_URL || "https://yonedarepo-research.vercel.app";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: { default: `YonedaRepo Research: ${SERIES}`, template: "%s | YonedaRepo Research" },
  description: THESIS,
  icons: { icon: "/brand/mark.svg" },
  openGraph: {
    type: "website",
    url: "/",
    siteName: "YonedaRepo Research",
    images: [{ url: "/og/home.png", width: 1200, height: 630 }],
  },
  twitter: { card: "summary_large_image", images: ["/og/home.png"] },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const items = papers.map((p) => ({ slug: p.slug, short: p.short, title: p.title, published: p.status === "published" }));
  return (
    <html lang="en">
      <body>
        <Shell series={SERIES} repoUrl={REPO_URL} items={items}>{children}</Shell>
      </body>
    </html>
  );
}
