# Response to review: machine-checked-batch-landing

Gemini 4 Argon (Medium), 1 round. Verdict: MINOR REVISIONS (0 critical, 0 major, 6 minor). The loop ends on MINOR REVISIONS; every minor item is fixed below.

| # | Item | Fix |
|---|---|---|
| 1 | 1-based prose vs 0-based Lean positions | Sec 2.4 now states that versions b < u <= v are positions b <= i < v; Sec 2.9 spells out the write-read and read-write conditions in Lean positions (i + 1 <= ej.base, ei.base <= j). |
| 2 | Fallback asymmetry of merge3State and landOn | Sec 2.6 explains that neither fallback affects a result: a conflict path lies in the change's write set, and every theorem about M assumes no conflict path. (The reviewer's suggested reason, that the fallback is needed for confinement, is not accurate, so it was not used.) |
| 3 | Helpers used in listings without a listing | Sec 10 now says the core definitions are shown and describes Outcome.clean, Coarsens, CoarsensAll, WritesDisjoint, Txn.write1, Txn.assign and Txn.patch in prose. |
| 4 | Proof fields elided in Txn.changeset | Sec 2 intro states that proof fields of structure instances are omitted unless a short proof is an argument of a definition. |
| 5 | Grab-bag paragraphs (Sec 2.2, 8.5, 9) | Sec 2.2 split, leading with the agreement claim; Sec 8.5 removed and its three remarks moved next to Thm 3.2, Thm 3.5 (already present) and Cor 5.2; the Limits paragraph split into two paragraphs with one claim each. |
| 6 | Caption period; tightness sentence | Period removed from the build listing caption; the tightness sentence rewritten in two sentences. |
| W1-W3 | Weakest paragraphs | All three rewritten as above. |

## Codex format loop
Round 1 NEEDS_FIX (1 issue: `\qed` outside a proof environment in Theorem 5.1); fixed. Round 2 PASS.

## Code audit (3 calls, cap)
- Round 1: 42/46 SUPPORTS. PARTIAL rows 27, 36, 43, 44: claims narrowed (line refinement claim no longer mentions FileConflict; the witness rows describe exactly what the statements contain); `batch_write_skew` added as its own listing so Proposition 5.3's Rebase claim is backed by a statement.
- Round 2: 43/47 SUPPORTS. PARTIAL rows 37, 44, 45, 46: row 37 now says position 1 reaches itself; the batch-witness prose no longer asserts m2's outcome; the witness prose says the premises are discharged inside the proofs; `refs_unchanged_no_entry` added to the refs listing.
- Round 3: 46/47 SUPPORTS. PARTIAL row 42: the cell omitted the hypothesis that W_j is non-empty. Fixed after the cap by adding "a non-empty write set" to the cell; this fix was not re-audited (3-call limit).
