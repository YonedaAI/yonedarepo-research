---
reviewer: Gemini 4 Argon (High)
paper: partitioned-derived-data
round: 1
date: 2026-10-20T15:55:29Z
---


# Peer Review: *Partitioned Derived Data (Part II of Source Control as a Data System)*

---

## 1. High-Level Evaluation by Criterion

### Mathematical Correctness
The central incremental-correctness result (Theorem 5.2) and the diagnosis and repair of the search prefix defect (Propositions 6.1 and 6.2) are sound and well-matched to the implementation. However, four formal claims later in the paper contain mathematical errors or missing hypotheses:
1. **Proposition 9.2 (Serializable codemods, lines 488–495)** is false as stated when the root-files partition is scanned and a concurrent commit adds a new root file containing the find string.
2. **Section 11 (line 621)** incorrectly claims that **Proposition 5.6 (Pruning by touched paths, lines 290–296)** allows a job to find changed partitions from $\W_v$ without listing every subtree under a **size-bounded recursive partitioning** (target size $g$). When file additions in one child subtree push a directory's file count above $g$, untouched sibling subtrees split into new partitions whose keys are absent from $\kappa(\Pi(c'))$ even though no path in $\W_v$ lies below them.
3. **Proposition 10.4 (Representation invariance of plans, lines 570–577)** states an insufficient hypothesis ("preserves reference edges and the nesting of symbol paths"): if a physical repartition merges two files that happen to contain prefix-related intra-file symbol paths (or split `impl` blocks), it creates new symbol overlaps unless the bijection preserves *same-file* symbol nesting in both directions.
4. **Proposition 11.1 (Optimal partition size, lines 606–617)** omits the R2 lookup cost incurred by eager commit-time derivation ($\lambda_c (N/g) c_\ell$), even though the implemented evaluator `searchSegments` runs on every landing (`deriveAfterLanding`, line 151) and looks up all $N/g$ keys without pruning by $\W_v$ (line 302).

### Clarity
The paper is unusually transparent about what the code does, where the implementation diverges from the design notes, and which claims rest on code inspection rather than execution. Clarity suffers where imported notation from Part I is compressed into a single dense paragraph (line 90), where undefined taxonomy labels appear in tables ("Change-local" and "Commit and policy" in Table 2, lines 213–218), and where formal propositions bake raw implementation constants into mathematical statements (e.g., Proposition 7.2 on line 416 and Proposition 11.2 on line 662).

### Completeness
The theoretical treatment of content-local read jobs is complete, and the code-evidence traceability in Appendix A (lines 734–791) is exemplary. Conversely, empirical completeness is weak: as the paper acknowledges (lines 83, 695, 719), there are zero measurements of segment build time, segment size, R2 lookup latency, codemod duration, planning duration, or partition change rates on real repositories. In addition, the prefix defect (Section 6) is traced manually through the source code without even a regression test demonstrating the failure and verifying Repair (b) (lines 374, 717).

### Logical Structure
The progression from the job model (Section 3) to incremental correctness (Section 5) and the prefix counterexample (Section 6) is natural, but three structural dislocations weaken the narrative arc:
1. **Search is split across three non-adjacent sections**: its map/reduce mechanics are sketched in Section 3 (lines 135, 147), its prefix bug and grant-filtering failure mode are analyzed in Section 6 (lines 350–386), and its query execution pipeline and trigram completeness are only formally introduced in Section 8 ("Search as a partitioned read job", lines 447–464).
2. **Section 4 ("Derived data as a fold over the commit DAG", lines 176–222)** is a 22-line stub that introduces parent-recursive derivations and drops them until Section 5 (Proposition 5.7) and Section 7 ("History-dependent kinds", lines 394–446).
3. **Vacuum (Proposition 11.2, lines 658–670)**—a maintenance job with its own formal safety proposition and proof—is introduced for the first time in the middle of Section 11 (*Evidence*), sandwiched between unit-test summaries (line 656) and Server-Timing tables (line 671), and is absent from Table 2.

### LaTeX Quality
The document compiles cleanly and uses `booktabs`, `tabularx`, `longtable`, and `tikz` effectively, but exhibits recurring typographical defects:
- Every page range and issue range in `thebibliography` (lines 804, 810, 816, 822, 854, 860, 866, 887, 893, 905, 910) uses a hyphen (`-`) instead of an en-dash (`--`).
- `\usepackage{cleveref}` is loaded (line 22) but never used.
- File paths and R2 keys alternate arbitrarily between `\path{...}` and `\code{...}` (e.g., lines 147, 242, 286, 389, 634, 640–651).
- Math spacing and identifier styling are inconsistent (`\mathrm{Inv}` on line 252 vs. plain text `Inv` on lines 254 and 257; manual thick spaces `\;` inside tuples on lines 119 and 185 vs. `\,` on line 130 and none on line 144).

### Prose Quality and House Style Adherence
Much of the prose is crisp, direct, and economical. Where it departs from the house style, it commits four recurring errors:
1. **Multi-claim grab-bag paragraphs**: Several paragraphs bundle four to nine distinct claims, definitions, or caveats into a single block (most severely at lines 90, 302, 372, 423, and 497).
2. **Qualifications and narrative traces placed before the finding**: In technical analyses (e.g., lines 302, 372, 423, 597), the prose walks through low-level operational steps before stating the governing claim or invariant violation, or hedges a finding before stating it.
3. **Signposting and self-referential meta-commentary**: Sentences such as *"The contributions are as follows"* (line 74), *"The evidence is uneven, and we say so where it matters"* (line 83), *"We recall the parts we need and fix notation for the rest"* (line 88), *"This section states both definitions and the relation between them"* (line 179), and *"We record this as a gap against Scion's practice of recursive blame"* (line 423) violate the prohibition on filler and signposting.
4. **Nested subordination in formal statements**: Proposition 11.2 (line 662) embeds five levels of subordinate clauses and configuration defaults inside a single 106-word sentence.

---

## 2. Weakest Three Paragraphs and Model Rewrite

### Weakest Paragraph 1 (Lines 90–91)
> The object store holds Git blobs, trees and commits addressed by their Git object ids (Part~I, Definition~4.1). A commit $c$ has an ordered list of parents, the first of which is $\pi_1(c)$, and a tree state $\tree(c)$, the map from file paths to blob ids and modes that its root tree encodes. For a path prefix $p$ we write $\tree(c)|_p$ for the subtree at $p$ when it exists, and $\id(\tree(c)|_p)$ for the id of the Git tree object that encodes it. The platform records with each commit its touched paths, a list that contains every path whose entry differs between $\tree(\pi_1(c))$ and $\tree(c)$ (Part~I, Definition~4.2). The transaction log $(e_1,\ldots,e_n)$ of a repository (Part~I, Definition~4.10) records, for each version $v$, the ref it moved, the old and new commit, and the touched paths $\W_v$ of the commit it appended (Part~I, Definition~4.8). A snapshot $S_v$ is the ref map after version $v$ (Part~I, Definition~4.11), and a read pinned at version $v$ or at a commit id sees an immutable tree (Part~I, Definition~4.13). Accesses are file paths, directory prefixes written \code{dir/}, or symbol entries \code{path\#symbol}, with an overlap relation $\bowtie$ (Part~I, Definition~4.4). Each change has a declared read set $\R$ and a write set $\W$, which the platform may refine to symbols (Part~I, Definition~4.6), and two work items are independent in the sense of the companion paper's \cite[Eq.~1]{long2026inversion} condition when neither writes what the other reads or writes (Part~I, Definition~4.7). Landing a change validates it backward against the entries that landed after its base version, with outcomes fast-forward, rebase, merge or conflict (Part~I, Definition~4.15).

**Why it fails the house style:** This 260-word paragraph has no identifiable claim. It concatenates nine distinct definitions imported from Part I—covering Git objects, tree projections, touched paths, transaction log entries, snapshots, access granularity, independence, and backward validation—into a single undifferentiated block, with nested appositives (e.g., *"and a tree state $\tree(c)$, the map from file paths to blob ids and modes that its root tree encodes"*). It should be split into two focused paragraphs (one on immutable tree state and the transaction log, one on access sets and backward validation) or a compact notation table.

### Weakest Paragraph 2 (Lines 372–373)
> For search, after a rename of \code{src/} to \code{lib/}, every later query at the new commit reads the segment built for \code{src/}. The query reports matches at \code{src/\ldots} paths that do not exist in the commit it names. Line matches are still correct, because \code{grep} reads the candidate by blob id. Grant filtering runs on the reported paths (\code{keepAllowed}), not on the paths where the content now lives. A caller whose grant covers \code{src/} but not \code{lib/} therefore receives line matches from files that, at the queried commit, exist only under \code{lib/}, and a caller whose grant covers only \code{lib/} receives none. The bytes are the bytes the first caller could read at the earlier commit, so the exposure is narrow, but the result contradicts Part~I's grant invariant I14 at the queried commit (Part~I, Table~2). When two directories \code{a/} and \code{b/} have the same content in one commit, the first query that builds both segments builds each with its own prefix and is correct. Both puts target the same key, so every later query reads one stored segment for both partitions. Every match is then reported twice under one prefix and never under the other. Two puts to one key in the same second may also exceed R2's per-key write rate \cite{cfr2limits}; we have not observed this case.

**Why it fails the house style:** This paragraph crowds five separate claims into 208 words: stale path reporting after a rename, accurate blob-level line matching, a violation of Part I's access-control invariant I14, duplicate/missing matches across identical sibling directories, and an unverified R2 rate-limit hazard. Worse, it buries its central finding—that prefix-free keys violate access control at the queried commit—in the middle of the paragraph, and places the qualification (*"The bytes are the bytes the first caller could read at the earlier commit, so the exposure is narrow"*) *before* the finding (*"but the result contradicts Part I's grant invariant I14"*).

### Weakest Paragraph 3 (Lines 423–424)
> The implementation evaluates the fold from scratch at every query. Its cost is one diff per version of the file, up to the 200 newest versions that the blame request reads from path history. Versions older than the window are attributed to the oldest version kept, which acts as a history boundary in the manner of \code{git blame}'s caret. A memoized parent-recursive blame keyed by $(\id(c),p)$ would cost one diff per landed change to the file, which is the cost profile Scion describes \cite{anthropic2026scion}. We record this as a gap against Scion's practice of recursive blame. Two further limits follow from the code: blame and path history follow the first parent, so changes reached only through a merge's other parents are attributed to the merge, and neither follows renames.

**Why it fails the house style:** This paragraph mixes three distinct topics—query-time fold cost and window truncation, a counterfactual comparison with Scion's memoized recursive blame, and two semantic limitations of first-parent traversal (merge attribution and rename blindness)—connected by self-referential signposting (*"We record this as a gap against Scion's practice of recursive blame. Two further limits follow from the code:"*).

### Model Rewrite of Weakest Paragraph 2 (Lines 372–373)
To adhere to the house style (one claim per paragraph, findings stated directly before qualification, no tacked-on asides), split the paragraph into two focused paragraphs—one on the rename and access-control failure, and one on duplicate directories:

> Prefix-free search keys misattribute paths after a directory rename and violate Part~I's path-grant invariant I14 (Part~I, Table~2). When \code{src/} is renamed to \code{lib/} without content changes, queries at the new commit reuse the segment built for \code{src/} and report hits under nonexistent \code{src/\ldots} paths, while \code{grep} still extracts matching lines by blob id. Because \code{keepAllowed} filters candidates by their stored paths rather than their paths at the queried commit, a caller granted \code{src/} but not \code{lib/} receives matches from \code{lib/}, whereas a caller granted only \code{lib/} receives none. This leak exposes only bytes that already existed under \code{src/} in the earlier commit, but it violates the snapshot's access policy.
>
> Prefix-free keys also corrupt search results within a single commit whenever two top-level directories have identical content. On a cold store, the first query builds distinct segments for \code{a/} and \code{b/} in memory and returns the right paths, but both writes target the same R2 key (and can trigger R2's one-write-per-second per-key limit \cite{cfr2limits}). Every subsequent query reads whichever segment landed last for both partitions, reporting each match twice under one directory and never under the other.

---

## 3. Structured Feedback by Severity

### Critical Issues

1. **Counterexample to Proposition 9.2 (Serializable codemods) on root-file phantom writes (lines 488–495)**
   - **Issue:** Proposition 9.2 states that if a codemod at version $v$ scans partition prefixes $p_1, \dots, p_m$ and declares the read set $\R = \{p_1/, \dots, p_m/\}$, *"together with the root files it scanned"*, then the landed tree equals the codemod applied to the snapshot immediately before its landing, restricted to the scanned partitions. This is false when the codemod scans the root-files partition $(\varepsilon, F)$. Declaring the individual root file paths in $F$ at version $v$ only locks those existing files. If a concurrent commit at version $v+1$ adds a *new* root file `new.rs` containing the find string, its write set $\W_{v+1} = \{\code{new.rs}\}$ does not overlap any $p_i/$ or any root file path that existed at version $v$. Backward validation therefore permits the codemod to land via rebase, leaving the find string unreplaced in `new.rs` inside the scanned root-files partition $\varepsilon$. Similarly, for a repository-wide codemod, declaring only the directories $p_1/, \dots, p_m/$ that existed at version $v$ does not conflict with a concurrent commit that adds a new top-level directory $p_{m+1}/$ containing the find string.
   - **Fix:** Either introduce a root-files partition token (or repository-wide prefix `/`) in the access algebra so that $\R$ can lock all root files against additions, or restrict Proposition 9.2 explicitly to directory partitions $p_1/, \dots, p_m/$.

2. **Invalid application of Proposition 5.6 (Pruning by touched paths) to size-bounded recursive partitioning (lines 290–296, 302, 621)**
   - **Issue:** Section 10 (line 621) proposes a recursive partitioning that descends from the root and makes a partition of every subtree whose file count is at most $g$, and claims that *"Proposition 5.6 lets the derivation job find the changed partitions from the log's touched paths without listing every subtree."* Proposition 5.6 is proved only for the fixed top-level partitioning $\Pi(c)$ of Definition 3.1, where partition boundaries do not depend on subtree file counts. Under size-bounded recursive partitioning, adding files to `a/b/` can push the file count of `a/` from $\le g$ to $> g$, splitting `a/` into child partitions `a/b/` and `a/c/`. The sibling partition `(a/c, \tree(c)|_{a/c})` is then a member of $\Ch(c', c)$—its key $\id(\tree(c)|_{a/c})$ was not in $\kappa(\Pi(c'))$ because `a/` was a single partition in $c'$—even though no path in $\W_v$ has prefix `a/c/`. Moreover, discovering that `a/c/` is now a partition requires listing `a/` when `a/` splits.
   - **Fix:** State explicitly in Proposition 5.6 that its prefix-pruning bound assumes fixed-boundary (layout-determined) partitions, and revise line 621 to note that under size-bounded recursive partitioning, touched paths prune only subtrees that do not share a splitting ancestor with any path in $\W_v$.

3. **Insufficient hypothesis in Proposition 10.4 (Representation invariance of plans, lines 570–577)**
   - **Issue:** Proposition 10.4 assumes a bijection $\varphi$ between the symbols of two repository layouts that *"preserves reference edges and the nesting of symbol paths"*. In Definition 10.1 (line 523), a symbol node is $(\text{path}, \text{symbol path})$. As the proof itself notes (line 576), two symbol entries overlap if and only if they *name the same file* and one symbol path is equal to or nested in the other. If Layout 1 places `(a.rs, Foo)` and `(b.rs, Foo::bar)` in distinct files (no overlap) and Layout 2 coalesces `a.rs` and `b.rs` into `c.rs`, mapping them to `(c.rs, Foo)` and `(c.rs, Foo::bar)`, then $\varphi$ preserves reference edges and intra-file symbol-path nesting, yet creates a new overlap in Layout 2 that alters Steps 3 and 4 of the plan.
   - **Fix:** Strengthen the hypothesis of Proposition 10.4 to require that $\varphi$ be an isomorphism of both the reference graph $G_s$ and the *same-file nesting relation* $u \sqsubseteq v \iff (\text{path}(u) = \text{path}(v) \land \text{sympath}(u) \preceq \text{sympath}(v))$ (i.e., $u \sqsubseteq v \iff \varphi(u) \sqsubseteq \varphi(v)$).

4. **Missing commit-derivation lookup term in Proposition 11.1 (Optimal partition size, lines 606–617)**
   - **Issue:** Proposition 11.1 defines $b = \lambda_q N c_\ell$, charging $N/g$ partition lookups only to queries arriving at rate $\lambda_q$. However, in YonedaRepo, eager derivation (`deriveAfterLanding`, line 151) calls `searchSegments` after every landing, and `searchSegments` looks up all $N/g$ partition keys in R2 without pruning by $\W_v$ (Proposition 5.5, line 279; line 302). Under the implemented evaluator, lookups occur on both eager derivations and queries, so $b = (\lambda_c + \lambda_q) N c_\ell$ (or, with queue coalescing at effective derivation rate $\tilde{\lambda}_c$, $b = (\tilde{\lambda}_c + \lambda_q) N c_\ell$). The formula $b = \lambda_q N c_\ell$ holds only if commit-time derivation prunes unchanged partitions via $\W_v$ without R2 lookups (in which case its $u$ lookups per commit belong to the linear term $a = \lambda_c u (c_i + c_\ell / g)$, i.e., absorbed into the constant $k = \lambda_c u c_\ell$).
   - **Fix:** Distinguish the cost of the unpruned evaluator ($b = (\lambda_c + \lambda_q) N c_\ell$) from that of the $\W_v$-pruned evaluator ($b = \lambda_q N c_\ell$ with $\lambda_c u c_\ell$ absorbed into $k$).

---

### Major Issues

5. **Type mismatch when applying Theorem 5.2 to history-dependent kinds (Section 7, line 408)**
   - **Issue:** Line 408 states that for any history-dependent kind whose value at $c$ is a function of the ancestry of $c$, *"Theorem 5.2 applies with $\kappa(c) = \id(c)$."* However, Definitions 3.1, 3.2, 3.4, and 5.1 and Theorem 5.2 are defined exclusively over content-local partitions $(p, x) \in \Pi(c)$ where $x$ is a subtree of $\tree(c)$, which does not carry commit ancestry.
   - **Fix:** Generalize Definitions 3.2 and 5.1 so that a partition element can include the commit $c$ (e.g., $(c, p)$) when $\delta$ is history-dependent, or state a brief corollary extending Theorem 5.2 to commit-keyed memoization.

6. **Implicit assumption on $\rho_\delta$ in Proposition 5.7(a) and imprecise condition in 5.7(c) (lines 306–313)**
   - **Issue:** In Proposition 5.7(a), the parent-recursive evaluator is given *"the family of segments of the first parent $c'$"*, and the proof concludes that it is *"computed from $c$ and $D_\delta(c')$, as Definition 4.1 requires."* In Definition 3.2, $D_\delta(c')$ is the *output* of the reduce function $\rho_\delta$, which only preserves the family of segments if $\rho_\delta$ is injective (e.g., the identity map returning the indexed segments rather than a truncated query answer). In Proposition 5.7(c), the strictness condition *"whenever a recomputed partition of $c$ has a key that occurs in the store from some commit other than $c'$"* misses the case where a partition $(p, x)$ of $c$ reuses a segment from *a different prefix $p' \ne p$ of $c'$ itself* (after Repair (b), when a directory in $c'$ is renamed or duplicated in $c$).
   - **Fix:** Specify in Proposition 5.7 that $D_\delta$ is the family of partition segments ($\rho_\delta = \mathrm{id}$), and state (c) as: *"the inclusion is strict whenever a partition of $c$ recomputed by the parent-recursive evaluator has a key already in $\dom\Sigma$ (whether from another prefix of $c'$ or from another commit)."*

7. **Imprecise formulation of feed constraints in Proposition 10.3 (Fewest stages is graph coloring, lines 555–562)**
   - **Issue:** Proposition 10.3 states *"suppose no feed constraints are imposed"*, even though the feed relation $\W_k \bowtie \hat\R_l$ is determined by the very same effective access sets $(\hat\R, \W)$ that define the conflict graph $H$. If feed edges exist, not every proper coloring of $H$ induces a valid topological order of the feed condensation (Step 3).
   - **Fix:** State Proposition 10.3 as a property of the greedy staging rule (Step 4) over arbitrary processing orders $\pi$ when $\W_k \cap \hat\R_l = \varnothing$ (pure write-write conflicts) or when Step 3's ordering constraint is relaxed.

8. **Structural misplacement of Vacuum (Proposition 11.2, lines 658–670) and Search (Section 8, lines 447–464)**
   - **Issue:** Vacuum is introduced for the first time inside Section 11 (*Evidence*, lines 658–670) with a formal proposition and proof, and is omitted from Table 2. Meanwhile, Section 8 (*Search as a partitioned read job*, lines 447–464) appears two sections *after* Section 6 (*The prefix defect in the search key*, lines 350–386) has already analyzed search's internal `grep` and `keepAllowed` behavior.
   - **Fix:** Move Section 8 ahead of Section 6 (or merge it into Sections 3 and 6), move Proposition 11.2 (Vacuum safety) into Section 7 or Section 9 (and add Vacuum to Table 2), and keep Section 11 strictly focused on test and benchmark evidence.

9. **Undefined taxonomy terms in Table 2 (lines 201–222)**
   - **Issue:** Section 4 formally defines only *parent-recursive* (Definition 4.1) and *content-local* (Definition 4.2) derivation kinds, while Section 3 mentions *history-dependent* kinds (line 132). Table 2 then introduces two undefined terms in its "Dependence" column: *"Change-local"* (lines 213, 214, 217) and *"Commit and policy"* (line 218).
   - **Fix:** Define change-local kinds (functions of $(\tree(\pi_1(c)), \tree(c))$) and policy-dependent kinds in Section 4 before Table 2.

10. **Prefix defect (Section 6) lacks an executable test (lines 374, 717)**
    - **Issue:** Although the paper is a study of an implemented codebase at commit `cfa4845` and relies on workerd and Rust tests as its primary evidence (Section 11), the flagship counterexample in Section 6 (lines 372–374) was never executed in a test. Writing a 15-line test in `repo-derived.test.ts` that renames `src/` to `lib/` (or duplicates `a/` and `b/`) would replace code-reading speculation with direct empirical verification.
    - **Fix:** Add or report the test case confirming Proposition 6.1 and Repair (b) of Proposition 6.2.

---

### Minor Issues

11. **En-dashes missing in all bibliography number ranges (lines 804–910)**
    - **Issue:** Every page and issue range in `thebibliography` uses a single hyphen `-` instead of `--`: `3411-3424` (line 804), `1-10` (line 810), `61-71` (line 816), `1601-1614` (line 822), `157-166` (line 854), `156-166` (line 860), `85-103` (line 866), `369-378` (line 887), `1-29` (line 893), `146-160` (line 905), and `15-28` (line 910).
    - **Fix:** Replace `-` with `--` in all numeric ranges.

12. **Typo in bibliography author name (line 858)**
    - **Issue:** `J.~S. F{o}ster` has unnecessary braces around `{o}`.
    - **Fix:** Change `F{o}ster` to `Foster`.

13. **Unused package and inconsistent path/code macros (lines 22, 147, 242, 286, 355–359, 389, 634–651)**
    - **Issue:** `\usepackage{cleveref}` (line 22) is unused. R2 key prefixes and filenames switch between `\path{...}` and `\code{...}` (compare line 242 `\path{derived/v1/<repo>/search/}` with line 286 `\code{derived/}` and line 389 `\code{derived/v1/}`; compare line 634 `\code{tests/workers}` with lines 640–651 `\path{...}`). Listing 1 (lines 355–359) places Rust and TypeScript lines in a single `lstlisting` without file comments.
    - **Fix:** Standardize on one macro for paths/keys, add file comment headers inside Listing 1, and either use `\cref` or remove `cleveref`.

14. **Inconsistent math typography and notation details (lines 119, 130, 185, 252–257, 378, 437, 523, 529)**
    - **Issue:**
      - Line 119: `\{(\varepsilon,\;F)\ \text{if}\ F\ne\varnothing\}` uses `if` instead of `:` and manual `\;` spacing inside pairs that is absent on lines 128, 144, and 229.
      - Lines 252–257: `\mathrm{Inv}` is typeset in math mode on line 252, then as plain text `Inv` on lines 254 and 257.
      - Line 378: Repair (b) says *"prepend $d$ to every path"*, whereas $d$ is the bare directory name (`e.name`, line 356), so the reduce must prepend $d/$ (with a slash) for non-empty prefixes.
      - Line 437: *"where the check passes at $\ell$ (initially $g$) or $\ell$ is the start"* is redundant since $g$ is the start.
      - Lines 523, 529: Write `\mathcal{C}` and `\hat{\R}` instead of `\mathcal C` and `\hat\R`.

15. **Signposting sentences to trim for house style (lines 74, 83, 88, 179, 385, 423)**
    - **Issue:** Remove meta-prose and signposting at line 74 (*"The contributions are as follows."*), line 83 (*"and we say so where it matters"*), line 88 (*"We recall the parts we need and fix notation for the rest."*), line 179 (*"This section states both definitions and the relation between them."*), line 385 (*"the next remark states the general rule"*), and line 423 (*"We record this as a gap against Scion's practice of recursive blame. Two further limits follow from the code:"*).

VERDICT: MAJOR REVISIONS (major issues remain)
