"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { ChevronIcon, CloseIcon, ExternalIcon, MenuIcon } from "./Icons";

export type NavItem = { slug: string; short: string; title: string; published: boolean };

type Props = { series: string; repoUrl: string; items: NavItem[]; children: React.ReactNode };

export function Shell({ series, repoUrl, items, children }: Props) {
  const pathname = usePathname() ?? "/";
  const [open, setOpen] = useState(false);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const sideRef = useRef<HTMLElement>(null);
  const wasOpen = useRef(false);
  useEffect(() => setOpen(false), [pathname]);
  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    if (open) {
      sideRef.current?.querySelector<HTMLElement>("a")?.focus();
    } else if (wasOpen.current) {
      toggleRef.current?.focus();
    }
    wasOpen.current = open;
    if (!open) return;
    // Escape closes; Tab cycles through the toggle and the drawer's links
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") { setOpen(false); return; }
      if (e.key !== "Tab") return;
      const items = [toggleRef.current, ...(sideRef.current?.querySelectorAll<HTMLElement>("a[href]") ?? [])].filter(Boolean) as HTMLElement[];
      const i = items.indexOf(document.activeElement as HTMLElement);
      const next = e.shiftKey ? (i <= 0 ? items.length - 1 : i - 1) : (i === items.length - 1 ? 0 : i + 1);
      e.preventDefault();
      items[next].focus();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  const current = items.find((i) => pathname.startsWith(`/papers/${i.slug}`));
  const crumb = current ? `${current.short}: ${current.title}` : "Overview";

  return (
    <div className="shell">
      <a href="#main" className="skip-link">Skip to content</a>
      <header className="mobile-bar">
        <Link href="/" className="brand" aria-label="YonedaRepo Research home">
          <img src="/brand/mark.svg" alt="" width={34} height={34} />
          <span className="brand-name">YonedaRepo Research</span>
        </Link>
        <button ref={toggleRef} type="button" className="icon-btn" aria-label={open ? "Close menu" : "Open menu"} aria-expanded={open} aria-controls="sidebar" onClick={() => setOpen(!open)}>
          {open ? <CloseIcon /> : <MenuIcon />}
        </button>
      </header>
      {open && <div className="scrim" onClick={() => setOpen(false)} />}
      <aside id="sidebar" ref={sideRef} className={`sidebar${open ? " open" : ""}`}>
        <Link href="/" className="brand brand-lg">
          <img src="/brand/mark.svg" alt="" width={40} height={40} />
          <span>
            <strong>YonedaRepo Research</strong>
            <small>{series}</small>
          </span>
        </Link>
        <nav aria-label="Papers" className="side-nav">
          <div className="side-label">Papers</div>
          {items.map((it) =>
            it.published ? (
              <Link key={it.slug} href={`/papers/${it.slug}/`} className={`side-link${current?.slug === it.slug ? " active" : ""}`} aria-current={current?.slug === it.slug ? "page" : undefined}>
                <span className="side-part">{it.short}</span>
                <span className="side-title">{it.title}</span>
              </Link>
            ) : (
              <div key={it.slug} className="side-link disabled">
                <span className="side-part">{it.short} <em>In review</em></span>
                <span className="side-title">{it.title}</span>
              </div>
            ),
          )}
        </nav>
        <div className="side-foot">
          <Link href="/#how-it-works">How it works</Link>
          <a href={repoUrl} target="_blank" rel="noreferrer">Source code <ExternalIcon /></a>
          <div className="status"><span className="dot" aria-hidden /> Reference implementation on Cloudflare</div>
        </div>
      </aside>
      <div className="main-col">
        <div className="topbar">
          <nav aria-label="Breadcrumb" className="crumbs">
            <Link href="/">Research</Link>
            <ChevronIcon />
            <strong aria-current="page">{crumb}</strong>
          </nav>
        </div>
        <main id="main">{children}</main>
        <footer className="site-foot">
          <span>Matthew Long &middot; The YonedaAI Collaboration, YonedaAI Research Collective</span>
          <a href={repoUrl} target="_blank" rel="noreferrer">Source on GitHub</a>
        </footer>
      </div>
    </div>
  );
}
