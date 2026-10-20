---
paper: serverless-git-on-cloudflare
responds-to: reviews/serverless-git-on-cloudflare-review-round-3.md (Gemini 4 Argon (High), VERDICT: MAJOR REVISIONS)
date: 2026-10-20
note: No further Gemini rounds (owner cap of 3 rounds, orchestrator NOTE 2026-10-20T19:42:32Z). Every round-3 item is addressed below. The paper was also revised for the owner's framing rule, thesis, proof-foundations rule, and the delta ledger (M100-M199).
---

## Critical

1. Double counting of authority queueing in T_c' = T_c + n_c W.
   Fixed. The model now uses the unloaded cycle T_c0 = 1.8 s (measured 2.6 s minus 9 x 90 ms of queueing), with T_c' = T_c0 + n_c W (Assumption 6.6, Sec. 6.3, App. B). The calibration section checks that T_c' at the burst's W reproduces the measured 2.6 s.

2. Unrecorded code state and unexplained failures in H3/H4.
   Addressed as far as the evidence allows: Sec. 5.2 states the inputs are fixed, so the H3 failures arose from server-side state, cause unknown; the deployed revision was not recorded; the runs were not repeated for this paper; the planned evaluation (Sec. 9) begins by repeating them on a recorded revision with tree cleanliness recorded. Threats (Sec. 11) lists the same.

## Major

1. R_0 vs direct CAS vs 1.5 T_c. Fixed: Assumption 6.6 now models the merge fraction f_m = 1 - exp(-X L_c), the busy fraction rho_c = min(1, X T_c'), and the wait T_c'(1 + rho_c/2); R_0 for a single agent is the commit plus one direct CAS (about 1.56 s).
2. C3 notification and lease handoff. Fixed: C3/C4 descriptions state the mechanism (held enqueue reply, answered when the batch lands; oldest held call receives the lease) and the cost assumption; C3 is now the measured non-polling combiner at 03821e0 (code rows in App. A).
3. Agents queued at the authority before polling. Fixed: Definition 6.2 now states that a landing whose enqueue call is queued has exactly one outstanding call and is counted among the pollers.
4. Constant Delta_T vs N. Fixed: Sec. 7 states the condition 1/(5s) <= m_max/T_push(64) under which Delta_T stays constant (132 vs 145 per second, holds); Sec. 8.7 gives the 12.6 to 19.1 s range with both cases.
5. Hybrid latency labelled as p95. Fixed: Table 7 caption and Sec. 8.4 call it the unloaded p95 plus the mean projected authority wait, not a projected percentile; the 1 s statement rests on the unloaded p95 alone.
6. Summed authority waits (483/1,138 ms). Fixed: text now says "the four authority phases before the derive step".
7. Prose. Signposting paragraphs folded or removed (Sec. 3.5 opener, Table 4 lead-in, appendix intro); multi-claim paragraphs split (Sec. 3.5, Sec. 6.3 inputs, Sec. 7 checks, App. B); the inputs paragraph rewritten along the reviewer's model.

## Minor

1. Root existence when U(0) >= 1. Fixed in App. B: domain (W_min, infinity), with the right side decreasing from infinity.
2. Implicit server hypothesis in Proposition 4.2. Fixed: the statement now names per-command independence with no hook or quota coupling refs; quota coupling noted after the proof.
3. Unused packages. Not changed: the preamble is the house skeleton (tikz and xcolor are used by the sidebar).
4. cleveref capitalization. Fixed: theorem-like references are written out ("Lemma~\ref"), and section, table and equation names are capitalized.
5. Table 3 composite rows and dashes. Composite rows now sit below a midrule. En dashes are not used: the house humanizer rule forbids them, so ranges use hyphens in the bibliography and "to" in prose.

## Changes beyond the review

- Owner framing: Sec. 3 is a primitive-to-realization table with another documented realization per primitive (AWS doc URLs verified); Sec. 4 "Realization limits" attributes each limit to a primitive property.
- Thesis and evolution paragraph in the abstract and introduction; series title "Source Code as a Transactional Abstraction".
- Proof foundations: asymptotic bounds and knee cited to Denning-Buzen and QSP, P-K formula to Adan-Resing; derivations dropped; poll corollary fixed to Q* = tau/(p s) per formal-foundations III-7.
- Delta ledger: Table 2 now covers H1-H4, the 4407515 runs (M101), the us-east-1 runs (M191, M113, M114) and the 1,000-writer runs (M110-M112, M116); later-revision commit p95 under 1 s reported with the acceptance-semantics caveat; combiner regression and authority overload reported; projections rebuilt for four code states (C1 early, C2 4407515, C3 03821e0, C4 short-cycle target); Scion comparison carries the non-comparability caveat in the same sentence; N11 targets in the planned evaluation; Git-object landing no longer described as required.

## Round 2 major items

1. Inverted tau and burst contamination: fixed. Definition 6.2 defines tau as the unloaded iteration (sleep plus idle round trips, 0.11 s early, 0.29 s at 4407515); the burst iteration 0.40-0.45 s is reported separately as a check (Sec. 6.3, Sec. 7).
2. M/D/1 used in the saturated regime: answered and narrowed. The P-K formula (Prop. 6.10, cited to Adan-Resing) is used only for the open part of the load below saturation; App. B names the projection solver a fixed-point approximation, not MVA, defines its root on (W_min, infinity), and shows that its large-Q limit is the Corollary 6.12 bound.
3. Cross-check of s without call-count correction: fixed (1.40 and 1.58 ms after removing the three sequential-only calls; Sec. 6.3, App. B).
4. Constant Delta_T at 1,000 writers: fixed (stated condition and 12.6 to 19.1 s range, Sec. 7 and Sec. 8.8).
5. Definition 3.2 contradictions (land order, status reads): fixed (direct CAS first, then enqueue; two or three status reads stated).
6. Prose (signposting, multi-claim paragraphs): fixed as listed under round 3, item 7.

## After the N11 rows (M200-M207)

- New Sec. 5.3 "Changeset landing, measured" with the dd6c9a8 side-by-side matrix (Table 2 rows S1-S6); open problems stated: 422/1000 reads refused, 49.7/s is a burst-span rate short of 50, no sustained run, Git projection lag p95 17.3 s.
- Sec. 8.4 sets projections against the measurements: polling failure predicted (right in direction, wrong in form: refusals, not unbounded delay); combiner ceiling about 11/s bounds the measured 5.9-7.0/s; 49.7/s corresponds to one 128-batch every 2.58 s, against the 2.56 s that 50/s needs.
- The unsupported 1.8 s unloaded cycle and the C4 configuration are removed; C1 and C2 use the measured 2.6 s cycle.
- Code-evidence rows for changeset landing pinned to dd6c9a8 (branch claude/native-p95e).

## Codex formatting, round 2 (one call, as instructed)

1. Space inside \nolinkurl for the Artifacts error: fixed (\texttt{ERR}~\nolinkurl{...}); the PDF had rendered "ERRartifacts_git_receive_pack_busy" and now renders the space.
2. everypage legacy warning: not changed; the GrokRxiv sidebar uses the house template from paper-format.md verbatim, and the compile shows no error.
3. En dashes in page ranges: not changed; the house humanizer rule forbids en dashes and paper-format.md asks for hyphenated ranges.
4. DOIs as plain text: not changed; paper-format.md asks for DOIs and arXiv ids as plain text.

## fef94e7 results (M220-M227)

- New Sec. 5.3 "Batched landing on the development branch, measured" (sec:sgoc:batch): ranges over all six 1,000-writer runs (tokens and shared login), 100-writer runs, burst-span rates with burst lengths, Git projection lag, the authority-read trade-off (M227), and the summary-line provenance of runs 1-2.
- The dd6c9a8 matrix is now "Controlled comparison of landing modes" (Sec. 5.4).
- Sec. 8.4 tests the batch-capacity relation with the measured batch call (256 landings, 308/372 ms): bound 690-830/s against measured 235-491/s burst-span rates.
- Open problems updated: no sustained run, authority reads refused under burst, shared-login commit p95 over 1 s, write skew not exercised, Git lag of several seconds.
- Code audit: rounds 3-4, 39 rows SUPPORTS (row 17 re-pointed to merging.rs at fef94e7). Codex format round 3: PASS.
