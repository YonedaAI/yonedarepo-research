---
reviewer: Gemini 4 Argon (Medium)
paper: machine-checked-batch-landing
round: 1
date: 2026-10-21T01:47:39Z
---


### Summary Evaluation

This paper presents a machine-checked Lean 4 formalization of the transactional source-control model introduced in Part I of the series. The formalization (174 theorems in core Lean 4.35.0, using only `propext` and `Quot.sound`) covers path overlap, tree states, transactions with read/write frames, log snapshots, validation outcomes, three-way merge at file and stable-key line granularities, single-landing serializability, batch landing with merged members under a new *patch compatibility* condition, and degraded guarantees under under-declared reads.

The work is mathematically sound, candid about the boundaries of its model, and well-structured. Its chief technical contribution—identifying *patch compatibility* ($\PC(m,H)$) as the exact necessary and sufficient condition for a conflict-free merged landing to equal serial transaction execution, and extending batch landing soundness to `Merge` members—is clean and well-motivated by concrete, kernel-checked counterexamples. Moreover, the four corrections and sharpenings to Part I (Section 7) demonstrate the concrete value of formalization. Only minor issues in exposition, notation alignment between mathematical prose and Lean listings, and minor prose tightening remain.

---

### Evaluation by Dimension

#### 1. Mathematical Correctness
The mathematical definitions, theorem statements, and proofs match the verbatim Lean 4 listings and are sound.
* **Path algebra and state agreement (Section 2.1–2.2):** Component-wise prefix ancestry (`anc`), comparability (`meets`), subtree coverage (`covered`), and overlap region (`region`) are cleanly defined. The distinction between agreement on $\reg(X)$ and write confinement to $\covd(W)$ is crucial; as Section 7.2 demonstrates, conflating the two breaks the frame lemma when ancestor nodes carry content.
* **Three-way merge and patch compatibility (Sections 2.6, 4.1, 4.3):** Including the same-change clause (`else if o = t then .ok o`) restores idempotence and yields the exact conflict characterization $O(p)\neq B(p) \land T(p)\neq B(p) \land O(p)\neq T(p)$. Theorem 4.3 (`merge_serial_iff`) and Proposition 4.4 (`changeset_patchCompatible_iff`) accurately isolate why blind writes with untouched paths in $\covd(\W)$ can violate serial equivalence when a prior commit modified those paths.
* **Batch soundness (Section 5):** The four-step decomposition (`landBatch_eq_seqLand`, `seqLand_eq_serialMerge`, `serialMerge_eq_serialTxns`, and `snap_append_members` / `noConflict_append_batch`) is completely rigorous.
* **Indexing convention:** There is a minor recurring 0-based (Lean) vs. 1-based (math prose) index translation across Definitions 2.5, 2.11, and Section 3 (detailed under Minor Issues below), though all mathematical claims remain valid once the convention $v = i + 1$ is tracked.

#### 2. Clarity
The paper is unusually clear about what is and is not proved. The pairing of each mathematical definition or theorem with its verbatim Lean declaration eliminates ambiguity about how informal concepts are encoded. The explicit distinction between $\lnd(B,H,C)$ (which falls back to $C(p)$ on conflict) and $\mrg(B,O,T)$ (which falls back to $O(p)$) is stated in Definition 2.7, and the paper clearly notes that all main theorems exclude conflict paths so the fallback choice does not affect the conclusions.

#### 3. Completeness
Within its stated scope, the formalization is comprehensive. Every major theorem is accompanied by both a non-vacuity witness (Section 6) and, where extra hypotheses are introduced, a machine-checked counterexample showing that dropping the hypothesis breaks the theorem (Propositions 4.5, 5.3, 6.3, and Theorem 6.5). Section 8 ( Limits of the formalization) and Table 2 thoroughly account for every result in Parts I–III and the synthesis paper, including what was omitted (positional `diff3`, multi-granularity validation with $\W^\rho$, opaque entries, and the throughput capacity model).

#### 4. Logical Structure
The progression from atomic primitives (Section 2) to single landings (Section 3), merge resolution and patch compatibility (Section 4), batch soundness (Section 5), under-declared reads (Section 6), non-vacuity witnesses (Section 7/6), and findings/limitations (Sections 7–10) is logical and self-contained.

#### 5. LaTeX Quality
The LaTeX source is clean, well-macroed, and free of compilation errors. Custom macros (`\cov`, `\meets`, `\covd`, `\reg`, `\Snap`, `\lnd`, `\mrg`, `\oct`, `\PC`) are used consistently. A few minor typographical details in the listings and tables are noted in the Minor Issues section.

#### 6. Prose Quality and House Style Adherence
The prose closely follows the house style: paragraphs generally open with a direct claim, sentences favour active verbs and concrete nouns, and limitations are stated plainly without defensive hedging. A handful of paragraphs, however, suffer from multi-claim crowding ("grab-bag" paragraphs that bundle three or four distinct points without a unifying claim) or slightly tangled clause subordination.

---

### Three Weakest Paragraphs and Model Rewrite

#### Weakest Paragraph 1 (Lines 169–170)
> Blobs are natural numbers so that concrete examples can be evaluated; any type with decidable equality would serve. Agreement here differs from Part I's relation, which compares the file and symbol locations in $\bigcup_{x\in X}\mathrm{sub}(x)$ and gives directories no content (Part I, Section~4.2). The Lean relation compares every path in the overlap region, including the proper ancestors of each $x$, and the content of a node is independent of the content of its children. When the ancestors of the accessed locations carry no content, as directories do in Part I, the two relations coincide; this is an informal observation, not a Lean theorem. For an access below a file, such as a symbol or a line, the Lean relation also compares the file node itself, and the model does not derive a file's content from its children. The mappings of Part I's results that conclude agreement are therefore adapted rather than literal. The two regions, $\reg$ for agreement and $\covd$ for change, are deliberately different, and Section~\ref{sec:mcbl:findings} shows that making them equal breaks the frame lemma.

*Critique:* This paragraph bundles three distinct topics—the representation of `Blob` as `Nat`, the semantic difference between Lean's `Agree` and Part I's agreement relation, and the asymmetry between $\reg(X)$ and $\covd(W)$—into one paragraph. It opens with a minor implementation detail ("Blobs are natural numbers...") rather than its central claim (how state agreement departs from Part I).

#### Weakest Paragraph 2 (Lines 1098–1099)
> Three further observations sharpen Part I without correcting it. The state equality in merge form needs only the write half of the pairwise rule and the absence of conflict paths; the read half is needed for serial execution of the transactions and for acyclicity. Part I's Theorem~6.7 is an equivalence at the level of validation outcomes; at the level of states the model proves the forward direction only. And FastForward, defined as the absence of later entries, is equivalent to a base equal to the head once the base is capped, which is the form Part I's proof uses.

*Critique:* This is a textbook list-in-prose paragraph with no single identifiable claim; the opening sentence is pure signposting ("Three further observations sharpen Part I..."), followed by three unrelated technical remarks that belong near the respective theorems they qualify (Corollary 5.2, Theorem 3.5, and Theorem 3.2).

#### Weakest Paragraph 3 (Lines 1109–1110)
> Several modelling choices simplify Part I. A conflicting landing falls back to the change's value instead of being refused. The consistent-base assumption holds by construction, and the log starts at version 0 rather than at an arbitrary version. In the Git projection, hashing is abstracted by identifying a commit with the data it encodes, which models content addressing with no collision. Part I's append discipline (Part I, Lemma~5.3), a property of the code, is a hypothesis of the ref results, and so is the ordering of commit generations.

*Critique:* Like Paragraph 2, this paragraph is a miscellaneous catalogue of five unrelated modeling simplifications (conflict fallback, consistent base, initial log index, collision-free hashing, and ref-log hypotheses) held together only by a generic topic label ("Several modelling choices simplify Part I").

#### Model Rewrite (of Weakest Paragraph 1, Lines 169–170)
Split the representation note from the substantive claim about `Agree`, and lead directly with the finding:

> Agreement in the formal model is stronger than in Part I because every node in the location tree can carry independent content. Whereas Part I gives directories no content and compares only file and symbol locations in the subtree $\bigcup_{x\in X}\mathrm{sub}(x)$ (Part I, Section~4.2), the Lean relation `Agree` compares every path in the overlap region $\reg(X)$, including proper ancestors. When ancestors of accessed locations carry no content, the two relations coincide, though for sub-file accesses (symbols or lines) `Agree` also compares the parent file node without deriving its content from its children. Theorems that conclude agreement are therefore adapted rather than literal translations of Part I. Finally, whereas agreement inspects $\reg(X)$, `ChangesWithin` confines writes to the smaller set $\covd(W)$; Section~\ref{sec:mcbl:findings} shows that equating these two regions breaks the frame lemma. (To make concrete witnesses executable, the model represents blobs as natural numbers; any type with decidable equality suffices.)

---

### Structured Feedback

#### Critical Issues
None.

#### Major Issues
None.

#### Minor Issues

1. **1-based prose indexing vs. 0-based Lean indexing (Lines 226–234, 449–469, 476–482, 916–930):**
   * In Definition 2.5 (Lines 226–230), log entries are 1-indexed as $\Log=(e_1,\dots,e_n)$ where entry $e_v$ lands at snapshot $\Snap{v}$ on head $\Snap{v-1}$, whereas the Lean code (`snap`, `validateAt`, `SEdge`, `frame_lemma`) uses 0-indexed list positions $i \in \{0,\dots,n-1\}$ where entry $i$ lands at `snap init log (i + 1)` on head `snap init log i`.
   * While Lines 233 and 453 mention that "Version $v$ is list position $v-1$ in Lean," several prose theorem statements mix or obscure the boundary condition:
     * In Definition 2.11 (Line 450), the read-write serialization edge condition in prose is "$b_u < v$ and $\R_u\meets\W_v$," whereas Listing 17 (Line 461) has `ei.base ≤ j`. Because $j = v - 1$ is 0-indexed while `ei.base` is a snapshot index $b_u$, $b_u \le j \iff b_u \le v - 1 \iff b_u < v$. Adding a half-line parenthetical in Line 453 (`so $u \le b_v$ is $i + 1 \le \mcode{ej.base}$ and $b_u < v$ is $\mcode{ei.base} \le j$`) will save readers from thinking there is an off-by-one discrepancy between Definition 2.11 and Listing 17.
     * Similarly, in Lemma 3.1 (Line 476), prose states "$b < u \le v$" (1-indexed entry $u$) while Listing 18 (Line 481) has `b ≤ i → i < v` (0-indexed position $i$). In Theorem 6.2 (Line 918), prose writes "$i < u \le v$" while Listing 38 (Line 927) writes `i ≤ j ∧ j < v`. A single explicit note in Section 2.4 stating the translation ($u = i + 1$, so $b < u \le v \iff b \le i < v$) would make every subsequent pairing transparent.

2. **Fallback asymmetry between `merge3State` and `landOn` (Lines 300–306, 319–321):**
   * Definition 2.7 defines $\mrg(B,O,T)$ (`merge3State`) with fallback $O(p)$ (ours) on conflict and $\lnd(B,H,C)$ (`landOn`) with fallback $C(p)$ (theirs/change) on conflict. Line 305 explains that no theorem depends on the fallback beyond write confinement (`ChangesWithin`). However, readers may wonder why two separate functions (`merge3State` and `landOn`) with opposite conflict fallbacks exist in the codebase at all, given that on conflict-free states $\lnd(B,H,C) = \mrg(B,H,C)$. Note briefly in Line 305 that `landOn` defaults to $C(p)$ so that `snap_step_changesWithin` holds unconditionally (since $C(p) = B(p)$ outside $\covd(\W)$, whereas $O(p)$ need not equal $C(p)$ on conflict inside $\covd(\W)$).

3. **Implicit helper definitions in Lean listings (Lines 289, 601, 862, 1012):**
   * Listing 8 (Line 289) uses `(validateAt ...).clean = true`, Listing 24 (Line 601) uses `Coarsens` and `CoarsensAll`, Listing 32 (Line 806) uses `WritesDisjoint`, Listing 35 (Line 862) uses `Txn.write1`, and Listing 42 (Line 1012) uses `Txn.patch`. Their meanings are clear from context and the surrounding prose, but since Section 8 (Line 1120) states that "this paper shows every definition the main theorems depend on," it would be more exact to say "shows the core definitions and states the remaining helper predicates in prose."

4. **Unproved helper fields omitted in Listing 5 (Lines 217–220):**
   * Listing 4 shows that `Txn` has five fields (`R`, `W`, `f`, `frame`, `reads`), whereas Listing 5 (`def Txn.changeset`) shows only `R`, `W`, and `f`. Line 115 notes that "proofs are omitted" from listings, which explains the missing `frame` and `reads` fields in `Txn.changeset`, though in Listing 35 (`def ca`, `def cb`) the proof fields *are* shown inline. Mentioning in Line 115 that proof fields of structure instances are elided where routine would prevent a Lean-literate reader from thinking `Txn.changeset` is syntactically incomplete.

5. **Grab-bag paragraphs in Sections 2.2, 7.5, and 8 (Lines 169–170, 1098–1099, 1109–1110):**
   * As detailed in the Weakest Paragraphs section above, revise Lines 169–170 to lead with the semantic difference in `Agree`, and either integrate the three remarks of Section 7.5 (Lines 1098–1099) into Sections 3 and 5 or frame Section 7.5 around a single unifying claim.

6. **Minor typographical and formatting touches (Lines 32, 1158):**
   * Line 1158: Listing 45 (`lst:mcbl:build`) has a trailing period in its caption (`caption={Building the development and printing the axioms report.}`), whereas all 44 other listing captions omit the trailing period. Remove the period for consistency.
   * Line 999: "The condition of Theorem~\ref{thm:mcbl:udsafe} is therefore the weakest condition that mentions only the access sets, not an exact characterization for a given transaction." — Consider tightening to: "Theorem~\ref{thm:mcbl:udsafe} is therefore the weakest sufficient condition on access sets alone, though individual transactions whose outputs ignore their stale undeclared reads may still executeizability-equivalently."

---

VERDICT: MINOR REVISIONS
