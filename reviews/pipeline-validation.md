# Pipeline validation (re-run)

Date: 2026-10-20. Project: /Users/mlong/Documents/Development/yonedarepo-research. Commit under test: 15bb01d (HEAD = origin/main).

## 1. OG images and live URLs

- PASS website/public/og/home.png: 1200x630, 85307 B, std 0.139
- PASS website/public/og/synthesis.png: 1200x630, 84711 B, std 0.138
- PASS website/public/og/transaction-log-source-control.png: 1200x630, 76199 B, std 0.128
- PASS website/public/og/partitioned-derived-data.png: 1200x630, 60397 B, std 0.115
- PASS website/public/og/serverless-git-on-cloudflare.png: 1200x630, 81261 B, std 0.137
- PASS website/public/og/og-default.png: 1200x630, 85307 B, std 0.139 (byte-identical in size and std to home.png; see note)
- PASS live /og/{og-default,home,synthesis,transaction-log-source-control,partitioned-derived-data,serverless-git-on-cloudflare}.png: 200 each

## 2. .vercel-url and live pages

- PASS .vercel-url: https://yonedarepo-research.vercel.app, plain ASCII, no punycode, starts with project name
- PASS root: 200, no SSO redirect
- PASS /papers/{synthesis, transaction-log-source-control, partitioned-derived-data, serverless-git-on-cloudflare}/: 200 each (checked in the first run; not re-fetched this run)
- PASS /papers/{slug}.pdf: 200, application/pdf, each slug (first run)

## 3. Artifacts

- PASS papers/pdf/*.pdf: 4 files
- PASS each PDF newer than its papers/latex/*.tex (re-checked this run; PDFs not regenerated)
- PASS images/*.png: 4 covers
- PASS reviews/{slug}-review.md and {slug}-response.md for all 4 slugs
- PASS reviews/style-check.md: RESULT: CLEAN
- PASS reviews/human-readable-check.md: RESULT: CLEAN
- PASS README.md site link matches .vercel-url
- PASS .knowledge-base.md, posts/
- PASS website/theme.json: exists, valid JSON (keys: name, domain, note, colors, font, heroGradient, cardEffect, bgPattern), committed in 15bb01d
- NOTE: website/theme.json is not served at /theme.json (404). It sits outside website/public/, so this is expected. The artifact check only requires the file to exist.

## 4. GitHub repo

- PASS gh api: private=false, visibility=public
- PASS git ls-files (113 tracked files): no sources/internal/, team/, .knowledge-base.md, *codex-review*, *code-audit*, .env, or sources/**/*.pdf. Only sources/README.md under sources/.
- PASS 15bb01d pushed: local HEAD equals origin/main

## 5. Proposed Slack message

- PASS bare-URL lint: 0 hits
- PASS angle-bracket lint: 0 hits
- PASS bleed lint (link followed by bold marker): 0 hits
- PASS bold balance: 0 unbalanced lines
- PASS URLs: website and GitHub each on their own bold-label line as markdown links
- PASS numbers vs README: 26+35+36+35 = 132 pages; 128 SUPPORTS (33+44+39+12); p95 ranges match README
- NOTE: "0 critical items" for Parts II and III is not stated in README. reviews/serverless-git-on-cloudflare-review.md has an empty Critical Issues section, so it is supported by the review file.

## 6. Style and format gate

- PASS filler/signposting grep: 0 hits in all 4 .tex
- PASS abstract word counts: 249, 211, 248, 248 (range 150-250)
- PASS abstract is one paragraph (0 breaks in all 4)
- PASS body size: 11pt in all 4
- PASS \maketitle present in all 4
- FAIL (spec conflict, not confirmed as a defect): margin rule. The validator spec in this agent's instructions, section E, reads: `grep -q 'margin=1in' "$tex" && { echo "FAIL: $tex uses margin=1in (6.5in measure); use the paper-format.md geometry"; fail=1; }`. All 4 .tex contain `\usepackage[margin=1in]{geometry}` (line 6). The skill file /Users/mlong/.claude/plugins/cache/local-skills/research-agent/0.7.18/references/paper-format.md line 15 uses the same line in its required skeleton, so the rule as written contradicts its own reference. The coordinator's quoted rule (`OK margins` on a match) was not found on disk, so I could not check it. Under the rule as written, this item FAILS. Owner decision needed: confirm margin=1in is the intended geometry and retire the spec rule, or change the geometry.

=== PIPELINE VALIDATOR SUMMARY ===
OG IMAGES:       PASS  (6 checked, 0 failed; og-default.png now present and live)
SLACK MESSAGE:   PASS  (0 rules failed)
VERCEL URL:      PASS  (https://yonedarepo-research.vercel.app)
ARTIFACTS:       PASS  (theme.json and og-default.png now present)
STYLE/FORMAT:    FAIL  (4 papers, 4 failing: margin=1in under the spec rule; likely spec conflict)

OVERALL: FAIL

VALIDATION: FAIL

Issues:
1. Style/format: all 4 .tex use \usepackage[margin=1in]{geometry} (line 6). Literal spec section E rule forbids this. paper-format.md skeleton uses it too. Owner must decide which rule is correct. If margin=1in is correct, retire the rule and this item passes. Do not alter the PDFs until that is settled.
2. Notes (not failures): og-default.png is byte-identical in size and std to home.png. website/theme.json is not served at /theme.json, which is expected.

## Orchestrator resolution (2026-10-20T23:07:38Z)
Item 1 was a contradiction inside research-agent 0.7.18: pipeline-validator.md:197 failed margin=1in, while paper-format.md:15 and :114 require it. Fixed in research-agent 0.7.19 (the validator now requires margin=1in). All 4 papers pass the corrected rule. Items 2-3 were fixed in 15bb01d.

VALIDATION: PASS
