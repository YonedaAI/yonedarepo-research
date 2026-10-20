---
paper: partitioned-derived-data
responds-to: reviews/partitioned-derived-data-review-round-5.md (final Gemini round; cap reached)
date: 2026-10-20
---

# Response to the final review (round 5)

Round 5 verdict: MAJOR REVISIONS, no critical issues. Five rounds were run (rounds 1 to 5); the owner's cap of three rounds was set after round 5 had finished, and a sixth round was stopped before it ran. Every critical and major item from all rounds was fixed in the paper or is answered below.

## Round 4 major items

| # | item | action |
|---|---|---|
| 1 | Prop 9.4 (codemod retry key) false under Repair (b): key omits the partition prefix | Fixed. The digest now covers (find, replace, prefix, grant, p) with length-prefixed encoding; the proof explains why p is needed (Section 9). |
| 2 | Prop 8.1 (blame fold) ignores the 200-version window and the 5,000-commit cap | Fixed. The proposition is stated for the complete first-parent version sequence; the text explains that the windowed blame is not an update of the parent's and that memoizing the untruncated fold removes the window (Section 8). |
| 3 | Root-files key omits file modes | Fixed. Section 3 states that the listing omits modes, that this suffices for search and symbols, and that a mode-dependent kind needs modes; Section 5 names the mode-only change as a second source of strict inclusion in Prop 5.7. |
| 4 | "Ordered by prefix" ambiguous for the root-files prefix | Fixed. Definition 3.1 defines the canonical order (directory partitions in tree-entry order, root-files partition last), and Definitions 3.2 and 4.3 use it. |

## Changes after the last round (no Gemini review)

- New Section 13, "Git as a derived view" (owner request): Definition 13.1, Lemma 13.2 (determinism of the projection), Proposition 13.3 (incremental projection), measured projection lag M200/M201 at dd6c9a8 (branch claude/native-p95e). Each proof step was checked by hand against team/formal-foundations.md and Part I, Proposition 4.3. Three code-evidence rows added at dd6c9a8.
- Evolution paragraph and the change-log duplicate case (M185, I8 at 3cc14b1).

## Round 5 major items

| # | item | action |
|---|---|---|
| 1 | DBSP Z-set equation does not describe what the parent-recursive evaluator computes | Fixed. The text now shows both sides equal map_f(Pi(c)) as Z-sets, explains that the literal right side would re-evaluate f on removed partitions, and that the evaluator reaches the same Z-set by deleting those rows by prefix and key. Z-sets are unordered; canonical order is restored afterwards. |
| 2 | Step 3 does not say how members of a feed component are ordered; why feed cycles are staged, not joined | Fixed. Step 3 now orders members of one component by input position, and every choice depends only on input positions. A new paragraph explains that joining is reserved for written reference cycles, while a feed cycle between declared sets is broken by choosing an order. |
| 3 | Constant k undefined; proof assumes queries never rebuild | Fixed. Prop 11.1 now assumes queries find every segment built by a job, and defines k >= 0 as the derivation cost independent of g. |
| 4a | Prefix-defect consequences in the TypeScript adapter not executed in workerd | Answered. The yonedarepo repository is read-only for this work, and running the workerd suite requires writing a test there. The core of the defect (equal keys, different segments) was executed against the Rust crates at cfa4845 (Appendix B). The paper states plainly that the adapter consequences were traced by reading and not run, and names the workerd test that would confirm them (Limitations). |
| 4b | Seed figures from a commit message appear in Table 4 | Fixed. The rows were removed from Table 4; the figures stay in Section 8 prose with the commit-message caveat. |
| 5 | Orphan paragraphs, multi-claim paragraphs, median vs p95 comparison | Fixed. Eleven short paragraphs were merged; the Gallai-Hasse-Roy-Vitaver paragraph was split from the planner-order paragraph; the derivation phase is now compared by p95 (335 and 367 ms) with the commit p95. |

## Items declined across rounds, with reasons

| item (rounds) | reason |
|---|---|
| Use en dashes in bibliography page ranges (1-5) | The house humanizer rule forbids en dashes; paper-format.md specifies hyphens in page ranges. |
| Remove the unused cleveref (and graphicx) packages (1-5) | Both are in the mandatory preamble skeleton of paper-format.md. cleveref mislabels amsthm environments that share a counter in this TeX installation, so references use explicit names. |
| Remove the Commit column from the evidence appendix (4, 5) | The worker brief requires the columns claim, file path, commit, what the code shows. One row now names a different commit (3cc14b1). |
| Add local microbenchmarks of index_partition, segment size and plan time (3) | Every YonedaRepo number must come from the measured-figures ledger (team/numbers.md); none exists for these quantities. The paper reports them as not measured and defers to Part III, Section 9 (planned evaluation). |
| Restate Part I's results fully (3) | Part I is a sibling paper in the same series. The four results used (P1 to P4) are now stated in Section 2 in the form the proofs use, with exact Part I numbers. |
