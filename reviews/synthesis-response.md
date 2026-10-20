# Response to review: synthesis

Round 1 (Gemini 4 Argon, Medium), verdict MINOR REVISIONS, 0 critical items. Every item was fixed in `papers/latex/synthesis.tex` except minor 3(a), which is answered below.

| # | Severity | Item | Response |
|---|---|---|---|
| M1 | Major | Theorem 5.1 omits object retention and map determinism | Added Part I Assumption 5.7 as a hypothesis and stated that Part II Assumption 5.2 includes determinism; the proof now says where retention is used. |
| M1 | Major | Proposition 5.2 omits collision resistance and the no-reset discipline | Added a well-formed log, collision-resistant identifiers and "no command deletes or resets the branch" (Part I Section 5.2); the proof explains why a reset would end the first-parent chain. |
| M1 | Major | Proposition 5.3 omits Assumptions 4.14 and 6.2 and validation against the prior log in the deferral case | Added both assumptions and the requirement that every member is validated against the log by Part I Definition 4.15 in both cases. |
| M1 | Major | Proposition 5.4 omits collision resistance and atomic gets | Added collision resistance and stores that return nothing or bytes that hash to the requested identifier. |
| M2 | Major | Merge outcome under closure coverage | Added a paragraph after Proposition 6.1: with path-granularity coverage of edits within the closure, a later write to an edited file is a Conflict; Merge arises only with symbol-granularity reads and refined writes, which is why Assumption 6.2 is a hypothesis. |
| M3 | Major | Signposting and buried claims (Sections 1, 2.4, 4, 7.3, 7.4) | Rewrote the opening of Section 1 to lead with the composed result, Section 1 paragraph 5 and Section 2.4 to lead with their claims, and the Section 4 opening to state what the results instantiate. Split Sections 7.3 and 7.4 so that each paragraph carries one finding before its qualifications. The reviewer's model rewrites used en dashes and "Moreover", which the house style forbids, so the rewrites are our own. |
| m1 | Minor | Signature of W and Phi in Definition 3.1 | W is now a set of file paths that the authority may refine to symbols, R is a set of accesses at path or symbol granularity, and Phi maps each path of W. |
| m2 | Minor | Denominators 990 and 998 | Section 7.4 now says 10 commits failed at the bench client, so 990 writers reached landing; Section 7.5 adds the 2 landings that failed by a storage timeout (4 + 994 + 2 = 1,000); Table 5 says "288 of 990 that committed". |
| m3a | Minor | Replace `everypage` with LaTeX hooks | Not changed. The GrokRxiv sidebar macro is copied verbatim from the Parts so that the series renders identically. |
| m3b | Minor | Notation for Later | Now written as a sequence, (e_u) indexed by b < u <= n with r_u = r. |
| m3c | Minor | Units in Table 5 | Column header now reads "Landing p95 (s)". |

Code audit round 1 (Codex): 10 of 12 rows SUPPORTS. Row 6 now names `store/auth.rs` and `repo_store.rs`, which show the human-owner gate and the refusal; row 11 now states that `accept` records writes only for members routed as a changeset or fast-forward and that merge-path members are adopted and queued.
