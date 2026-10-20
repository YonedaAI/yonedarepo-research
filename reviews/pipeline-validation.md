# Pipeline validation

Date: 2026-10-20. Project: /Users/mlong/Documents/Development/yonedarepo-research

## 1. OG images and live URLs

- PASS website/public/og/home.png: 1200x630, 85307 B, std 0.139
- PASS website/public/og/synthesis.png: 1200x630, 84711 B, std 0.138
- PASS website/public/og/transaction-log-source-control.png: 1200x630, 76199 B, std 0.128
- PASS website/public/og/partitioned-derived-data.png: 1200x630, 60397 B, std 0.115
- PASS website/public/og/serverless-git-on-cloudflare.png: 1200x630, 81261 B, std 0.137
- PASS live /og/{home,synthesis,transaction-log-source-control,partitioned-derived-data,serverless-git-on-cloudflare}.png: 200
- FAIL website/public/og/og-default.png: missing locally (required by Artifacts check); live /og/og-default.png returns 404

## 2. .vercel-url and live pages

- PASS .vercel-url: https://yonedarepo-research.vercel.app, plain ASCII, no punycode, starts with project name, no trailing junk
- PASS root https://yonedarepo-research.vercel.app/: 200, no redirect (no SSO 302)
- PASS /papers/{synthesis, transaction-log-source-control, partitioned-derived-data, serverless-git-on-cloudflare}/: 200 each
- PASS /papers/{slug}.pdf: 200, application/pdf, each slug

## 3. Artifacts

- PASS papers/pdf/*.pdf: 4 files (synthesis, transaction-log-source-control, partitioned-derived-data, serverless-git-on-cloudflare)
- PASS each PDF newer than its papers/latex/*.tex (by mtime)
- PASS images/*.png: 4 covers present
- PASS reviews/{slug}-review.md and {slug}-response.md for all 4 slugs
- PASS reviews/style-check.md: RESULT: CLEAN
- PASS reviews/human-readable-check.md: RESULT: CLEAN
- PASS README.md site link matches .vercel-url
- PASS .knowledge-base.md, posts/
- FAIL website/theme.json: missing (not found anywhere in the tree)

## 4. GitHub repo

- PASS gh api: private=false, visibility=public, default branch main
- PASS git ls-files (110 tracked files): no sources/internal/, team/, .knowledge-base.md, *codex-review*, *code-audit*, .env, or sources/**/*.pdf. Only sources/README.md is tracked under sources/.

## 5. Proposed Slack message

- PASS bare-URL lint: none
- PASS angle-bracket lint: none
- PASS bleed lint (link followed by bold marker): none
- PASS bold balance: all lines balanced
- PASS URLs: website and GitHub each on their own bold-label line as markdown links
- PASS numbers vs README: 26+35+36+35 = 132 pages; 128 SUPPORTS (33+44+39+12); p95 ranges 714 to 1,673 ms, 1,140 to 1,614 ms, Git delay 3.2 to 5.4 s match README
- NOTE: "0 critical items" for Parts II and III is not stated in README. It is supported by reviews/serverless-git-on-cloudflare-review.md (empty Critical Issues section). Not a mismatch, but README does not back it.

## 6. Style and format gate

- PASS filler/signposting grep: 0 hits in all 4 .tex
- PASS abstract word counts: 249, 211, 248, 248 (range 150-250)
- PASS abstract is one paragraph (0 breaks in all 4)
- PASS body size: 11pt in all 4
- PASS \maketitle present in all 4
- FAIL margin=1in in all 4 .tex (line 6 of each: \usepackage[margin=1in]{geometry}). Spec forbids it; must use the paper-format.md geometry (6.5in measure is not allowed).

=== PIPELINE VALIDATOR SUMMARY ===
OG IMAGES:       FAIL  (5 checked, 0 failed; og-default.png missing and 404 live)
SLACK MESSAGE:   PASS  (0 rules failed)
VERCEL URL:      PASS  (https://yonedarepo-research.vercel.app)
ARTIFACTS:       FAIL  (10 required, 2 missing: website/public/og/og-default.png, website/theme.json)
STYLE/FORMAT:    FAIL  (4 papers, 4 failing: margin=1in)

OVERALL: FAIL

VALIDATION: FAIL

Issues:
1. Style/format: all 4 .tex use \usepackage[margin=1in]{geometry} (line 6). Switch to paper-format.md geometry, recompile, re-run Phase 6 conversion for each paper.
2. website/public/og/og-default.png missing locally; live /og/og-default.png returns 404. Restore it.
3. website/theme.json missing.
4. Slack message: lint and numbers pass. Re-run validation after fixes 1-3 (and the PDFs regenerate, so re-check the PDF mtimes).
