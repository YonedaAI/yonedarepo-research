"use client";
import { useEffect, useState } from "react";
import { ListIcon } from "./Icons";

type H = { id: string; num: string; text: string; level: number };

export function Toc({ headings }: { headings: H[] }) {
  const [activeId, setActiveId] = useState("");
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      const y = window.scrollY + 100;
      let current = "";
      for (const { id } of headings) {
        const el = document.getElementById(id);
        if (el && el.getBoundingClientRect().top + window.scrollY <= y) current = id;
      }
      setActiveId(current);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, [headings]);

  return (
    <nav className={`toc${open ? " open" : ""}`} aria-label="Contents">
      <button type="button" className="toc-toggle" aria-expanded={open} onClick={() => setOpen(!open)}>
        <ListIcon /> Contents
      </button>
      <div className="toc-list">
        <div className="toc-heading">Contents</div>
        {headings.map(({ id, num, text, level }) => (
          <a key={id} href={`#${id}`} onClick={() => setOpen(false)} className={`toc-item${level === 3 ? " toc-sub" : ""}${activeId === id ? " toc-active" : ""}`}>
            {num && <span className="toc-num">{num}</span>}
            {text}
          </a>
        ))}
      </div>
    </nav>
  );
}
