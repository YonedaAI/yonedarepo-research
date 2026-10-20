---
paper: transaction-log-source-control
rounds: 3 (round 1 Gemini 4 Argon High; round 2 High; round 3 Medium fallback after two High timeouts)
final verdict: MINOR REVISIONS (round 3: 0 critical, 0 major)
---

# Response to reviews

## Round 1 (MAJOR REVISIONS)
- M1 Theorem 6.4 overstated for Merge outcomes: fixed (Thm 6.4 equivalence restricted to FastForward/Rebase histories; Merge covered by Prop 6.5).
- M2 Prop 7.4 rule enforced only in the adapter: fixed (rule stated over recorded write sets, (R_j ∪ W_j) vs W_i, and placed in the authority's verification; Sec 7.3).
- M3 Location tree underspecified: fixed (Def 4.4 universal tree of all valid locations; content ⊥ for absent locations; directories have no content of their own).
- M4 Reliance on companion papers: fixed (Assumption 5.7 retention and Cor 5.8 stated in Part I; Part II cited only for the vacuum procedure).
- M5 House style in Evidence and Limitations: fixed (paragraphs split, findings first; Sec 10 and Limitations).

## Round 2 (MAJOR REVISIONS)
- C1 Theorem 6.4 hypotheses and c_i vs installed merge commit: fixed (all entries naming r above v0 are single-commit, non-batch landings; m_i distinguished; T(m_i) ⊆ W(c_i) proved; Thm 6.4).
- C2 Prop 7.4 conflated sequential-landing equivalence with conflict-serializability: fixed (Prop 7.4 split into part 1, sequential equivalence, and part 2, conflict-serializability only when no member needed a line merge; refined vs unrefined write sets stated).
- M1 FastForward on stale parents during merge verification: answered (checked at cfa4845: merging.rs::verify accepts only Rebase/Merge, land_queue.rs::verify_octopus accepts FastForward only when the first parent is the head; stated in Sec 6.1 with appendix row 28; residual exposure is a base strictly between the parent's version and the head, Assumption 6.1).
- M2 Sound refinement for platform merge commits: answered (merge commits are prepared by the authority with the head as first parent, so Δ(m) ⊆ T(m); appendix row 29; imports are the stated exception).
- M3 Type mismatch T(c), Δ(c), W(c): fixed (Def 4.2: T(c) is a set of path nodes).
- M4 Series title in sibling bib entries: fixed (Source Code as a Transactional Abstraction).
- M5 Unpreserved local raw output and missing hosted run: fixed in part, answered in part (both hosted runs in Table 4; local figures labeled as reported in commit messages; re-running is not possible because the code repository is read-only for this work).
- M6 Multi-claim paragraphs and signposting: fixed (paragraphs split; signposting sentences removed).

## Round 3 (MINOR REVISIONS; no critical or major items)
- Minor items 1-6 and 8 fixed: revision relationship stated (Sec 3.6 and Appendix A intro); projection renamed Π and changeset χ; 0 ≤ b < v in Def 4.8; T(m_i) containment made explicit in Thm 6.4 proof; local figures labeled in Table 4; unused duplicate labels removed; Row 9 paths shortened.
- Minor item 7 (en dashes in page ranges): answered (house rule forbids en dashes; hyphens kept).
- Three weakest paragraphs rewritten (objects paragraph split; Delta isolation paragraph leads with the finding; local-provenance sentence folded into the evidence paragraph).

## Owner-scope changes applied between rounds
- Cloud-portable framing over abstract primitives; central thesis and evolution paragraph; series title; proof foundations (K-R Sec 4, BHG Thm 2.1, Adya G2-item, Fekete Thm 2.1, Delta isolation levels from source); N11 changeset landing (Sec 3.6, Sec 8; implemented at dd6c9a8 on an unmerged branch); number-rule update (cfa4845-era commit latency relabeled; commit p95 < 1 s at later revisions with caveats; landing as negative result).

## Codex formatting (3 rounds, cap)
- Fixed: centered ellipsis in Thm 6.4; ties in companion references; `API\@.`; url-based `\code` dropped spaces in six instances (now `\texttt`).
- Declined, house rule: en dashes in bibliography page ranges (paper-format.md and the humanizer rule require hyphens). This is the only item behind the final NEEDS_FIX.

## Post-merge update (fef94e7)
- Changeset landing relabeled as merged into dev at fef94e7 (first measured at dd6c9a8); abstract and Sec 3.6 headline: 1,000 of 1,000 landed in each of six hosted bursts (M220, M221).
- Batch write-skew check: c4c8f47 added it; the merged batch path at fef94e7 calls it before routing (appendix row 33); unexercised because the benchmarks write disjoint files.
- Code audit round 2: 33 of 33 rows SUPPORTS, VERDICT PASS.
