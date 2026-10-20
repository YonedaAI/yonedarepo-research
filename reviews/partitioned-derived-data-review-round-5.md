---
reviewer: Gemini 4 Argon (High)
paper: partitioned-derived-data
round: 5
date: 2026-10-20T18:58:37Z
---


## Overview and Assessment across Evaluation Criteria

This paper formalizes incrementally maintained derived data (search indexes, symbol tables, blame, checks, codemods, and agent work plans) as partitioned views over an immutable commit DAG and transaction log. Its central theoretical contribution—characterizing snapshot view consistency via *key sufficiency* (Definition 5.1, Theorem 5.3) and demonstrating that content-addressed subtree keys strictly subsume parent-recursive derivations for content-local views (Proposition 5.8)—is clean, well-motivated, and productively applied to expose a real path-prefix collision bug in the YonedaRepo reference implementation (Section 7).

### 1. Mathematical Correctness
The core proofs (Lemmas 2.2–2.3, Theorem 5.3, Propositions 5.4, 5.6, 5.7, 5.8, 6.1, 7.1, 7.2, 8.1, 8.2, 9.2, 9.3, 9.4, Theorem 10.2, Propositions 10.3, 10.4, 10.6, 11.1, 11.2, and 12.1) are sound in their main conclusions, but four technical gaps require correction:
- **DBSP Z-set reduction (line 359):** The equation $F_\delta(c)=F_\delta(c')+\mathrm{map}_{f_\delta}(\Pi(c)-\Pi(c'))$ does not match what the parent-recursive evaluator of Proposition 5.8 actually computes. In DBSP, $\Pi(c)-\Pi(c')$ is a Z-set containing weight $-1$ entries for removed or modified partitions in $\Pi(c')\setminus\Pi(c)$, so applying the linear operator $\mathrm{map}_{f_\delta}$ to the difference would evaluate $f_\delta$ on the old partitions to subtract them. The parent-recursive evaluator instead drops old entries from $F_\delta(c')$ by prefix lookup without re-evaluating $f_\delta$, and it operates on canonically ordered sequences (Definition 4.3, line 225) rather than unordered Z-sets.
- **Underspecified intra-component ordering in the feed relation (lines 602, 613, 646–650):** Step 3 of the planner (line 602) orders items "topologically over their condensation, breaking ties by the smallest input position." As Theorem 10.2(d) (line 613) acknowledges, two distinct joint items $k$ and $l$ can lie in the *same* strongly connected component of the feed relation ($\W_k\bowtie\hat{\R}_l$ and $\W_l\bowtie\hat{\R}_k$, since Step 1 joins cycles in $G_s$ rather than cycles in the induced feed relation). Step 3 never defines how items *inside* a multi-item feed component are ordered, which leaves the determinism of Step 3 and the equivariance proof of Proposition 10.4 (lines 649–651) incomplete.
- **Undefined constant $k$ and unstated cache-hit hypothesis in Proposition 11.1 (lines 680–691):** The displayed cost function $C(g)=k+ag+b/g$ (line 684) introduces an undefined constant $k$ that is explained only inside the proof (line 690: "with $k$ the cost that does not depend on $g$"). For the unpruned evaluator of Proposition 11.1, $k=0$; $k$ becomes nonzero only for the pruned variant discussed afterward on line 693. In addition, the proof relies on the premise that "Queries rebuild nothing that a job has already built" (line 690), which must be stated as an explicit steady-state hypothesis in the proposition because asynchronous queue coalescing (line 175) allows queries to hit unindexed commits and trigger lazy rebuilds.
- **Implicit atomicity of single-key reads and writes (lines 275, 278, 293):** Assumption 5.2(iii) states that $\mathrm{get}(k)$ returns either nothing or a value previously put at $k$, and line 278 claims this "holds for any store that does not invent values." Under concurrent puts (line 293), this requires single-key read/write atomicity (absence of torn reads or bytewise-interleaved writes), which should be stated explicitly.

### 2. Clarity and Completeness
The formal model is clear and tightly linked to the implementation via Appendix A. However, the paper's empirical evaluation is incomplete in ways that weaken its systems claims:
- **Unmeasured core parameters:** As acknowledged on lines 58, 86, 712, 791, and 815, the paper provides no measurements of search indexing throughput, segment size, R2 lookup latency $c_\ell$, per-file indexing cost $c_i$, codemod latency, or plan computation time. Consequently, the optimal partition size $g^*$ in Proposition 11.1 cannot be instantiated for any repository.
- **Unverified commit-message metrics:** The warm-start seed speedups (109 s vs. 8.1 s; 1/301 and 1/201 blobs fetched, lines 524–527 and Table 4, lines 780–781) are cited from a commit message with no raw logs or reproduction artifacts.
- **Incomplete end-to-end execution of the prefix counterexample:** The scratch test in Appendix B (lines 896–991) tests only the Rust functions `search_plan` and `index_partition`; the downstream effects on `search` grant filtering and `codemod` conflict failure in the TypeScript Worker adapter (`repo-derived.ts`, `repo-code.ts`) were traced by reading code rather than executed in `workerd` (lines 459, 813).
- **Status of codemod read sets:** Proposition 9.3 (lines 556–559) proves serializability when a codemod declares $\R=\{q/\}$, whereas the actual implementation in `repo-code.ts::codemod` declares no read set (lines 537, 552, 869). The text should state explicitly that $\R=\{q/\}$ is a proposed protocol extension, not an existing option in `codemod`.

### 3. Logical Structure
The progression from imported Part I primitives (Section 2) to the job model (Section 3), DAG folds (Section 4), key sufficiency (Section 5), read/write jobs (Sections 6–9), semantic planning (Section 10), granularity (Section 11), and vacuum (Section 12) is logical and cohesive. Within sections, however, argumentative flow is repeatedly broken by **eleven one- or two-sentence orphan paragraphs** (lines 308, 328, 330, 348, 396, 569, 627, 712, 811, 819, 821) that act as isolated asides or transitions rather than self-contained analytical paragraphs.

### 4. LaTeX Quality
The LaTeX source is clean and compiles without structural hacks, but has several typographical and markup flaws:
- **Hyphens instead of en-dashes in page ranges:** Every page range in the bibliography uses a single hyphen `-` instead of `--` (lines 1012, 1018, 1024, 1030, 1068, 1080, 1086, 1092, 1110, 1129, 1134, 1139).
- **Hyphens instead of en-dashes in multi-author theorem names:** `Gallai-Hasse-Roy-Vitaver theorem` (line 638) should use en-dashes (`Gallai--Hasse--Roy--Vitaver`).
- **Misuse of `\path{...}` for module-qualified function names:** Expressions such as `\path{repo-derived.ts::searchSegments}` (lines 171, 173, 175, 537) apply filesystem path markup to TypeScript function names using Rust `::` syntax.
- **Unused packages:** `\usepackage{graphicx}` (line 12) and `\usepackage{cleveref}` (line 23) are loaded but never used.
- **Redundant column in Appendix A `longtable`:** Every row of Table 5 (lines 850–887) repeats `\code{cfa4845}` in the `Commit` column even though line 835 states that all rows refer to `cfa4845`.

### 5. Prose Quality and House Style Evaluation
The prose is generally direct and avoids heavy nominalization, but it violates the house style in four recurring ways:
1. **Orphan and grab-bag paragraphs:** Several paragraphs consist of a single sentence lacking developed support (e.g., lines 328, 712, 811, 819), while others bundle multiple distinct claims into one block (e.g., lines 86, 638).
2. **Signposting and meta-discourse openings:** Paragraphs open with throat-clearing such as `"Thearchitecture is stated over..."` (line 73), `"Table 1 records the analogy and where it bends."` (line 198), `"The claims of this Part rest on..."` (line 737), and `"The formal results are about the model, and the model abstracts the code."` (line 809) instead of stating the finding directly.
3. **Repetitive phrasing and passive constructions:** Line 86 repeats its opening clause verbatim in the passive voice (`"Tests support the correctness properties... Correctness properties are supported by tests..."`), and line 73 repeats `"built"` three times across seventeen words.
4. **Qualification before finding or imprecise statistical comparison:** Lines 787–789 open with a structural label rather than the empirical finding and compare a median (240–248 ms) against a 95th percentile (2.8–3.7 s) when the 95th percentile of the derivation phase itself (335–367 ms) is reported in Table 4.

---

## Weakest Three Paragraphs and Model Rewrite

### 1. Weakest Paragraph 1 (Line 86)
> `Tests support the correctness properties, and almost no timings exist. Correctness properties are supported by tests and property-based tests in the repository, and by a test we wrote against the code at commit \code{cfa4845} that executes the counterexample of Section~\ref{sec:pdd:prefix}. The only timings that touch derived data are the commit-time derivation phase in two instrumented hosted runs and the warm-start seed figures from commit messages. Indexing throughput, segment sizes, the fraction of partitions that change on real repositories and the cost of a codemod were not measured; Part~III, Section~9 lists the planned measurements \cite{long2026partIII}.`

**Why it fails the house style:** The opening sentence joins two distinct claims (verification of correctness vs. absence of performance timings), and the second sentence immediately repeats the first clause almost word-for-word in the passive voice (`"Tests support the correctness properties"` $\to$ `"Correctness properties are supported by tests"`).

### 2. Weakest Paragraph 2 (Line 73)
> `The architecture is stated over cloud-portable primitives. The system under study, YonedaRepo, is its reference realization, built on Cloudflare. The author designed and built it, and it is still being built; its code is cited by file and commit throughout and in Appendix~\ref{app:pdd:evidence}.`

**Why it fails the house style:** This paragraph makes no substantive analytical claim. It strings together meta-signposting (`"The architecture is stated..."`, `"its code is cited..."`) with biographical status notes, uses passive voice in three of its four clauses, and repeats `"built"` three times (`"built on Cloudflare"`, `"designed and built it"`, `"still being built"`).

### 3. Weakest Paragraph 3 (Line 638)
> `The planner does not range over all orders. Step 3 places a writer before every item it feeds whenever the two lie in different components of the feed relation, so the planner's minimum is at least the chromatic number and can exceed it. The proposition is the Gallai-Hasse-Roy-Vitaver theorem applied to the staging rule: the layers of the longest-path layering of an acyclic orientation color the graph properly, and some acyclic orientation has exactly $\chi(H)$ layers \cite[Th\'eor\`emes~1 and~2]{roy1967}. Each processing order induces an acyclic orientation of $H$, and every acyclic orientation arises from a topological order, so the proof above is the reduction. Minimizing the number of stages over all orders is as hard as graph coloring, which is NP-complete in its decision form (see \cite{karp1972}). The planner's fixed order is a greedy coloring. The choice is defensible for a scheduler that must be deterministic and fast, but the stage count it reports is an upper bound on the parallel depth, not the minimum.`

**Why it fails the house style:** This paragraph packs three distinct claims into one block: (1) why the planner's feed-constrained greedy order can exceed $\chi(H)$, (2) how Proposition 10.3 reduces to the Gallai–Hasse–Roy–Vitaver theorem, and (3) why minimizing stages is NP-hard. Because the theoretical digression sits in the middle, the main claim about the planner is split between the first two sentences and the final two sentences.

### Model Rewrite (Rewriting Line 86)
> The correctness claims of this paper rest on executable tests at commit \code{cfa4845}, whereas its performance claims remain largely unmeasured. Unit and property-based tests in the repository verify partition reuse, trigram filtering, blame attribution, bisect, vacuum, symbol handles, codemod reduction, and plan staging, and an external integration test (Appendix~\ref{app:pdd:prefixtest}) reproduces the search-key collision of Section~\ref{sec:pdd:prefix}. By contrast, only two hosted runs of the commit-time derivation phase and commit-message figures for warm-start seeds provide timing data; indexing throughput, segment sizes, partition change rates, and codemod latency are left to the measurement plan in Part~III, Section~9 \cite{long2026partIII}.

---

## Structured Feedback by Severity

### Critical Issues
None. No fatal mathematical errors invalidate the paper's core theorems.

### Major Issues

- **[Major 1 — Mathematical precision of the DBSP Z-set reduction] Line 359:**
  The claim that $F_\delta(c)=F_\delta(c')+\mathrm{map}_{f_\delta}(\Pi(c)-\Pi(c'))$ is "what the parent-recursive evaluator computes" is inaccurate. In DBSP, $\Pi(c)-\Pi(c')$ contains negative weights for partitions in $\Pi(c')\setminus\Pi(c)$, so applying a linear map $\mathrm{map}_{f_\delta}$ to $\Pi(c)-\Pi(c')$ requires evaluating $f_\delta$ on the removed parent partitions in order to cancel their tuples in $F_\delta(c')$. The parent-recursive evaluator of Proposition 5.8 avoids recomputing $f_\delta$ on removed partitions because it indexes $F_\delta(c')$ by prefix $p$ and key $\kappa(p,x)$, discarding unmatched parent tuples directly, and it produces a canonically ordered sequence (Definition 4.3, line 225) rather than an unordered Z-set. Revise line 359 to state this distinction explicitly.

- **[Major 2 — Incomplete specification of Step 3 (Order) on cyclic feed components] Lines 602, 613, 646–651:**
  Step 3 (line 602) specifies that the planner computes the strongly connected components of the feed relation ($\W_k\bowtie\hat{\R}_l$) and orders items "topologically over their condensation, breaking ties by the smallest input position." Because Step 1 only joins items that touch a shared written cycle in $G_s$, two distinct joint items $k$ and $l$ can still form a cycle in the feed relation (for instance, when $G_s$ is acyclic and $\W_k\bowtie\hat{\R}_l$ while $\W_l\bowtie\hat{\R}_k$). Theorem 10.2(d) (line 613) explicitly guards against this case ("and they lie in different components of the feed relation"), but Step 3 never specifies how items *within* a multi-item component of the feed condensation are ordered, nor does Section 10 explain why mutually feeding items are serialized into distinct stages by Step 4 rather than joined into a single joint item. Specify the intra-component tie-breaking rule in Step 3, verify that it depends only on input positions (and not on symbol iteration order) so Proposition 10.4 (lines 646–651) holds, and explain why cyclic feed dependencies are staged rather than joined.

- **[Major 3 — Undefined constant $k$ and unstated zero-miss assumption in Proposition 11.1] Lines 680–691:**
  In Proposition 11.1 (line 684), the constant $k$ appears in $C(g)=k+ag+b/g$ without being defined in the proposition statement. Under the hypotheses of Proposition 11.1 (where both derivation jobs and queries look up all $N/g$ partitions), the sum of rebuild and lookup costs has $k=0$; a positive $k$ arises only in the pruned variant discussed on line 693 (`$\tilde\lambda_c u c_\ell$ does not depend on $g$ and moves into $k$`). Furthermore, the proof (line 690) assumes that "Queries rebuild nothing that a job has already built," which does not hold automatically when derivation jobs are asynchronous and coalesced (line 175). Define $k$ (or set $k=0$ in Proposition 11.1 and introduce the constant term on line 693) and state in Proposition 11.1 that queries hit warm segments with no lazy rebuilds.

- **[Major 4 — Unexecuted adapter path for the prefix defect and unarchived seed measurements] Lines 451–459, 524–527, 780–781, 813:**
  Two empirical claims rest on incomplete evidence:
  1. The grant-bypass and codemod-conflict consequences of the prefix defect (lines 451–457) depend on the TypeScript Worker adapter (`repo-derived.ts`, `repo-code.ts`), which was inspected by reading code rather than executed in `workerd` (lines 459, 813). Adding a `workerd` test that renames `src/` to `lib/` and invokes `search` (with a path-restricted grant) and `codemod` would turn an inspection trace into direct experimental evidence.
  2. The warm-start seed measurements in lines 524–527 and Table 4 (lines 780–781) are taken solely from a commit message with no raw output on disk. Either re-run the local and hosted seed checks to record reproducible logs or move the unarchived commit-message numbers out of Table 4 into the prose with an explicit caveat.

- **[Major 5 — Paragraph structure and house-style violations] Lines 73, 86, 308, 328, 330, 348, 396, 569, 627, 638, 712, 787–789, 811, 819, 821:**
  Revise the manuscript to eliminate single-sentence orphan paragraphs and multi-claim blocks, and ensure every paragraph leads with its claim before qualification:
  - Merge or expand the eleven 1–2 sentence orphan paragraphs: line 308 (merge into line 305/Proposition 5.4 discussion), line 328 (merge into line 326), line 330 (merge into line 344 after Proposition 5.7), line 348 (merge into line 346), line 396 (merge into Corollary 5.9 discussion), line 569 (merge into line 567), line 627 (merge into line 638), line 712 (merge into line 710), and lines 811, 819, and 821 (consolidate in Section 14 by thematic limitation: formal model vs. implementation coverage vs. empirical gaps).
  - Split line 638 into two focused paragraphs: one proving that Proposition 10.3 is the Gallai–Hasse–Roy–Vitaver theorem and hence stage minimization is NP-hard, and another explaining that Step 3 restricts the planner to a feed-respecting greedy coloring whose stage count upper-bounds $\chi(H)$.
  - Rewrite lines 73, 86, and 787–789 to remove meta-signposting, passive repetition, and the mismatched median-vs.-p95 comparison (compare the derivation phase's p95 of 335–367 ms directly against the commit p95 of 2.8–3.7 s).

### Minor Issues

- **[Minor 1 — Single-key atomicity in Assumption 5.2] Lines 275, 278, 293:**
  Specify in Assumption 5.2(iii) and line 278 that `put` and `get` are atomic per key (no torn reads or interleaved bytes from concurrent puts).

- **[Minor 2 — Order and root sentinel for change-local keys] Lines 230–233:**
  Line 233 states that "a key built from both tree ids is sufficient" for a change-local kind. Specify that the key must encode the *ordered* pair $(\id(\tree(\pi_1(c))),\id(\tree(c)))$, using the canonical empty-tree id when $c$ is a root commit.

- **[Minor 3 — Clarify that `codemod` read sets are not implemented] Lines 537, 552, 556–559:**
  State explicitly before Proposition 9.3 that the current `repo-code.ts::codemod` implementation does not accept or emit a `read_set` (as noted on lines 552 and 869), so Proposition 9.3 characterizes a proposed extension of the codemod commit payload.

- **[Minor 4 —Clarify tree reads vs. count lookups in size-bounded pruning] Lines 708–710:**
  Line 708 states that the derivation job must "list the directories in $A$ and their children." Because each directory entry in a parent tree $p\in A$ already records the child's name, mode, and subtree id $\id(\tree(c)|_r)$, reading the trees of $A$ already yields the keys of all children of $A$; the children's subtrees are read only when building a missing segment or computing an unmemoized file count. Clarify this distinction on lines 708–710.

- **[Minor 5 — Bibliography page ranges and compound names] Lines 638, 1012, 1018, 1024, 1030, 1068, 1080, 1086, 1092, 1110, 1129, 1134, 1139:**
  Replace single hyphens `-` with en-dashes `--` in all bibliography page ranges and in `Gallai--Hasse--Roy--Vitaver` (line 638).

- **[Minor 6 — LaTeX markup and preamble cleanup] Lines 12, 23, 146, 159, 171, 173, 175, 430, 486, 488, 505, 537, 666, 727, 838–888:**
  Remove the unused `graphicx` (line 12) and `cleveref` (line 23) packages (or use `\cref` consistently); replace `\path{file::symbol}` with `\path{file}` and `\code{symbol}` (especially for TypeScript files such as `repo-derived.ts`); and remove the redundant `Commit` column from Table 5 (lines 838–888), since every row is `\code{cfa4845}`.

VERDICT: MAJOR REVISIONS (major issues remain)
