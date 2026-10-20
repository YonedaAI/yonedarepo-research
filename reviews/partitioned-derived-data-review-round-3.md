---
reviewer: Gemini 4 Argon (High)
paper: partitioned-derived-data
round: 3
date: 2026-10-20T17:40:50Z
---


### Overview

This paper (Part II of *Source Control as a Data System*) models repository derived data—code search indexes, symbol tables, blame, path history, review classifications, check runs, and partitioned codemods—as partitioned map-reduce jobs over immutable Git snapshots in YonedaRepo. Its central theoretical contribution, Theorem 5.3, establishes that incremental reuse of content-addressed partition segments equals full recomputation under arbitrary concurrency whenever the partition key determines the map output (*key sufficiency*). Using this criterion, the author identifies a real bug in YonedaRepo's search indexer (Section 7): directory partitions are keyed by bare Git subtree ID while segments store full paths including the directory prefix, causing silent path misattribution, grant-filtering bypasses, and codemod failures when top-level directories are renamed or duplicated. The paper also analyzes write-skew anomalies in partitioned codemods (Section 8), proves staging and representation-invariance properties of the symbol-level plan DAG (Section 9), and adapts a convex granularity model to size-bounded recursive partitioning (Section 10).

The paper's core mathematical framework is clean, its honesty about system limitations and unmeasured quantities is exemplary, and the discovery, formalization, and executed test of the search-key prefix defect (Section 7 and Appendix B) are standout contributions. However, several formal statements contain technical flaws or unstated encoding assumptions, key proofs rely on unstated theorems from an unpublished companion manuscript (Part I), empirical measurements of derived-data jobs are nearly absent, and several paragraphs violate the house style by bundling disparate claims or burying formal definitions in transitional prose.

---

### Evaluation by Dimension

#### 1. Mathematical Correctness
The main correctness theorem (Theorem 5.3), the necessity result (Proposition 5.4), the work and pruning bounds (Propositions 5.6, 5.7, and 10.2), the blame fold (Proposition 7.3), and the graph-coloring reduction for stage minimization (Proposition 9.3) are mathematically sound. Nevertheless, several formal statements need correction or tightening:
- **Proposition 8.3 (lines 530–532)** states a false implication when $q/$ is a top-level directory (detailed under Major Issues below).
- **Proposition 8.4 (lines 546–557)** constructs a hash key over four variable-length arguments without specifying an injective tuple encoding, unlike Proposition 7.2(a), which carefully invokes fixed-width ID encoding (line 443).
- **Assumption 2.1 (lines 96–99)** assumes collision resistance only for stored Git object IDs, whereas Propositions 7.2(a), 8.4, and 9.6 also require collision resistance for the platform digest $H$.
- **Proposition 7.5 (lines 488–495)** bounds bisect check executions by $\lceil \log_2 n \rceil$ over $n$ candidates $x_1, \dots, x_n$, which holds only if the bad endpoint $x_n = b$ is treated as known-failing without requiring a check execution during bisect.
- **Line 210** writes $D_\delta(c) = \rho_\delta(F_\delta(c))$ "after the keys are dropped," which is a type mismatch between $F_\delta(c)$ (a family of triples) and the domain of $\rho_\delta$ (families of pairs in Definition 3.2, line 143).

#### 2. Clarity
The paper is exceptionally clear in mapping abstract definitions to concrete Rust and TypeScript functions (`platform_derived.rs::plan`, `repo-derived.ts::searchSegments`, `txlog/plan.rs`). Figure 1 and Tables 1–2 orient the reader quickly. Clarity suffers only where formal objects from Part I (`\bowtie`, coarsening, combiner batch acceptance rules, and numbered invariants I5, I6, I10, I12, I14) are invoked by number without restating their definitions.

#### 3. Completeness
The theoretical treatment of YonedaRepo at commit `cfa4845` is thorough, and Appendix A provides an exemplary traceability matrix linking every system claim to source files. Empirical completeness, however, is weak (Section 12, lines 736–760):
- There are no measurements of search segment build time, segment byte size, R2 lookup latency, codemod latency, or plan DAG computation time.
- The warm-start seed numbers (lines 501–504; Table 4, lines 749–750) are cited from a commit message with no raw logs on disk.
- The workerd test suite count (line 706) comes from a log that omitted the git revision, and the commit-time derivation timings (line 736) come from a branch commit (`ebbee09`) rather than the analyzed commit (`cfa4845`).
- The prefix-defect test in Appendix B exercises the Rust compute layer (`search_plan` and `index_partition`), while the downstream effects on `keepAllowed` grant filtering and `codemod` commit preparation were only traced by reading the TypeScript adapter (lines 435, 782).

#### 4. Logical Structure
The progression from read jobs (Sections 3–7) to write jobs (Section 8), semantic planning (Section 9), partition granularity (Section 10), and garbage collection (Section 11) is mostly logical, with two structural flaws:
- **Section 6 ("Search as a partitioned read job") and Section 7 ("The prefix defect in the search key")** split a single subject across two sections while Section 8 ("History-dependent kinds", labeled `sec:pdd:history` on line 456) sits *after* the search bug and bundles four weakly related subsystems: path history, blame, exact rename detection (which is change-local, not history-dependent, line 482), policy-dependent check results, bisect, and warm-start seeds (which are content-local, line 499).
- **Section 11 ("Vacuum", lines 687–702)** concerns object-store reference retention (`refs/yoneda/c/<commit>`) rather than partitioned derived data; it reads as a stray appendix from Part I rather than an organic part of Part II's argument.

#### 5. LaTeX Quality
The LaTeX source is clean, compiles without structural hacks, and uses semantic macros (`\tree`, `\R`, `\W`, `\Pfx`, `\Keys`, `\Ch`, `\Eval`, `\dom`) effectively. Specific typographical and package defects exist in the bibliography (single hyphens instead of en-dashes for all page ranges), unused packages (`cleveref`), and math-mode text macros (detailed under Minor Issues).

#### 6. Prose Quality and House Style
Much of the paper achieves high density and directness. It avoids throat-clearing phrases ("In this section, we will...") and states technical mechanisms plainly. However, several paragraphs violate the house style:
- **Multiple claims per paragraph**: Transitional and post-proof commentary paragraphs frequently staple together three or four distinct points—such as cost-bound interpretation, implementation details, forward references, and invariant checks—into a single block (e.g., lines 210, 308, 403, 525, 683, 788).
- **Findings stated after setup or qualification**: In several places (e.g., lines 210, 453, 615, 683), the paragraph opens with background context or proof continuation and delays the main claim until the final sentence.
- **Signposting**: Sentences such as *"The interesting question is how much of the recomputation can be skipped, and the answer depends on the key function"* (line 210), *"Both terms reappear in the granularity model of Section 10"* (line 308), and *"The relation between parent recursion and content addressing is now a corollary"* (line 330) are pure structural signposting.

---

### Weakest Three Paragraphs and Model Rewrite

#### 1. Paragraph 1 (Line 210)
> Every kind of the form in Definition~\ref{def:pdd:kind} is content-local, since $\Pi(c)$ is a function of $\tree(c)$. For a content-local kind the parent-recursive definition can be satisfied by recomputing from the tree. The interesting question is how much of the recomputation can be skipped, and the answer depends on the key function. The reuse arguments of Section~\ref{sec:pdd:incremental} work on the family of segments rather than on the reduced value, so we name it: the \emph{derived state} of a content-local kind at $c$ is $F_\delta(c)=\langle (p,\kappa(p,x),f_\delta(p,x))\rangle_{(p,x)\in\Pi(c)}$, and $D_\delta(c)=\rho_\delta(F_\delta(c))$ after the keys are dropped.

**Why it fails the house style:** It packs three separate moves into one paragraph (verifying that Definition 3.2 is content-local, signposting the question of Section 5, and introducing a formal definition needed later in Proposition 5.8), includes rhetorical filler (*"The interesting question is..."*), delays its main technical definition until the last clause, and commits a type error in $D_\delta(c)=\rho_\delta(F_\delta(c))$ that it has to patch in prose (*"after the keys are dropped"*).

#### 2. Paragraph 2 (Line 308)
> The bound counts changed partitions, not changed files. A one-line edit in a directory of 20,000 files re-indexes all 20,000. The bound also charges a lookup for every partition on every evaluation, including partitions that did not change. In the implementation each lookup is an R2 get inside the query's Worker invocation. Both terms reappear in the granularity model of Section~\ref{sec:pdd:granularity}. The store-retention hypothesis holds in the code at \code{cfa4845}: the platform adapter contains no deletion of keys under \path{derived/}.

**Why it fails the house style:** It has no single governing claim. It starts with the coarseness of map work per partition, pivots to per-partition R2 lookup overhead, inserts a signpost to Section 10 (*"Both terms reappear..."*), and ends with an unrelated code-audit verification of Proposition 5.6's store-retention assumption.

#### 3. Paragraph 3 (Line 403)
> Case folding is ASCII only, so a query that differs from the content in the case of a non-ASCII letter is not a match, in the index or in line matching. The superset is then narrowed by exact line matching on the verified blob. Two limits on completeness follow from the code. Files over 1~MiB and binary files are never content candidates, so their contents are never searched; they match only by path. A partition with more than 20,000 files has no segment at all and is reported as skipped. Both limits are reported to a search caller, the second through \code{skipped\_partitions}. The reduce is a concatenation with a limit, so the result order depends on partition order and on the order of files within a segment.

**Why it fails the house style:** It is a four-topic catalog (ASCII case folding, blob line verification, size caps on files and partitions, and result ordering in the reduce step) assembled into one paragraph without a unifying claim.

#### Model Rewrite (of Line 308, split into two focused paragraphs)
> Proposition~\ref{prop:pdd:cost} exposes the tension between rebuild work and lookup overhead as partition size varies. Map work scales with the size of each changed partition rather than the size of the edit, so a one-line change in a 20,000-file directory re-indexes all 20,000 files. Conversely, lookup work scales with the total number of partitions $|\Pi(c)|$, because the evaluator issues one R2 \code{get} per partition inside the Worker invocation even for unchanged directories.
>
> The proposition's no-deletion hypothesis holds at commit \code{cfa4845}: the platform adapter never deletes keys under \path{derived/}.

---

### Structured Feedback by Severity

#### Critical Issues
None. The paper's core theorems and its central counterexample (the search prefix defect) are valid and reproducible.

#### Major Issues

1. **False sufficiency claim in Proposition 8.3 (lines 530–532).**
   Lines 531–532 state: *"Suppose that the top-level partition containing $q/$ is within the indexing cap of 20,000 files both at $v$ and immediately before the landing, which holds automatically when $q/$ is itself a top-level directory."* As written, the non-restrictive clause claims that a top-level directory $q/$ is automatically within the 20,000-file cap at both versions—which is false if $q/$ already exceeds 20,000 files at version $v$. As the proof (line 535) shows, what holds automatically when $q/$ is a top-level directory and $\R=\{q/\}$ is validated is the *preservation* of the file count from $v$ to the landing snapshot: if $q/$ is within the cap at $v$, it remains within the cap immediately before landing. Rewrite lines 531–532 to state: *"Suppose that the top-level partition containing $q/$ is within the indexing cap of 20,000 files at $v$, and also immediately before the landing (the second condition follows from the first when $q/$ is a top-level directory)."*

2. **Uninjective tuple hashing in Proposition 8.4 (lines 546–557).**
   Line 550 defines the codemod retry key using $H(\text{find},\text{replace},\text{prefix},\text{grant})$, and line 556 asserts in the proof that this key determines the arguments `find`, `replace`, `prefix`, and `grant`. Because all four arguments have variable length, naive concatenation before hashing allows boundary collisions (for example, `find = "ab", replace = "c"` versus `find = "a", replace = "bc"`) even when $H$ is collision-resistant. Specify an unambiguous length-prefixed or delimiter-escaped serialization before applying $H$, matching the care taken with fixed-width IDs in the proof of Proposition 7.2(a) (line 443).

3. **Security understatement in the grant-bypass analysis of the prefix defect (line 429).**
   Line 429 concludes: *"The leaked bytes are bytes the first caller could read at the earlier commit, which limits the harm but not the violation."* This assumes the segment was populated by an earlier commit on the same branch to which the caller already had access. fails in two realistic scenarios: (a) an administrator moves sensitive files out of `src/` into `lib/` *before* granting an external principal read access to `src/` at the new head; and (b) the segment at key $\id(x)$ was populated under `src/` on a restricted branch or fork that the caller was never authorized to read, and is then reused when `lib/` has tree $x$ on a branch the caller can query. State this stronger security consequence directly.

4. **Incomplete specification of size-bounded single-file partitions (lines 672–681).**
   Line 672 defines the recursive partitioning rule: *"make a file whose parent directory has more than $g$ files a partition of its own. Keys remain subtree ids, made sufficient by repair (b) of Proposition~\ref{prop:pdd:repairs}."* A single file is a blob, not a subtree, so its key cannot be a subtree ID (moreover, if two executable and non-executable files in the same large directory have the same blob ID, or if the file's mode matters, a bare blob ID omits the mode). Furthermore, repair (b) records paths relative to the partition root and prepends $d/$ during reduce; for a single-file partition at path $p$, the relative path must be $\varepsilon$ so that prepending $p$ reconstructs the file path. Define $\kappa$ and $f_{\mathrm{r}}$ explicitly for single-file partitions in Section 10.

5. **Non-self-contained proofs depending on Part I (lines 88–92, 534–536, 697–699).**
   The proofs of Proposition 8.3 (lines 534–536) and Proposition 11.1 (lines 697–699) rely directly on Part I's Definition 4.15, Theorem 5.4, Theorem 6.4, Theorem 7.3, Proposition 7.4, and Invariants I5, I6, I10, I12, and I14. Because Part I is an unpublished author's manuscript (line 1003), a reader cannot verify these proofs as written. Add a concise formal statement (or summary lemma in Section 2) of the exact pre- and post-conditions of backward validation (Part I, Definition 4.15 and Theorem 6.4), combiner batch serializability (Part I, Proposition 7.4), and first-parent reachability (Part I, Theorem 5.4).

6. **Misplaced content-local and change-local kinds in Section 7 ("History-dependent kinds", lines 455–505).**
   Section 7 is titled *"History-dependent kinds"*, yet its second half analyzes exact rename detection (line 482, explicitly noted as change-local), check results and bisect (lines 484–498, policy-dependent), and warm-start seeds (lines 499–504, explicitly noted as content-local). Either rename Section 7 to cover non-search derived kinds (e.g., *"History-, change-, and policy-dependent kinds"*) and move warm-start seeds to Section 3 or 4, or split history-dependent kinds from check/seed derivations.

7. **Missing microbenchmarks for implemented Rust operations (lines 736–760).**
   While hosted end-to-end measurements are deferred to Part III, the author already extracted and ran the Rust workspace at commit `cfa4845` on 20 October 2026 to execute the integration test in Appendix B (line 862). Running a local benchmark in that same environment to measure `index_partition` cost per file ($c_i$), segment byte size per file, and `plan` duration as a function of work-item count $m$ would supply concrete values for the model parameters in Sections 9 and 10 instead of leaving all performance claims untested.

#### Minor Issues

1. **Scope of Assumption 2.1 (Collision resistance, lines 96–99).**
   Assumption 2.1 states collision resistance only for stored Git objects (`id`), whereas line 137, Proposition 7.2(a) (line 443), Proposition 8.4 (line 550), and Proposition 9.6 (line 637) also require collision resistance for the platform digest $H$. Extend Assumption 2.1 to include $H$.

2. **Type mismatch in the definition of derived state $F_\delta(c)$ (line 210) and root-commit edge case in Proposition 5.8 (lines 332–339).**
   Line 210 defines $F_\delta(c)=\langle (p,\kappa(p,x),f_\delta(p,x))\rangle_{(p,x)\in\Pi(c)}$ and writes $D_\delta(c)=\rho_\delta(F_\delta(c))$ *"after the keys are dropped."* Define the projection $\pi_{1,3}(p,k,s) = (p,s)$ explicitly or promote $F_\delta(c)$ to a numbered Definition so Proposition 5.8 does not depend on an informal inline definition. In Proposition 5.8 (line 333), specify that $\Pi(c') = \emptyset$ when $c$ is a root commit so that part (a) satisfies Definition 4.1's base case (line 200).

3. **Implicit endpoint assumption in Proposition 7.5 (Bisect, lines 488–495).**
   State explicitly in Proposition 7.5 that the bad commit $b = x_n$ is known to fail under the current policy digest before bisect begins (or that checking $b$ is excluded from the step count). Otherwise, if $x_n$ itself must be executed when the candidate range narrows to $(x_{n-1}, x_n]$, worst-case binary search over $n$ untested elements takes $\lfloor \log_2 n \rfloor + 1$ executions, which exceeds $\lceil \log_2 n \rceil$ whenever $n$ is a power of two.

4. **Unspecified union rule for joint items and relationship between $N$ and $\mathcal{C}$ in Section 9 (lines 566–577, 617–620).**
   - In Step 1 (line 573), state explicitly that merging items into a joint item $k$ sets its initial read and write sets to the unions of its members' coarsened read and write sets.
   - In Definition 9.1 (line 568) and Proposition 9.4 (line 619), clarify that coarse files $\mathcal{C}$ have no symbol nodes in $N$ (so any symbol entry naming a node in $N$ necessarily lies outside $\mathcal{C}$).

5. **Redundant condition in the proof of Proposition 10.2 (line 680).**
   Line 680 states: *"Take such a partition of $c$ with neither $r$ nor its parent in $A$."* Because $A$ is prefix-closed (every proper prefix of a path in $\W_v$ has all of its ancestor directories in $A$), if $r$'s parent $d$ is not in $A$, then $r$ cannot be in $A$ either. Noting that $A$ is upward-closed simplifies the case analysis.

6. **Ambiguous definition of $u$ under coalescing in Proposition 10.1 (lines 657–660).**
   Line 657 defines $u$ as *"the mean number of partitions per landing that derivation must rebuild, independent of $g$, where landings coalesced into one derivation job that change the same partition count it once."* Defining $u$ per landing while discounting coalesced duplicates makes $u$ an implicit function of the coalescing ratio $\tilde{\lambda}_c / \lambda_c$. Define $u$ instead as the mean number of partitions rebuilt *per derivation job* (giving $a = \tilde{\lambda}_c u c_i$), which separates the job arrival rate $\tilde{\lambda}_c$ from the per-job partition footprint $u$.

7. **Bibliography page-range dashes (lines 949, 955, 961, 967, 995, 1001, 1007, 1013, 1029, 1035).**
   All ten page ranges in `\begin{thebibliography}` use a single hyphen (`3411-3424`, `1-10`, `61-71`, `1601-1614`, `157-166`, `85-103`, `369-378`, `1-29`, `146-160`, `15-28`) instead of a LaTeX en-dash (`--`).

8. **Unused package and math-mode `\code` calls (lines 22, 137, 363).**
   - Line 22 loads `\usepackage{cleveref}`, which is never used. Either replace manual `Section~\ref{...}` / `Proposition~\ref{...}` strings with `\cref` / `\Cref` or remove the package.
   - Lines 137 and 363 invoke `\code{files-}` directly inside math mode (`$\code{files-}h$`). Wrap it in `\text{\code{files-}}` to avoid font warnings.
   - Line 540 has a stray leading space at the start of the paragraph (` A repository-wide codemod...`), and lines 33–35, 459–460, and 857–858 contain extra blank lines.

9. **Paragraph-level house-style cleanups (lines 210, 308, 403, 525, 683, 788).**
   Split the multi-claim paragraphs at lines 210, 308, 403, 525, 683, and 788 so that each paragraph states one claim in its opening sentence and supports it without signposting.

VERDICT: MAJOR REVISIONS (major issues remain)

### Overview and Evaluation by Dimension

This paper develops a formal model of partitioned derived data over immutable Git snapshots in YonedaRepo, proves that content-addressed partition reuse equals full recomputation if and only if the storage key is sufficient for the map function, identifies and tests a key-insufficiency bug in the implemented trigram search index, analyzes write skew in partitioned codemods, and establishes staging and invariance properties for the symbol-level maintenance planner.

1. **Mathematical correctness:** The central results—incremental correctness under key sufficiency (Theorem 5.3, lines 266–277), necessity of sufficiency (Proposition 5.4, lines 283–290), the prefix counterexample and its two repairs (Propositions 7.1–7.2, lines 418–444), and the plan DAG properties (Theorem 10.2 and Proposition 10.3, lines 579–609)—are sound and cleanly proved. However, Section 11 contains a direct algebraic error regarding the direction in which path pruning shifts the optimal partition size $g^*$ and conflates the landing rate $\lambda_c$ with the coalesced job rate $\tilde\lambda_c$ (lines 657–668). Several secondary propositions also omit required hypotheses or state boundary conditions imprecisely (lines 531, 619, 672).
2. **Clarity:** The paper is exceptionally clear in connecting formal definitions to concrete Rust and TypeScript functions. The Spark mapping (Table 1, lines 166–185) and the classification of derivation kinds (Table 2, lines 223–244) orient the reader immediately, and the distinction between what the model proves and what the implementation actually does is maintained with admirable candor.
3. **Completeness:** The paper is self-contained within its multi-part series, though its heavy reliance on imported definitions and theorems from Part I (lines 88–92, 531–538, 694–699) leaves a few proof steps opaque to a standalone reader. As the author candidly acknowledges (lines 83, 760, 782–784), empirical performance data for indexing, R2 lookups, codemods, and planning are absent, and the end-to-end search and codemod failures under the prefix defect were traced by inspection of the TypeScript adapter rather than executed in `workerd`.
4. **Logical structure:** The progression from read jobs (Sections 3–8) to write jobs (Section 9), semantic planning (Section 10), partition granularity (Section 11), and garbage collection (Section 12) is logical, though Sections 10 and 12 (the static symbol planner and hidden-ref vacuuming) sit outside the core partition-derivation model of Sections 3–7 and read as loosely coupled subsystems.
5. **LaTeX quality:** The manuscript compiles cleanly and uses macros consistently, with minor issues: `cleveref` is loaded (line 22) but never used, the `longtable` in Appendix A (line 805) is narrower than `\textwidth` and packs 54-character file paths into a 4.1 cm column, `\code` is invoked inside math mode (lines 137, 363), and page ranges in the bibliography use hyphens instead of en-dashes (lines 942–1025).
6. **Prose quality (House Style):** Most of the manuscript adheres well to the house style: sentences are direct, active, and free of academic throat-clearing, and limitations are stated plainly before qualification. The main departures are multi-claim "catch-all" paragraphs at the ends of sections (lines 210, 403, 525, 683, 788) that bundle three or four unrelated caveats without a governing claim, and one-sentence signposting paragraphs used as transitions (lines 88, 112, 212, 281, 330, 628, 765).

---

### Structured Feedback by Severity

#### Critical Issues

None. All issues identified below can be resolved without invalidating the paper's core theorems or architecture.

#### Major Issues

1. **Inverted comparative static and rate mismatch in the partition granularity model (Section 11, lines 655–668).**
   - *Sign error on $g^*$ (line 668):* Proposition 11.1 (lines 659–661) defines the expected cost $C(g) = k + ag + b/g$ with $a = \lambda_c u c_i$, $b = (\tilde\lambda_c + \lambda_q) N c_\ell$, and unique minimizer $g^* = \sqrt{b/a}$. Line 668 then states that pruning derivation lookups by touched paths moves $\tilde\lambda_c u c_\ell$ into $k$, "which leaves $b = \lambda_q N c_\ell$ and a larger optimum $g^*$." Because $\tilde\lambda_c > 0$, pruning *decreases* $b$ from $(\tilde\lambda_c + \lambda_q) N c_\ell$ to $\lambda_q N c_\ell$ while leaving $a$ unchanged, which makes $g^* = \sqrt{b/a}$ **smaller**, not larger. Intuitively, when derivation jobs no longer pay a lookup per partition, having more partitions is cheaper, shifting the optimum toward finer partitions.
   - *Rate mismatch between $\lambda_c$ and $\tilde\lambda_c$ (lines 657–668):* Line 657 defines $u$ as "the mean number of partitions per landing that derivation must rebuild... where landings coalesced into one derivation job that change the same partition count it once," and multiplies $u$ by the landing rate $\lambda_c$ in $a = \lambda_c u c_i$. Line 668 then treats the same $u$ as the number of changed partitions *per coalesced job* and multiplies it by the job rate $\tilde\lambda_c$ to get $\tilde\lambda_c u c_\ell$. Unless $\tilde\lambda_c = \lambda_c$, $u$ cannot be both per-landing and per-job. Define $u$ per coalesced derivation job so that $a = \tilde\lambda_c u c_i$ and the pruned lookup term is $\tilde\lambda_c u c_\ell$.

2. **Missing sufficiency hypothesis and imprecise cap condition in Proposition 9.3 (Section 9, lines 529–536).**
   - Unlike Proposition 9.2 (line 518), which explicitly assumes that the search key is sufficient, Proposition 9.3 (`prop:pdd:serializable`, lines 529–532) omits this assumption even though its proof (line 535) relies on search segments accurately reflecting the candidates below $q/$.
   - Line 531 states: "Suppose that the top-level partition containing $q/$ is within the indexing cap of 20,000 files both at $v$ and immediately before the landing, which holds automatically when $q/$ is itself a top-level directory." Being within the 20,000-file cap at both versions does not hold automatically when $q/$ is a top-level directory; if $q/$ has 25,000 files at $v$, it exceeds the cap at both versions. What holds automatically when $q/$ is top-level and validation succeeds is that the file count of $q/$ is *unchanged* between $v$ and landing, so being within the cap at $v$ implies being within the cap before landing. State the assumption at $v$ first, then note that validation preserves it when $q/$ is a top-level directory.

3. **Underspecified keys and file-level partitions in the size-bounded recursive partitioning scheme (Section 11, lines 672–681).**
   - Line 672 proposes making "a file whose parent directory has more than $g$ files a partition of its own" and states immediately afterward that "[k]eys remain subtree ids, made sufficient by repair (b) of Proposition 7.2." A single file is a blob entry, not a subtree, so its key cannot be a subtree id. Moreover, if the key is a bare blob id and the segment records file metadata or mode, two files with identical content but different executable modes (`100644` vs. `100755`) would collide unless mode is included or ignored. Specify the exact key and relative-path convention for single-file partitions in Definition 3.1's terms.

4. **Undefined extension of $\varphi$ to non-graph symbol entries in Proposition 10.4 (Section 10, lines 617–624).**
   - Proposition 10.4 (`prop:pdd:invariance`, line 619) defines $\varphi$ as "a bijection between the symbols of two repository layouts" (i.e., between the node sets $N_1$ and $N_2$ of $G_s$) and then says "Extend $\varphi$ to symbol access entries." In Definition 10.1 (line 568), a work item's declared symbol entry `path#symbol` need not already exist in $N$ at the plan revision (for example, when a work item adds a new symbol or names a container whose children are in $N$). Either restrict Proposition 10.4 to symbol entries that name nodes in $N$, or define $\varphi$ on the ambient space of qualified symbol paths.

5. **Overstatement of the access-control bound in the prefix defect analysis (Section 7, line 429).**
   - Line 429 argues that when `src/` is renamed to `lib/` and a caller with a grant for `src/` but not `lib/` receives matches from `lib/`, "[t]he leaked bytes are bytes the first caller could read at the earlier commit, which limits the harm but not the violation." This qualification holds only if the segment was populated from an earlier commit on the same branch to which that caller also held a grant. Under the duplicated-directory scenario of line 431 (where `src/` and `lib/` coexist in a single commit), or when the segment was populated by another branch or fork to which the caller never had access, the leaked bytes need never have existed under `src/` in any commit the caller was authorized to read. State the condition under which the harm is limited.

#### Minor Issues

1. **Implicit distinctness in Theorem 10.2(b)–(c) and Proposition 10.3 (Section 10, lines 584–585, 604).**
   - Theorem 10.2(b) and (c) quantify over "[t]wo joint items" and "every pair of joint items that are not independent." Because any item with a non-empty write set overlaps itself ($\W_k \bowtie \W_k$) and is therefore not independent of itself, add "distinct" in (b), (c), and Proposition 10.3 (line 604).

2. **Informal notation for $\rho_\delta(F_\delta(c))$ (Section 4, line 210).**
   - Line 210 defines $F_\delta(c) = \langle (p, \kappa(p,x), f_\delta(p,x)) \rangle_{(p,x)\in\Pi(c)}$ as a family of triples and writes "$D_\delta(c) = \rho_\delta(F_\delta(c))$ after the keys are dropped." Because $\rho_\delta$ is typed on pairs $(p, s)$ in Definition 3.2 (line 141), define the projection explicitly or define $F_\delta(c)$ so its image matches the domain of $\rho_\delta$.

3. **Canonical ordering in Lemma 2.2 (Section 2, lines 106–108).**
   - Line 107 states that "recursively equal trees serialize to the same bytes and hash to the same id." Note briefly that this relies on Git's canonical sorting of tree entries by name and mode.

4. **One-sentence signposting paragraphs (lines 88, 112, 212, 281, 330, 628, 765).**
   - These seven one-line paragraphs (`This Part uses Part~I's objects without redefining them.`, `Commit ids carry the same guarantee for history.`, `Two further classes of kinds occur in the platform.`, `Sufficiency is also necessary, in the following sense.`, `The relation between parent recursion and content addressing is now a corollary.`, `A symbol handle is the planner's counterpart at edit time.`, `The problem of keeping a derived value current as its inputs change has three established treatments, and this Part sits between them.`) are pure structural signposts rather than paragraphs advancing a supported claim. Fold each into the adjacent paragraph or drop it before the formal environment.

5. **LaTeX and typographical fixes (lines 22, 137, 363, 459–460, 540, 644, 805, 942–1025).**
   - Line 22: `\usepackage{cleveref}` is loaded but never used; either use `\cref`/`\Cref` or remove the package.
   - Lines 137 and 363: `\code{files-}` is placed inside math mode (`$\kappa(\varepsilon,F)=\code{files-}\,\|\,H(\lambda(F))$` and `$\code{files-}h$`). Use `\text{\code{files-}}` or place `\code{files-}` outside `$...$`.
   - Lines 459–460, 540, 644: Remove the extra blank line at 459–460, the leading space at line 540, and the trailing space at line 644.
   - Line 805: In Appendix A (`tab:pdd:evidence`), the `longtable` column widths sum to $14.2\text{ cm}$ plus intercolumn spacing ($\approx 15.5\text{ cm}$), leaving the rules ~1 cm narrower than `\textwidth` ($16.51\text{ cm}$), and `L{4.1cm}` forces 54-character Rust paths to wrap across three lines. Widen the file column (or strip the common prefix `backend/crates/` in the table caption) so the table spans `\textwidth`.
   - Lines 942, 948, 954, 960, 991, 997, 1003, 1019, 1025: Replace single hyphens in page ranges (`3411-3424`, `1-10`, `61-71`, etc.) with en-dashes (`3411--3424`, `1--10`, `61--71`).

---

### Weakest Three Paragraphs and Model Rewrite

#### 1. Line 210 (Section 4)
> Every kind of the form in Definition~\ref{def:pdd:kind} is content-local, since $\Pi(c)$ is a function of $\tree(c)$. For a content-local kind the parent-recursive definition can be satisfied by recomputing from the tree. The interesting question is how much of the recomputation can be skipped, and the answer depends on the key function. The reuse arguments of Section~\ref{sec:pdd:incremental} work on the family of segments rather than on the reduced value, so we name it: the \emph{derived state} of a content-local kind at $c$ is $F_\delta(c)=\langle (p,\kappa(p,x),f_\delta(p,x))\rangle_{(p,x)\in\Pi(c)}$, and $D_\delta(c)=\rho_\delta(F_\delta(c))$ after the keys are dropped.

*Why it fails the house style:* It packs four distinct moves into one paragraph (verifying that Definition 3.2 is content-local, noting trivial satisfaction of Definition 4.1, rhetorical signposting with "The interesting question is...", and forward-referencing Section 5 to motivate a definition), and it buries a formal object ($F_\delta(c)$) needed by Proposition 5.8 at the end of the paragraph using the imprecise phrase "after the keys are dropped."

#### 2. Line 403 (Section 6)
> Case folding is ASCII only, so a query that differs from the content in the case of a non-ASCII letter is not a match, in the index or in line matching. The superset is then narrowed by exact line matching on the verified blob. Two limits on completeness follow from the code. Files over 1~MiB and binary files are never content candidates, so their contents are never searched; they match only by path. A partition with more than 20,000 files has no segment at all and is reported as skipped. Both limits are reported to a search caller, the second through \code{skipped\_partitions}. The reduce is a concatenation with a limit, so the result order depends on partition order and on the order of files within a segment.

*Why it fails the house style:* It has no single controlling claim. It concatenates four unrelated observations about the search implementation: (1) ASCII-only case folding, (2) post-index blob line matching, (3) completeness caps on file size, binary files, and partition file counts, and (4) the dependence of result ordering on partition and file order.

#### 3. Line 525 (Section 9)
> The codemod's result is complete only for indexed files. A file over 1~MiB is never a candidate and is never rewritten, and a partition over 20,000 files is skipped. The codemod's response reports the number of partitions but not which were skipped, so a caller cannot tell that the replacement was partial. Rerunning a codemod on its own output changes nothing exactly when the output contains no occurrence of the find string. The repository's test checks the empty case: a codemod for a string that occurs nowhere returns \code{changed: false}.

*Why it fails the house style:* The paragraph begins with a clear claim about codemod completeness under the indexing caps (first three sentences), then pivots without transition in the final two sentences to an unrelated claim about idempotence and the empty-match unit test.

#### Model Rewrite of Line 403
Splitting the catch-all paragraph at line 403 into two focused paragraphs—one stating the exact scope of search completeness before its qualifications, and one stating how the reduce stage orders and truncates matches—restores one claim per paragraph and puts the finding first:

> Search is complete only for ASCII-folded matches inside indexed partitions and files. Because both the trigram extractor and the line matcher fold case on ASCII bytes alone, queries that differ from file contents in the case of a non-ASCII letter do not match. Moreover, the indexer excludes binary files and files larger than 1~MiB from content postings (matching them only by path) and refuses to build segments for partitions exceeding 20,000 files; the response reports both exclusions to the caller, the latter in \code{skipped\_partitions}.
>
> Within those bounds, the reduce stage returns exact matches in partition and file order up to the query limit. For each candidate returned by the trigram intersection, the evaluator verifies the blob against its id, filters lines by exact substring match, and concatenates the matching lines across partitions until the limit is reached. Because concatenation preserves partition order and each segment's internal file list, the returned subset when matches exceed the limit depends on how the repository is partitioned.

VERDICT: MAJOR REVISIONS (major issues remain)
