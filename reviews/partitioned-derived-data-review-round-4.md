---
reviewer: Gemini 4 Argon (High)
paper: partitioned-derived-data
round: 4
date: 2026-10-20T18:28:36Z
---


### Summary Evaluation

1. **Mathematical Correctness**: The core theoretical apparatus—the reduction of incremental partition reuse to key sufficiency and store discipline (Theorem 5.3, Proposition 5.4), the work bound and touched-path pruning (Propositions 5.6–5.7), the subsumption of parent recursion by content addressing (Proposition 5.8), the diagnosis and repair of the search prefix defect (Propositions 7.1–7.2), the write-skew and serializability analysis for scoped codemods (Proposition 9.3), the plan DAG staging and chromatic-number bounds (Theorem 10.2, Proposition 10.3), representation invariance (Proposition 10.4), size-bounded pruning (Proposition 11.2), and vacuum safety (Proposition 12.1)—is sound and well-structured. However, **Proposition 9.4 (lines 554–565) contains a mathematical flaw** when combined with Repair (b) of Proposition 7.2 (lines 446–453): its memoization key omits the partition prefix $p$, reintroducing the prefix collision of Section 7 for codemod retries whenever $\kappa(d,x) = \id(x)$. In addition, **Proposition 8.1 (lines 473–480)** states the parent-recursive blame equation without qualifying for the 200-version sliding window (line 482) and 5,000-commit history cap (line 469), and the root-files key $\kappa(\varepsilon, F)$ (line 137) omits file modes without noting that sufficiency holds only for mode-insensitive map functions.
2. **Clarity**: Definitions, assumptions, and proofs are concise and readable. The separation between abstract cloud primitives and the Cloudflare reference realization (lines 121–123, Table 1) is transparent.
3. **Completeness**: Code-level claims are thoroughly cross-referenced against commit `cfa4845` (Appendix A) and backed by an executed Rust integration test reproducing the search key collision (Appendix B). Empirical completeness is much weaker: as acknowledged on lines 57, 83, 693, 770, and 792, no measurements exist for segment build time, segment size, R2 lookup latency, codemod duration, or plan computation, and the warm-start seed timings rely solely on commit messages without raw logs (lines 507–510, Table 4).
4. **Logical Structure**: The progression from read jobs and DAG folds (Sections 3–4) to key sufficiency (Section 5), search and its key defect (Sections 6–7), history/checks (Section 8), write jobs (Section 9), semantic planning (Section 10), partition granularity (Section 11), and vacuum (Section 12) is cohesive. A few passages duplicate material between Section 5 (line 286) and Section 13 (lines 775–781).
5. **LaTeX Quality**: The manuscript compiles cleanly and uses macros consistently, with minor issues: `\usepackage{cleveref}` is loaded on line 22 but never used; Listing 1 (line 422) uses raw backticks inside `lstlisting` without `upquote`; Listing 2 (lines 890, 907, 923, 940) has lines exceeding 100 characters that rely on automatic line-breaking; Table 5 (`longtable`, line 815) repeats the identical commit hash `cfa4845` in all 38 rows; and bibliography page ranges (lines 958–1047) use single hyphens (`-`) rather than en-dashes (`--`).
6. **Prose Quality**: Most of the paper adheres well to the house style—direct claims, minimal filler, and active reasoning. The weakest paragraphs violate the style by opening with metatextual signposting ("Four results of Part I carry...", "The more consequential property concerns concurrency", "Partial failure is the remaining gap..."), packing multiple distinct claims into a single paragraph (lines 72, 92, 286, 436), or mislabeling design choices as "assumptions that we name" (line 286).

---

### Weakest Three Paragraphs and Model Rewrite

#### 1. Paragraph 1 (Line 286)
> Theorem~\ref{thm:pdd:incremental} is an instance of two established arguments, and its proof is the reduction to them. Resilient distributed datasets recompute a lost partition from its lineage because the transformations are deterministic and their inputs are immutable \cite{zaharia2012rdd}; here the key plays the role of lineage, and key sufficiency together with Assumption~\ref{as:pdd:store}(i) is exactly the condition under which a stored partition may stand for the computation its key names. Build systems with constructive traces reuse a stored result when the hashes of a task's inputs match \cite{mokhov2018build}; key sufficiency is the requirement that the key cover every input the task reads. In the terms of incremental view maintenance, the evaluator maintains the view $D_\delta$ from $c'$ to $c$ by recomputing exactly the partitions whose inputs changed. It differs from tuple-level maintenance, which propagates the change itself through the query \cite{blakeley1986views,budiu2023dbsp}, in two assumptions that we name: a change is detected by comparing keys rather than represented as a delta, and the reduce is recomputed from all segments rather than updated.

*Why it fails the house style*: It bundles two distinct claims into one paragraph (first, that Theorem 5.3 reduces to RDD lineage recovery and constructive build traces; second, how the evaluator differs from tuple-level incremental view maintenance), duplicates the related-work synthesis on lines 775–781, and ends with signposting ("in two assumptions that we name") that mischaracterizes two algorithmic design choices as "assumptions."

#### 2. Paragraph 2 (Line 436)
> Prefix-free keys misattribute paths after a directory rename, and the misattribution defeats Part~I's grant invariant~I14 at the queried commit (Part~I, Table~2). When \code{src/} is renamed to \code{lib/} without content changes, queries at the new commit reuse the segment built for \code{src/} and report hits under \code{src/\ldots} paths that do not exist in that commit. The matched lines are still correct, because \code{grep} reads each candidate by blob id. Grant filtering in \code{keepAllowed} uses the stored paths, not the paths at the queried commit. A caller whose grant covers \code{src/} but not \code{lib/} therefore receives matches from files that exist only under \code{lib/}, and a caller whose grant covers only \code{lib/} receives none. How far the harm extends depends on where the stored segment came from. Segment keys are scoped to one repository, and directory grants restrict paths at every commit (Part~I, invariant~I14), so the leaked bytes always existed under the reported path in some commit of the same repository. If that commit is one the caller can name, such as an earlier commit on a branch it can read, the caller could have read the same bytes there, and only the attribution is wrong. If the segment was built from a commit the caller cannot discover, such as unlanded work of another writer, the caller receives content it had no practical way to reach. In both cases the response contradicts the grant at the queried commit.

*Why it fails the house style*: At ten sentences and 231 words, it fuses two separate arguments—the mechanics of how path misattribution breaks `keepAllowed` after a directory rename, and a secondary threat-model taxonomy of cross-commit information exposure—into one block, relying on nested conditionals ("If that commit is one the caller can name, such as an earlier commit on a branch it can read, the caller could have read...") and repeating its opening claim at the close.

#### 3. Paragraph 3 (Line 92)
> Four results of Part~I carry the proofs of Sections~\ref{sec:pdd:write} and~\ref{sec:pdd:vacuum}, and we state them here in the form we use. (P1) Validation of a change with base $b$ and declared reads $\R$ returns a conflict if some later entry on the same ref is opaque or has a refined write that overlaps $\R$; otherwise it returns fast-forward, rebase or merge, and in the last two cases the platform appends a merge commit whose parents are the previous head and the landed commit (Part~I, Definition~4.15). (P2) If validation does not return a conflict, the tree after landing equals the tree before landing with the change's writes applied, and the declared reads agree between the base and the state just before landing (Part~I, Theorem~6.4). (P3) The land combiner validates each batch member against the log but not against the other members, so a batch can contain two members that each write what the other read (Part~I, Theorem~7.3); if the combiner also refuses a member whose reads overlap the writes of an earlier accepted member, the batch is equivalent to landing its members one at a time in ticket order (Part~I, Proposition~7.4). (P4) If a ref holds commit $x$ at version $u$, then at every later version its value reaches $x$ by first parents (Part~I, Theorem~5.4).

*Why it fails the house style*: It opens with pure signposting ("Four results of Part~I carry the proofs... and we state them here in the form we use") rather than a substantive claim, and runs four distinct imported theorems with multi-level subordinate clauses together into a single unformatted paragraph.

#### Model Rewrite (of Paragraph 1, Line 286)
> Theorem~\ref{thm:pdd:incremental} reduces incremental view maintenance over snapshots to deterministic replay and input-hash memoization. In resilient distributed datasets, a lost partition is recomputed from its lineage because transformations are deterministic and inputs are immutable \cite{zaharia2012rdd}; in constructive build systems, a stored output is reused whenever the hashes of all inputs read by the task match \cite{mokhov2018build}. Key sufficiency and Assumption~\ref{as:pdd:store}(i) combine both conditions: the segment key serves as the partition's lineage and covers every input that $f_\delta$ reads. Unlike tuple-level view maintenance, which propagates relational deltas through a differentiated query \cite{blakeley1986views,budiu2023dbsp}, the evaluator detects change by comparing partition keys and recomputes $\rho_\delta$ across all segments at each evaluation.

---

### Structured Feedback by Severity

#### Critical Issues
None. No defect invalidates the main theoretical contributions or the experimental verification of the search key bug.

#### Major Issues

1. **Proposition 9.4 (lines 554–565) is false under Repair (b) of Proposition 7.2 (lines 446–453)**:
   - *Location*: Lines 554–565, cross-referencing Definition 9.1 (line 517), line 520, and Proposition 7.2(b) (lines 446–453).
   - *Problem*: Proposition 9.4 stores each partition's codemod output $C_p$ under the key
     \[
     \bigl(\textsf{codemod},\;H(\langle\text{find},\text{replace},\text{prefix},\text{grant}\rangle),\;\kappa(p,x)\bigr)
     \]
     assuming only that "$\kappa$ is sufficient for search." However, in Proposition 7.2(b)—which line 453 endorses as "the better one" and line 678 adopts—$\kappa(d,x) = \id(x)$ is sufficient for search only because the modified search map function $f_{\mathrm{r}}(x)$ stores paths relative to the partition root and leaves prefixing to $\rho_\delta$. For a codemod, by contrast, $C_p$ depends on the partition prefix $p = d$ in two ways:
     1. By Definition 9.1 (line 517), $C_p$ is a set of file changes *below $p$* (with full paths, so that the reduce is the plain union $C = \bigcup_p C_p$).
     2. By line 520, the map task filters candidate files in partition $(p,x)$ against the job's optional `prefix` argument and the caller's `grant`. Both `prefix` and `grant` in $H(\langle\text{find},\text{replace},\text{prefix},\text{grant}\rangle)$ are job-wide constants, not the partition's prefix $p$.
     Consequently, if a commit contains two identical top-level directories `a/` and `b/` ($\id(x_a) = \id(x_b)$) and a caller runs a codemod with `prefix = "a/"` or a grant restricted to `a/`, partition `a` produces non-empty edits under `a/` while partition `b` produces $\emptyset$, yet both partitions receive the exact same retry key under $\kappa(d,x) = \id(x)$.
   - *Fix*: Include the partition prefix $p$ inside the digest of Proposition 9.4:
     \[
     \bigl(\textsf{codemod},\;H(\langle\text{find},\text{replace},\text{prefix},\text{grant},p\rangle),\;\kappa(p,x)\bigr).
     \]
     Because $p$ and $\kappa(p,x)$ together determine both the partition location $p$ and the subtree $x$, this key is sufficient for $(p,x) \mapsto C_p$ under both Repair (a) and Repair (b).

2. **Proposition 8.1 (lines 473–480) does not account for the 200-version blame window (line 482) or the 5,000-commit history cap (line 469)**:
   - *Location*: Lines 469–484.
   - *Problem*: Proposition 8.1 asserts that "`blame` returns $\mathrm{own}_m$ paired with the lines of $v_m$" and that blame satisfies the parent-recursive relation $\mathrm{Blame}(c)=\mathrm{update}(\mathrm{Blame}(c'),\mathrm{diff}(v(c'),v(c)),c)$ when $c$ changes the file relative to $c' = \pi_1(c)$. As noted on line 482, however, the implemented `blame` operation requests `path_history` with a default limit of 200 versions (and `path_history` walks at most 5,000 first-parent commits, line 469), attributing all lines surviving from before the 200-version window to the oldest retained version $c_0$. When a file has more than 200 versions, advancing from $c'$ to $c$ shifts the window boundary $c_0 \to c_1$, so $\mathrm{Blame}(c)$ does *not* equal $\mathrm{update}(\mathrm{Blame}(c'),\mathrm{diff}(v(c'),v(c)),c)$ for the truncated function.
   - *Fix*: State explicitly in Proposition 8.1 that $v_0, \ldots, v_m$ is the *untruncated* first-parent version sequence of the file (or a sequence within the 200-version/5,000-commit bounds without file deletion and recreation), and note on line 484 that memoizing the parent-recursive fold under $(\id(c), p)$ eliminates the 200-version window altogether. Also note in the proof (line 480) that because $\mathrm{Blame}(c')$ pairs $\mathrm{own}_{m-1}$ with the lines $v(c')$, $\mathrm{update}$ is a function of $(c, \mathrm{Blame}(c'))$ alone, matching Definition 4.1.

3. **Incompleteness of the root-files key $\kappa(\varepsilon, F)$ with respect to file modes (lines 137, 327–329)**:
   - *Location*: Line 137 and Proposition 5.7 (lines 319–331).
   - *Problem*: Line 137 defines $\kappa(\varepsilon,F)=\text{\code{files-}}\,\|\,H(\lambda(F))$, where $\lambda(F)$ lists each root file's name and blob id, omitting the file mode (contrast Lemma 2.2 on line 103 and file partitions on line 678, both of which include mode). If a derivation kind's map function $f_\delta(\varepsilon, F)$ depends on file modes, $\kappa(\varepsilon, F)$ is not sufficient. Furthermore, in Proposition 5.7 (line 328), a commit that changes only the mode of a root file puts that file in $\W_v$ (so $\varepsilon \in \Pfx(\W_v)$) without changing $\kappa(\varepsilon, F)$, providing a second source of strict inclusion beyond the one described on line 331.
   - *Fix*: Clarify on line 137 that $\lambda(F)$ omits modes because search and symbol extraction depend only on paths and blob ids, and note that any mode-dependent kind must include mode in $\lambda(F)$ (or hash the root tree's non-directory entries with modes).

4. **Ambiguity in "ordered by prefix" for the empty prefix $\varepsilon$ vs. `platform_derived.rs::plan` (lines 141, 216, 410, 827)**:
   - *Location*: Definition 3.2 (line 141), Definition 4.3 (line 216), Section 6 (line 410), and Appendix A (line 827).
   - *Problem*: Definitions 3.2 and 4.3 define the family of prefixed segments as "ordered by prefix." Under standard lexicographic order, the empty prefix $\varepsilon$ of the root-files partition comes *first* ($\varepsilon < d_i$). In the reference implementation (`platform_derived.rs::plan`, line 827), however, directory partitions are emitted first in Git tree order and the root-files partition is emitted *last*. Because search truncates results at the query limit in partition order (line 410), the ordering affects $D_\delta(c)$ whenever matches exceed the limit.
   - *Fix*: Specify in Definition 3.1 or 3.2 that prefixes are ordered with directory prefixes $d_1 < \dots < d_r$ in tree-entry order followed by the root-files prefix $\varepsilon$ (or define "ordered by prefix" to refer to that canonical order).

---

#### Minor Issues

1. **Missing positivity hypotheses in Proposition 11.1 (lines 661–668)**:
   - *Location*: Lines 663–667.
   - *Problem*: The existence and uniqueness of $g^* = \sqrt{b/a}$ on $(0, \infty)$ requires $a > 0$ and $b > 0$ (i.e., $N, \tilde\lambda_c, u, c_i, c_\ell > 0$). If $\tilde\lambda_c = 0$ (a read-only period with $\lambda_q > 0$), $a = 0$ and $C(g) = k + b/g$ has no minimizer on $(0, \infty)$, attaining its minimum only at the upper endpoint of a bounded feasible interval $[1, N]$.
   - *Fix*: State $N, \tilde\lambda_c, u, c_i, c_\ell > 0$ in Proposition 11.1.

2. **Root-commit convention in Definition 4.4 (lines 219–222)**:
   - *Location*: Line 221.
   - *Problem*: Definition 4.4 defines a change-local kind at $c$ as a function of $\tree(\pi_1(c))$ and $\tree(c)$ alone, without specifying $\tree(\pi_1(c))$ when $c$ is a root commit (whereas Definition 4.3 on line 216 explicitly specifies the root-commit convention).
   - *Fix*: Add "with $\tree(\pi_1(c))$ taken to be the empty tree when $c$ is a root commit" on line 221.

3. **Size-1 cycles (self-loops) in Step 1 of the planner vs. prose on line 606**:
   - *Location*: Lines 581, 606, and 857.
   - *Problem*: Step 1 (line 581) merges items touching a strongly connected component "with more than one node," whereas line 606 states that the plan "has one work item per written cycle shared by several items." A self-referential symbol $(u, u) \in E$ forms a written cycle of length 1 (an SCC of size 1), which Step 1 does not merge. (Theorem 10.2 still holds because two items touching $u$ where one writes $u$ overlap directly on $u$ and are ordered into distinct stages by Step 4.)
   - *Fix*: Say "one work item per multi-symbol written cycle shared by several items" on line 606.

4. **Prose house-style violations in additional paragraphs (lines 72, 83, 212, 535, 552, 788)**:
   - *Line 72*: Splits focus across four claims (cloud portability, authorial history of YonedaRepo, top-level directory keying, and the 3/1/0 test). Split into one paragraph on the reference realization's partitioning scheme and test, moving authorial status to the evidence or limitations section.
   - *Line 83*: Opens with vague metacommentary ("The evidence is uneven."). State the finding directly: "Tests verify the correctness properties at commit `cfa4845`, whereas only commit-time derivation and warm-start seeds have timing data."
   - *Line 212*: Ends with metatextual signposting ("The reuse arguments of Section 5 work on segments, not on reduced values, so they need a name for the family of segments."). Delete or fold into Definition 4.3.
   - *Line 535*: Opens with signposting ("The more consequential property concerns concurrency."). Replace with the direct claim: "An unscoped codemod that declares no read set permits write skew under backward validation."
   - *Line 552*: Opens with signposting ("Partial failure is the remaining gap between design and code."). Replace with the direct claim: "Retrying a failed partition without repeating replacements across the repository requires memoizing the codemod's map outputs."
   - *Line 788*: Combines two unrelated limitations (unverified code assumptions of Theorem 5.3 and partial-failure availability). Split or unify under model-to-code scope.

5. **LaTeX and formatting issues (lines 22, 422, 815–865, 890–940, 958–1047)**:
   - *Line 22*: `\usepackage{cleveref}` is loaded but never used; either use `\cref`/`\Cref` or remove the package.
   - *Line 422*: The TypeScript template literal `` `derived/v1/${repo}/search/${key}` `` inside `lstlisting` uses raw backticks without `\usepackage{upquote}`, which renders backticks as curly left single quotes under `T1`/`lmodern`. Add `\usepackage{upquote}` to the preamble.
   - *Lines 815–865 (`tab:pdd:evidence`)*: Every row of the `Commit` column repeats `\code{cfa4845}`, which line 812 already states globally. Removing the redundant column and widening `Claim`, `File`, and `What the code shows` will eliminate cramped path wrapping in column 2 and match the full `\textwidth` of the `tabularx` tables.
   - *Lines 890, 907, 923, 940 (`lst:pdd:prefixtest`)*: Four lines in Listing 2 exceed 100 characters and rely on `breaklines=true` to wrap mid-expression; break them manually at `.map(...)` / `.iter()` boundaries.
   - *Lines 958, 964, 970, 976, 1004, 1010, 1025, 1031, 1042, 1047*: Replace single hyphens in page ranges (`3411-3424`, `1-10`, etc.) with en-dashes (`3411--3424`, `1--10`, etc.).

VERDICT: MAJOR REVISIONS (major issues remain)
