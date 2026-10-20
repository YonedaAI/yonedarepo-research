#!/usr/bin/env node
// Converts papers/latex/<slug>.tex into website content.
//   pandoc -> docs/papers/<slug>.html (raw)  ->  sanitize + KaTeX (build time)  ->  website/content/<slug>.html
// Re-run after editing a .tex or adding a paper to PAPERS. Needs pandoc, pdflatex, pdftocairo.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const WEB = path.join(ROOT, 'website');
const require = createRequire(path.join(WEB, 'package.json'));
const katex = require('katex');
const DOMPurify = require('isomorphic-dompurify');

// Order = series order. A paper is "published" when released !== false and papers/pdf/<slug>.pdf exists.
const PAPERS = [
  { slug: 'synthesis', part: 'Overview: start here', short: 'Overview' },
  { slug: 'transaction-log-source-control', part: 'Part I', short: 'Part I' },
  { slug: 'partitioned-derived-data', part: 'Part II', short: 'Part II' },
  { slug: 'serverless-git-on-cloudflare', part: 'Part III', short: 'Part III' },
];

const DIRS = {
  tex: path.join(ROOT, 'papers/latex'),
  pdf: path.join(ROOT, 'papers/pdf'),
  docs: path.join(ROOT, 'docs/papers'),
  build: path.join(ROOT, '.build'),
  content: path.join(WEB, 'content'),
  figures: path.join(WEB, 'public/figures'),
  pdfOut: path.join(WEB, 'public/papers'),
};
for (const d of Object.values(DIRS)) fs.mkdirSync(d, { recursive: true });

const THM = ['theorem', 'proposition', 'lemma', 'corollary', 'definition', 'assumption', 'example', 'remark'];
const THM_RE = THM.join('|');

// ---------- TeX helpers ----------
function readGroup(s, i) {
  // s[i] === '{' ; returns [inner, indexAfterClosing]
  let depth = 0;
  for (let j = i; j < s.length; j++) {
    const c = s[j];
    if (c === '\\') { j++; continue; }
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) return [s.slice(i + 1, j), j + 1]; }
  }
  throw new Error('unbalanced group at ' + i + ': ' + s.slice(i, i + 60));
}
function skipWs(s, i) { while (i < s.length && /\s/.test(s[i])) i++; return i; }

// Replace \name{arg} (optionally with [opt]) using fn(arg, opt)
function replaceCmd(s, name, fn) {
  const re = new RegExp('\\\\' + name + '(?![A-Za-z])', 'g');
  let out = '', last = 0, m;
  while ((m = re.exec(s))) {
    let i = skipWs(s, m.index + m[0].length);
    let opt = null;
    if (s[i] === '[') { const e = s.indexOf(']', i); opt = s.slice(i + 1, e); i = skipWs(s, e + 1); }
    if (s[i] !== '{') continue;
    const [arg, end] = readGroup(s, i);
    out += s.slice(last, m.index) + fn(arg, opt);
    last = end; re.lastIndex = end;
  }
  return out + s.slice(last);
}

function stripComments(s) {
  const keep = [];
  s = s.replace(/\\begin\{lstlisting\}[\s\S]*?\\end\{lstlisting\}/g, (m) => { keep.push(m); return `@@LST${keep.length - 1}@@`; });
  s = s.replace(/(^|[^\\])%.*$/gm, '$1');
  return s.replace(/@@LST(\d+)@@/g, (_, n) => keep[+n]);
}

function parseAux(slug) {
  // fresh aux from two pdflatex passes in .build (papers/latex may not hold one)
  const dir = path.join(DIRS.build, 'aux-' + slug);
  fs.mkdirSync(dir, { recursive: true });
  fs.copyFileSync(path.join(DIRS.tex, slug + '.tex'), path.join(dir, slug + '.tex'));
  for (let i = 0; i < 2; i++) {
    try { execFileSync('pdflatex', ['-interaction=nonstopmode', slug + '.tex'], { cwd: dir, stdio: 'ignore' }); } catch { /* aux still written */ }
  }
  const aux = path.join(dir, slug + '.aux');
  const labels = {}, cites = {};
  if (!fs.existsSync(aux)) { console.warn(`  ! no ${slug}.aux; cross-references will be unresolved`); return { labels, cites }; }
  const txt = fs.readFileSync(aux, 'utf8');
  for (const m of txt.matchAll(/^\\newlabel\{([^}]+)@cref\}\{\{\[([a-z]+)\]\[[^\]]*\]\[[^\]]*\]([^}]*)\}/gm)) {
    labels[m[1]] = { type: m[2], num: m[3] };
  }
  for (const m of txt.matchAll(/^\\bibcite\{([^}]+)\}\{([^}]+)\}/gm)) cites[m[1]] = m[2];
  return { labels, cites };
}

// KaTeX macros from \newcommand / \DeclareMathOperator in a preamble
const SKIP_MACROS = new Set(['code', 'UrlFont', 'UrlBreaks', 'path']);
function extractMacros(preamble) {
  const macros = {
    '\\slashed': '\\not{#1}',
    '\\bra': '\\langle #1|', '\\ket': '|#1\\rangle', '\\braket': '\\langle #1\\rangle',
    '\\Hom': '\\operatorname{Hom}', '\\Tr': '\\operatorname{Tr}', '\\Lan': '\\operatorname{Lan}', '\\Ran': '\\operatorname{Ran}',
    '\\textunderscore': '\\_', '\\allowbreak': '',
  };
  const re = /\\(?:re)?newcommand\*?|\\DeclareMathOperator\*?|\\DeclareRobustCommand/g;
  let m;
  while ((m = re.exec(preamble))) {
    const star = m[0].endsWith('*') && m[0].includes('Operator');
    let i = skipWs(preamble, m.index + m[0].length);
    let name;
    if (preamble[i] === '{') { const [n, e] = readGroup(preamble, i); name = n.trim(); i = skipWs(preamble, e); }
    else { const mm = /^\\[A-Za-z]+/.exec(preamble.slice(i)); if (!mm) continue; name = mm[0]; i = skipWs(preamble, i + name.length); }
    if (!name.startsWith('\\') || SKIP_MACROS.has(name.slice(1))) continue;
    let nargs = 0;
    if (preamble[i] === '[') { const e = preamble.indexOf(']', i); nargs = +preamble.slice(i + 1, e); i = skipWs(preamble, e + 1); }
    if (preamble[i] !== '{') continue;
    const [body] = readGroup(preamble, i);
    macros[name] = m[0].includes('Operator') ? `\\operatorname${star ? '*' : ''}{${body}}` : body;
    void nargs;
  }
  return macros;
}

function texToPlain(t) {
  return t.replace(/\\emph\{([^}]*)\}/g, '$1').replace(/\\(normalsize|small|large)\b/g, '').replace(/\\\\(\[[^\]]*\])?/g, ' ').replace(/[{}]/g, '').replace(/\s+/g, ' ').trim();
}

// ---------- tikz figures ----------
function renderTikz(slug, tikz, idx, macroPreamble) {
  const name = `${slug}-fig${idx}`;
  const dir = path.join(DIRS.build, name);
  fs.mkdirSync(dir, { recursive: true });
  const tex = `\\documentclass[border=6pt]{standalone}
\\usepackage[T1]{fontenc}\\usepackage{lmodern}\\usepackage{amsmath,amssymb}\\usepackage{tikz}
\\usetikzlibrary{arrows.meta,positioning}
\\newcommand{\\code}[1]{{\\def\\_{\\textunderscore}\\texttt{#1}}}
${macroPreamble}
\\begin{document}
${tikz}
\\end{document}
`;
  fs.writeFileSync(path.join(dir, 'fig.tex'), tex);
  execFileSync('pdflatex', ['-interaction=nonstopmode', '-halt-on-error', 'fig.tex'], { cwd: dir, stdio: 'ignore' });
  execFileSync('pdftocairo', ['-svg', 'fig.pdf', path.join(DIRS.figures, name + '.svg')], { cwd: dir });
  return `/figures/${name}.svg`;
}

// ---------- preprocess one paper ----------
function preprocess(slug) {
  const raw = fs.readFileSync(path.join(DIRS.tex, slug + '.tex'), 'utf8');
  const src = stripComments(raw);
  const bd = src.indexOf('\\begin{document}');
  const preamble = src.slice(0, bd);
  const doc = src.slice(bd + '\\begin{document}'.length, src.lastIndexOf('\\end{document}'));
  const macros = extractMacros(preamble);
  const mathDefs = [...preamble.matchAll(/\\(?:newcommand|DeclareMathOperator)\*?\{[^\n]*$/gm)]
    .map((m) => m[0]).filter((l) => !/\\(code|UrlFont)\b/.test(l)).join('\n');

  // metadata
  const ti = preamble.indexOf('\\title{');
  const [titleRaw] = readGroup(preamble, ti + '\\title'.length);
  const [mainT, ...restT] = titleRaw.split('\\\\');
  const title = texToPlain(mainT);
  const subtitle = texToPlain(restT.join(' ').replace(/^\s*\[[^\]]*\]/, ''));
  const am = preamble.indexOf('\\author{');
  const [authorRaw] = readGroup(preamble, am + '\\author'.length);
  const author = texToPlain(authorRaw.split('\\\\')[0]);
  const date = texToPlain(preamble.match(/\\date\{([^}]*)\}/)?.[1] ?? '');

  // abstract
  const a0 = doc.indexOf('\\begin{abstract}'), a1 = doc.indexOf('\\end{abstract}');
  const abstractTex = doc.slice(a0 + '\\begin{abstract}'.length, a1).trim();
  let body = (doc.slice(0, a0) + doc.slice(a1 + '\\end{abstract}'.length)).replace('\\maketitle', '');

  const { labels, cites } = parseAux(slug);

  // env type of each theorem-like label (cleveref reports "Theorem" for every shared-counter env)
  const envOf = {};
  {
    const stack = [];
    for (const m of body.matchAll(new RegExp(`\\\\(begin|end)\\{(${THM_RE})\\}|\\\\label\\{([^}]+)\\}`, 'g'))) {
      if (m[1] === 'begin') stack.push(m[2]);
      else if (m[1] === 'end') stack.pop();
      else if (stack.length) envOf[m[3]] = stack[stack.length - 1];
    }
  }

  const transform = (s, isBody) => {
    // verbatim-ish macros -> \verb
    for (const name of ['code', 'path', 'nolinkurl']) {
      s = replaceCmd(s, name, (arg) => {
        const txt = arg.replace(/\\l?dots\b\s*/g, '…').replace(/\\textunderscore\s*/g, '_').replace(/\\allowbreak\s*/g, '').replace(/\\textbackslash\s*/g, '\\').replace(/\\([_#%&${}])/g, '$1');
        const d = ['|', '!', '+', '~', '^', '@', ';'].find((c) => !txt.includes(c));
        return `\\verb${d}${txt}${d}`;
      });
    }
    // \newline in cells
    s = s.replace(/\\newline\b/g, ' ');
    // cross references
    const typeName = (k) => {
      const l = labels[k]; if (!l) return null;
      if (envOf[k] && l.type === 'theorem') return envOf[k][0].toUpperCase() + envOf[k].slice(1);
      return { section: 'Section', subsection: 'Section', subsubsection: 'Section', appendix: 'Appendix', subappendix: 'Appendix', table: 'Table', figure: 'Figure', equation: 'Eq.', paragraph: 'Section' }[l.type] ?? 'Section';
    };
    const link = (k) => {
      const l = labels[k];
      if (!l) { console.warn(`  ! unresolved label ${k}`); return '??'; }
      return `\\href{\\#${k}}{${l.type === 'equation' ? '(' + l.num + ')' : l.num}}`;
    };
    const plural = (t) => (t === 'Eq.' ? 'Eqs.' : t === 'Section' ? 'Sections' : t + 's');
    const cref = (arg) => {
      const keys = arg.split(',').map((x) => x.trim());
      const groups = [];
      for (const k of keys) {
        const t = typeName(k);
        const g = groups[groups.length - 1];
        if (g && g.t === t) g.keys.push(k); else groups.push({ t, keys: [k] });
      }
      const join = (xs) => (xs.length <= 1 ? xs.join('') : xs.slice(0, -1).join(', ') + ' and ' + xs[xs.length - 1]);
      return join(groups.map((g) => `${g.keys.length > 1 ? plural(g.t) : g.t}~${join(g.keys.map(link))}`));
    };
    s = replaceCmd(s, 'cref', cref);
    s = replaceCmd(s, 'Cref', cref);
    s = replaceCmd(s, 'eqref', (arg) => link(arg.trim()).replace(/^(\\href\{[^}]*\}\{)\(?([^)}]*)\)?\}$/, '$1($2)}'));
    s = replaceCmd(s, 'ref', (arg) => link(arg.trim()).replace(/^(\\href\{[^}]*\}\{)\(([^)}]*)\)\}$/, '$1$2}'));
    s = replaceCmd(s, 'cite', (arg, opt) => {
      const parts = arg.split(',').map((k) => k.trim()).map((k) => {
        if (!cites[k]) { console.warn(`  ! unresolved cite ${k}`); return '?'; }
        return `\\href{\\#bib-${k}}{${cites[k]}}`;
      });
      return `[${parts.join(', ')}${opt ? ', ' + opt : ''}]`;
    });
    return s;
  };

  // numbering + theorem headings (single ordered pass over sections and theorem openings)
  let sec = 0, thm = 0, inApp = false;
  const secLabel = () => (inApp ? String.fromCharCode(64 + sec) : String(sec));
  const numberPass = (s) => {
    let out = '', last = 0, m;
    const re = new RegExp(`\\\\section(\\*?)\\{|\\\\begin\\{(${THM_RE})\\}`, 'g');
    while ((m = re.exec(s))) {
      if (m[0].startsWith('\\section')) { if (!m[1]) { sec++; thm = 0; } continue; }
      let i = m.index + m[0].length, name = null;
      if (s[i] === '[') {
        let d = 0, j = i;
        for (; j < s.length; j++) {
          const c = s[j];
          if (c === '\\') { j++; continue; }
          if (c === '{') { const [, e] = readGroup(s, j); j = e - 1; continue; }
          if (c === '[') d++;
          else if (c === ']') { d--; if (d === 0) break; }
        }
        name = s.slice(i + 1, j); i = j + 1;
      }
      thm++;
      const env = m[2];
      const label = `${env[0].toUpperCase() + env.slice(1)} ${secLabel()}.${thm}`;
      out += s.slice(last, m.index) + `\\begin{${env}}\\textbf{${label}}${name ? ` (${name})` : ''}. `;
      last = i; re.lastIndex = i;
    }
    return out + s.slice(last);
  };

  body = body.replace('\\appendix', '\\section*{APPENDIXMARKER}');
  // handle appendix switch inside numbering pass
  {
    const [pre, post] = body.split('\\section*{APPENDIXMARKER}');
    body = numberPass(pre);
    if (post !== undefined) { sec = 0; inApp = true; body += '\\section*{APPENDIXMARKER}' + numberPass(post); }
  }

  // tables
  const colCount = (spec) => {
    let n = 0, i = 0; const al = [];
    while (i < spec.length) {
      const c = spec[i];
      if ('@>!<'.includes(c)) { const [, e] = readGroup(spec, i + 1); i = e; continue; }
      if ('lcrXY'.includes(c)) { n++; al.push(c === 'r' ? 'r' : c === 'c' ? 'c' : 'l'); i++; continue; }
      if ('pmbL'.includes(c)) { const [, e] = readGroup(spec, i + 1); n++; al.push('l'); i = e; continue; }
      i++;
    }
    return al.join('');
  };
  {
    let out = '', last = 0;
    const re = /\\begin\{tabularx\}/g; let m;
    while ((m = re.exec(body))) {
      const [, e1] = readGroup(body, skipWs(body, m.index + m[0].length));
      const [spec, e2] = readGroup(body, skipWs(body, e1));
      out += body.slice(last, m.index) + `\\begin{tabular}{${colCount(spec)}}`;
      last = e2;
    }
    body = out + body.slice(last);
  }
  body = body.replace(/\\end\{tabularx\}/g, '\\end{tabular}');
  body = body.replace(/\\begin\{(small)\}|\\end\{(small)\}/g, '');
  // longtable -> table + tabular (pandoc repeats \endfirsthead/\endhead blocks as body rows)
  {
    let out = '', last = 0;
    const re = /\\begin\{longtable\}/g; let m;
    while ((m = re.exec(body))) {
      const [spec, e] = readGroup(body, skipWs(body, m.index + m[0].length));
      const end = body.indexOf('\\end{longtable}', e);
      let inner = body.slice(e, end);
      let cap = '', lab = '';
      const ci = inner.indexOf('\\caption');
      if (ci >= 0) {
        const [c, ce] = readGroup(inner, skipWs(inner, ci + '\\caption'.length));
        cap = c;
        const lm = /^\s*\\label\{([^}]+)\}/.exec(inner.slice(ce));
        let rest = inner.slice(ce);
        if (lm) { lab = lm[1]; rest = rest.slice(lm[0].length); }
        inner = rest.replace(/^\s*\\\\/, '');
      }
      const fh = inner.indexOf('\\endfirsthead');
      const header = fh >= 0 ? inner.slice(0, fh) : '';
      let rows = inner;
      for (const k of ['\\endhead', '\\endfoot', '\\endlastfoot']) {
        const i = rows.indexOf(k);
        if (i >= 0 && (k === '\\endhead' || i < 400)) rows = rows.slice(i + k.length);
      }
      if (fh < 0) rows = inner;
      out += body.slice(last, m.index)
        + `\\begin{table}\n\\caption{${cap}}${lab ? `\\label{${lab}}` : ''}\n\\begin{tabular}{${colCount(spec)}}\n${header}${rows.trim()}\n\\bottomrule\n\\end{tabular}\n\\end{table}`;
      last = end + '\\end{longtable}'.length;
    }
    body = out + body.slice(last);
  }

  // bibliography
  body = body.replace(/\\begin\{thebibliography\}\{[^}]*\}([\s\S]*?)\\end\{thebibliography\}/, (_, inner) => {
    const items = inner.split(/\\bibitem\{/).slice(1).map((chunk) => {
      const k = chunk.slice(0, chunk.indexOf('}'));
      const text = chunk.slice(chunk.indexOf('}') + 1).replace(/\\newblock/g, '').replace(/\\small/g, '').trim();
      return `\\begin{refitem}\\label{bib-${k}}\\textbf{[${cites[k] ?? '?'}]} ${text}\n\\end{refitem}`;
    });
    return `\\section*{References}\n${items.join('\n\n')}\n`;
  });

  // tikz figures
  let fig = 0;
  const macroPreamble = mathDefs;
  body = body.replace(/\\begin\{tikzpicture\}[\s\S]*?\\end\{tikzpicture\}/g, (tz) => {
    fig++;
    const url = renderTikz(slug, tz, fig, macroPreamble);
    return `\\includegraphics{${url}}`;
  });

  body = transform(body, true);
  const abstractOut = transform(abstractTex, false);
  const head = mathDefs + '\n';
  return { labels, title, subtitle, author, date, macros, body: head + body, abstractTex: head + abstractOut };
}

// ---------- pandoc + post-process ----------
function pandoc(texPath, outPath) {
  execFileSync('pandoc', [texPath, '--from', 'latex', '--to', 'html5', '--math-method=mathjax', '--number-sections',
    '--shift-heading-level-by=1', '--syntax-highlighting=none', '--wrap=none', '-o', outPath], { stdio: ['ignore', 'inherit', 'inherit'] });
}
const unesc = (s) => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
const slugify = (s) => s.toLowerCase().replace(/<[^>]+>/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

function postprocess(html, macros, labels = {}) {
  // 1. headings: own numbering (appendix letters), toc
  const toc = [];
  let n2 = 0, n3 = 0, n4 = 0, inApp = false;
  html = html.replace(new RegExp(`(<div class="(?:${THM_RE})")>\\n<p>((?:(?!</p>)[\\s\\S])*?)<span id="([^"]+)" data-label="[^"]*"></span>\\s?`, 'g'), '$1 id="$3">\n<p>$2');
  let lastLevel = 2;
  html = html.replace(/<h([2-6])([^>]*)>([\s\S]*?)<\/h\1>/g, (m, lvl, attrs, inner) => {
    lvl = +lvl;
    if (/^\s*APPENDIXMARKER\s*$/.test(inner)) { inApp = true; n2 = 0; return ''; }
    const id = /id="([^"]+)"/.exec(attrs)?.[1];
    inner = inner.replace(/<span class="header-section-number">[^<]*<\/span>\s*/, '');
    if (lvl >= 5) {
      // run-in paragraph headings: keep the outline gap-free
      const level = Math.min(lastLevel + 1, 6);
      return `<p class="run-head" role="heading" aria-level="${level}"${id ? ` id="${id}"` : ''}>${inner}</p>`;
    }
    const unnumbered = /class="[^"]*unnumbered/.test(attrs);
    let num = '';
    if (!unnumbered) {
      if (lvl === 2) { n2++; n3 = 0; n4 = 0; num = inApp ? String.fromCharCode(64 + n2) : String(n2); }
      else if (lvl === 3) { n3++; n4 = 0; num = `${inApp ? String.fromCharCode(64 + n2) : n2}.${n3}`; }
      else { n4++; num = `${inApp ? String.fromCharCode(64 + n2) : n2}.${n3}.${n4}`; }
    }
    lastLevel = lvl;
    const hid = id ?? slugify(inner);
    const text = inner.replace(/<[^>]+>/g, '');
    if (lvl <= 3) toc.push({ id: hid, num, text: unesc(text), level: lvl });
    const label = num ? `<span class="header-section-number">${num}</span> ` : '';
    return `<h${lvl} id="${hid}">${label}${inner}</h${lvl}>`;
  });

  // 2. sanitize (math is still plain text delimiters here), then KaTeX
  html = DOMPurify.sanitize(html, { USE_PROFILES: { html: true, svg: true }, ADD_ATTR: ['target'] });

  const rendered = [];
  let errors = 0;
  html = html.replace(/<span class="math (inline|display)">(?:\\\(|\\\[)([\s\S]*?)(?:\\\)|\\\])<\/span>/g, (m, kind, tex) => {
    let src = unesc(tex);
    const lab = [...src.matchAll(/\\label\{([^}]+)\}/g)];
    if (lab.length) {
      const id = lab[0][1];
      src = `\\htmlId{${id}}{${src.replace(/\\label\{[^}]+\}/g, '')}}` + (labels[id] ? `\\tag{${labels[id].num}}` : '');
    }
    const out = katex.renderToString(src, { displayMode: kind === 'display', throwOnError: false, trust: true, strict: 'ignore', macros: { ...macros } });
    if (out.includes('katex-error')) { errors++; console.warn('  ! KaTeX error in:', unesc(tex).slice(0, 100)); }
    const vis = out.replace(/<math[\s\S]*?<\/math>/g, '').replace(/<[^>]+>/g, '');
    if (/\\/.test(vis)) { errors++; console.warn('  ! raw TeX visible in math:', vis.slice(0, 100)); }
    rendered.push(out);
    return `\u0001${rendered.length - 1}\u0001`;
  });

  // 3. leak check on text with math removed
  const leaks = [];
  const text = unesc(html.replace(/<pre[\s\S]*?<\/pre>|<code[\s\S]*?<\/code>/g, ' ').replace(/<[^>]+>/g, ' ').replace(/\u0001\d+\u0001/g, ' '));
  for (const re of [/\\[A-Za-z]+/g, /\\[({\[]/g, /\$[^$\s][^$]*\$/g, /@@/g, /APPENDIXMARKER/g, /\?\?/g, /\\\\/g]) {
    for (const m of text.matchAll(re)) leaks.push(text.slice(Math.max(0, m.index - 30), m.index + 40).replace(/\s+/g, ' '));
  }
  for (const re of [/class="(tabularx|longtable|small|citation)"/g, /data-reference-type/g, /<img[^>]*src="(?!\/)/g]) {
    for (const m of html.matchAll(re)) leaks.push('html residue: ' + m[0]);
  }

  // 4. caption numbers, figure alt text, wrap tables, restore math
  let tn = 0, fn = 0;
  html = html.replace(/<caption>/g, () => `<caption><strong>Table ${++tn}.</strong> `);
  html = html.replace(/<figure([^>]*)>\s*<img src="([^"]+)">\s*<figcaption>([\s\S]*?)<\/figcaption>/g, (m, a, src, cap) => {
    const alt = unesc(cap.replace(/<[^>]+>/g, '')).split(/\.\s/)[0].replace(/"/g, '&quot;');
    return `<figure${a}><img src="${src}" alt="${alt}" loading="lazy"><figcaption><strong>Figure ${++fn}.</strong> ${cap}</figcaption>`;
  });
  html = html.replace(/<table[\s\S]*?<\/table>/g, (t) => `<div class="table-scroll">${t}</div>`);
  html = html.replace(/\u0001(\d+)\u0001/g, (_, i) => rendered[+i]);
  // sites whose https endpoint is verified to serve the same page
  html = html.replace(/http:\/\/www\.numdam\.org/g, 'https://www.numdam.org');
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]));
  for (const m of html.matchAll(/href="#([^"]+)"/g)) if (!ids.has(m[1])) leaks.push('dangling anchor: #' + m[1]);
  return { html, toc, errors, leaks, mathCount: rendered.length };
}

function pageCount(pdf) {
  try {
    const out = execFileSync('pdfinfo', [pdf], { encoding: 'utf8' });
    return +/Pages:\s+(\d+)/.exec(out)[1];
  } catch {
    const out = execFileSync('mdls', ['-name', 'kMDItemNumberOfPages', '-raw', pdf], { encoding: 'utf8' });
    return +out;
  }
}

// ---------- main ----------
const manifest = [];
let totalErr = 0, totalLeaks = 0;
for (const p of PAPERS) {
  const texFile = path.join(DIRS.tex, p.slug + '.tex');
  if (!fs.existsSync(texFile)) { console.warn(`skip ${p.slug}: no .tex`); continue; }
  console.log(`== ${p.slug}`);
  const pre = preprocess(p.slug);
  const bodyTex = path.join(DIRS.build, p.slug + '.body.tex');
  const absTex = path.join(DIRS.build, p.slug + '.abstract.tex');
  fs.writeFileSync(bodyTex, pre.body);
  fs.writeFileSync(absTex, pre.abstractTex);
  const rawHtml = path.join(DIRS.docs, p.slug + '.html');
  const absHtml = path.join(DIRS.build, p.slug + '.abstract.html');
  pandoc(bodyTex, rawHtml);
  pandoc(absTex, absHtml);

  const main = postprocess(fs.readFileSync(rawHtml, 'utf8'), pre.macros, pre.labels);
  const abs = postprocess(fs.readFileSync(absHtml, 'utf8'), pre.macros, pre.labels);
  const abstractText = unesc(abs.html.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ')).replace(/\s+/g, ' ').trim();

  fs.writeFileSync(path.join(DIRS.content, p.slug + '.html'), main.html);
  fs.writeFileSync(path.join(DIRS.content, p.slug + '.toc.json'), JSON.stringify(main.toc, null, 1));

  const pdfSrc = path.join(DIRS.pdf, p.slug + '.pdf');
  const hasPdf = p.released !== false && fs.existsSync(pdfSrc);
  let pages = null;
  if (hasPdf) { fs.copyFileSync(pdfSrc, path.join(DIRS.pdfOut, p.slug + '.pdf')); }
  else fs.rmSync(path.join(DIRS.pdfOut, p.slug + '.pdf'), { force: true });
  if (fs.existsSync(pdfSrc)) pages = pageCount(pdfSrc);
  manifest.push({
    slug: p.slug, part: p.part, short: p.short, title: pre.title, subtitle: pre.subtitle, author: pre.author, date: pre.date,
    abstract: abstractText, abstractHtml: abs.html, pages, status: hasPdf ? 'published' : 'in-review',
    pdf: hasPdf ? `/papers/${p.slug}.pdf` : null, og: `/og/${p.slug}.png`,
  });
  totalErr += main.errors + abs.errors; totalLeaks += main.leaks.length + abs.leaks.length;
  console.log(`   math spans ${main.mathCount}, katex errors ${main.errors + abs.errors}, leaks ${main.leaks.length + abs.leaks.length}, pages ${pages}`);
  for (const l of [...main.leaks, ...abs.leaks].slice(0, 25)) console.log('   leak:', l);
}
fs.writeFileSync(path.join(WEB, 'papers.json'), JSON.stringify(manifest, null, 2));
console.log(`done: ${manifest.length} papers, ${totalErr} katex errors, ${totalLeaks} leaks`);
if (totalErr || totalLeaks) process.exitCode = 1;
void os;
