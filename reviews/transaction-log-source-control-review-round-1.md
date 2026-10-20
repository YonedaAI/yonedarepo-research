---
reviewer: Gemini 4 Argon (High)
paper: transaction-log-source-control
round: 1
date: 2026-10-20T15:53:48Z
---


# Peer Review: *A Transaction Log for Source Control (Part I of Source Control as a Data System)*

## 1. General Evaluation

- **Mathematical correctness:** The formalization is largely sound and benefits from tight correspondence with an executable implementation. The proofs of replay determinism (Theorem 5.1), tamper evidence (Proposition 5.2), first-parent ref advancement (Theorem 5.4), snapshot immutability (Theorem 5.6), order-insensitive landing under candidate independence (Theorem 6.7), and intra-batch write skew (Theorem 7.3) are valid and insightful. Three formal gaps require revision: (1) Theorem 6.4 states a general serial-equivalence conclusion across all accepted landings on a ref, even though its parts and proof cover only `FastForward` and `Rebase` outcomes and omit `Merge` outcomes; (2) Proposition 7.4 relies on write-path disjointness that is enforced only on net merged paths in the untrusted adapter rather than in the authority's verification; and (3) Definition 4.4 leaves the universal domain of the location tree $\Loc$ across snapshots and the leaf node types underspecified.
- **Clarity:** The paper explains the architectural shift from client-side ref compare-and-swap to server-side commit preparation and log-validated landing with unusual clarity. The distinction between candidate independence as a symmetric scheduling rule and backward validation as an asymmetric safety rule (Section 6.4) is particularly crisp.
- **Completeness:** The paper is commendably candid about implementation gaps uncovered by the formal analysis—trusted checkpoint ref maps (line 343), unchecked writer-supplied base versions (line 429), and intra-batch write skew (lines 590–601)—and provides concrete fixes for each. However, it relies in several places on forward references to unincluded companion papers (Parts II and III) for definitions and safety arguments that affect Part I's model, and its empirical section includes local latency numbers whose raw outputs were not preserved.
- **Logical structure:** The progression from coordination bottleneck (Section 2) to system architecture (Section 3), formal model (Section 4), log invariants (Section 5), optimistic concurrency control (Section 6), batched landing (Section 7), invariant summary (Section 8), and empirical/code evidence (Section 9 and Appendix A) is logical and cohesive.
- **LaTeX quality:** The manuscript is cleanly typeset overall, with well-structured tables and a clear TikZ diagram, but contains several concrete LaTeX defects: an empty math subscript `\Snap{}(r)` (line 439), hyphens instead of en-dashes in every bibliography page range (lines 749–849), justified `p{}` columns instead of ragged-right `L{}` columns in the narrow `longtable` of Appendix A (line 867), unused packages and libraries (`listings`, `cleveref`, `fit`), and duplicate unused labels.
- **Prose quality (House Style):** Sections 1–8 and 10 adhere closely to the house style: sentences are direct, technical claims precede qualifications, nominalizations and signposting are rare, and paragraphs generally develop a single claim. In contrast, Section 9 (Evidence) and parts of Section 11 (Limitations) break from the house style by bundling unrelated claims into single paragraphs, narrating test runs chronologically before stating the finding at the end of the paragraph, and inserting lab-notebook provenance notes mid-paragraph.

---

## 2. Structured Feedback by Severity

### Critical Issues

None. No fatal mathematical errors or irreparable methodological flaws invalidate the core contributions.

### Major Issues

1. **Overstated serial-equivalence conclusion in Theorem 6.4 for `Merge` outcomes (lines 442–465).**
   Theorem 6.4 quantifies over any sequence of accepted landings $v_1 < \dots < v_m$ on $r$ (line 444) and concludes unqualifiedly that "the history of $r$ is equivalent to the serial execution of $c_1,\dots,c_m$ in log order, in which each change reads its declared set from the state just before its own entry" (line 450). However, items 2 and 3 of the theorem specify the post-state $\tree(\Snap{v_i}(r))$ only when validation returns `FastForward` or `Rebase`, and the proof (line 462) appeals only to parts 2 and 3. As line 465 later concedes, `Merge` outcomes are covered only in the weaker sense of Proposition 6.5. If $c_i$ is modeled as writing whole-file blobs on $\W(c_i)$, a `Merge` landing does not produce $\tree(c_i)$ on $\W(c_i)\cap M$; it produces a line-level three-way merge. Either restrict Theorem 6.4's serial-equivalence statement to histories of `FastForward` and `Rebase` landings (treating `Merge` separately in Proposition 6.5 under a patch-composition assumption), or state the patch-level hypothesis explicitly inside Theorem 6.4.

2. **Mismatch between adapter deferral and authority verification in Proposition 7.4 (lines 559, 564, 603–612, 900–901).**
   Proposition 7.4 states that if the combiner accepts the $j$-th claimed item only when $\R_j \nmeets \W_i$ for every earlier accepted item $i$ "in addition to the existing checks," then the batch entry is equivalent to landing its accepted members one at a time in ticket order. Its proof (line 609) relies on "the existing deferral rule" to assert that merged changes of distinct members touch disjoint paths. There are two gaps here:
   - First, as Definition 7.1 (line 559) and Table A.1 (rows 22–23, lines 900–901) document, write disjointness is checked only by the untrusted Worker adapter (`landBatch`), not by the authority (`verify_octopus`). Line 612 recommends enforcing the new $\R_j \nmeets \W_i$ rule in the authority "because the authority is the component that must not trust its callers," yet without also enforcing $\W_j \nmeets \W_i$ in the authority, a faulty or malicious caller could still submit overlapping writes in a batch.
   - Second, the adapter checks disjointness of *merged paths against $H_0$* ($\Delta(\text{merge}(\fp(c_i), H_0, c_i))$ relative to $H_0$), whereas sequential validation (Definition 4.7, line 315) checks $\W(c_j) \nmeets \W_i$ using the recorded write sets. If a path $p \in \W(c_i) \cap \W(c_j)$ was already modified identically in $H_0$ so that $c_i$'s merge against $H_0$ is a no-op on $p$, the adapter does not defer $c_j$, whereas sequential landing of $c_i$ followed by $c_j$ would classify $c_j$ as `Merge` rather than `Rebase`. Proposition 7.4 should require $(\R_j \cup \W_j) \nmeets \W_i$ (or state explicitly that the existing write-disjointness check is taken over $\W_i$) and specify that the authority enforces both.

3. **Underspecified location tree $\Loc$ and directory agreement in Section 4.2 (lines 222–226, 244, 424–427, 433–440).**
   - In Definition 4.4 (line 225), $\Loc$ is defined as "a rooted tree whose internal nodes are directories, files and symbols." In a rooted tree, leaf symbols (and childless files or directories) are leaves, not internal nodes; "internal nodes" should be "nodes."
   - Line 244 defines agreement $\tree \equiv_X \tree'$ as assigning "the same content to every location in $\bigcup_{x\in X}\mathrm{sub}(x)$. For a file this is its blob; for a symbol it is the source text the parser attributes to that symbol." This leaves two questions unanswered: (a) Is $\Loc$ the universal tree of all syntactically valid paths and symbols (with absent locations in a given $\tree$ assigned content $\bot$), or is $\Loc$ indexed by a specific snapshot? For Lemma 6.3 (Frame, line 435) to detect newly added or deleted files under a directory prefix $x \in X$ (e.g., `src/`), $\Loc$ must be the universal tree over all possible paths and symbols, and absent nodes must map to $\bot$. (b) What is the "content" assigned by $\tree$ to a directory node $d \in \mathrm{sub}(x)$? Defining content on file and symbol nodes (with $\bot$ for absence) suffices if directory nodes have no independent content beyond their descendant files, or if a directory's content is its tree identifier.

4. **Non-self-contained reliance on unincluded companion papers for model assumptions (lines 141, 402, 496).**
   Theorem 5.6 (Snapshot immutability, line 393) qualifies object immutability with "if they are present," and lines 141 and 402 defer the safety of releasing hidden refs to "Part II (Proposition 12.1)" \cite{long2026partII}. Similarly, line 496 defers transitive symbol-reference expansion of read sets to "Part II (Section 10)." To make Part I formally self-contained, state the object-store retention invariant (e.g., that $O$ retains all objects reachable from any commit in the image of $\Snap{u}$ for all $u \leq n$, as guaranteed by Definition 4.1's monotonicity $O \subseteq O'$) directly in Section 5.3 rather than leaving object presence contingent on an external proposition.

5. **House-style violations in Section 9 and Section 11 (lines 666, 693–697, 701–707, 730).**
   Several paragraphs in the later sections violate the house style's core rules: one claim per paragraph, findings stated before qualification, and no narrative filler or signposting. See Section 3 below for exact quotes and a model rewrite.

### Minor Issues

1. **Edge case $x = \bot$ in Theorem 5.4 and its use in the proof of Theorem 6.4 (lines 371, 456).**
   Theorem 5.4 (line 371) assumes $\Snap{u}(r) = x \neq \bot$ and proves that if $\Snap{u}(r) = \Snap{v}(r)$, then no entry in $(u,v]$ names $r$. In the proof of Theorem 6.4 (line 456), Theorem 5.4 is invoked on $\Snap{b_i}(r) = \fp(c_i) = \Snap{v_i-1}(r)$ to conclude that $\Later(P_i)$ is empty. When $c_i$ is the very first commit landed on a new branch $r$, $\fp(c_i) = \bot$, so $\Snap{b_i}(r) = \Snap{v_i-1}(r) = \bot$, which falls outside the hypothesis $x \neq \bot$ of Theorem 5.4. The second sentence of Theorem 5.4 in fact holds for $x = \bot$ as well (since by Lemma 5.3 and the first sentence of Theorem 5.4, any entry naming $r$ sets it to a non-$\bot$ value that remains non-$\bot$ thereafter); dropping $x \neq \bot$ for the second claim of Theorem 5.4 closes this corner case.

2. **Object type dependency in Definition 4.1 (line 193).**
   Definition 4.1 writes $x = H(\mathit{hdr}(b)\,\|\,b)$ where $O: \mathit{Id} \rightharpoonup \mathit{Bytes}$ and "$\mathit{hdr}$ is Git's type-and-length header." Because Git's header (`<type> <size>\0`, line 141) depends on the object's type (`blob`, `tree`, `commit`) and not solely on the raw payload bytes $b$, either $O$ should map $\mathit{Id}$ to typed objects $\mathit{Type} \times \mathit{Bytes}$ or $b$ should be defined as the typed representation.

3. **Definition of directory size $|d|$ in Proposition 4.3 (lines 207–214).**
   Proposition 4.3 bounds rewrite work by $O\bigl(\sum_{d\in D(P)}|d|\bigr)$, "where $|d|$ is the number of entries in directory $d$." Because a change $P$ can add new entries to $d$ or create new directories in $D(P)$ that had zero entries in $\tree(\fp(c))$, clarify that $|d|$ denotes the total number of entries in $d$ across $\tree(\fp(c))$ and $\tree(c)$ (i.e., $|\tree(\fp(c))(d) \cup \tree(c)(d)|$).

4. **Scope of the `#` overlap fallback remark (line 228).**
   Line 228 notes that the code's fallback for filenames containing a literal `#` can only add overlaps, "which is the safe direction for every result below." Adding overlaps is conservative for soundness results (Lemma 6.3, Theorem 6.4, Proposition 6.10), where extra overlaps only cause additional conflicts or merges. However, Theorem 6.7 (lines 503–511) is a bidirectional equivalence ("The following are equivalent"); that equivalence holds because both `independent` and `Proposal::check` use the same overlap relation, not merely because one contains the other.

5. **Unspecified write set $\W$ of a batch merge entry in Definition 7.1 (line 559).**
   Line 559 specifies the read set (union of members' read sets) and base (smallest member base) of the entry appended by `Land batch`, but omits its write set $\W$ (whether it is $T(m)$ of the octopus merge commit or the union of the accepted members' touched paths). State this explicitly to match Definition 4.5.

6. **Degenerate case $b = v$ in Lemma 6.3 (line 435).**
   Changing $b < v$ to $b \leq v$ in Lemma 6.3 (Frame) makes the base case $b_i = v_i - 1$ immediate in Theorem 6.4 without needing a separate case analysis when $\Later(P_i)$ is empty.

7. **Empty math subscript in proof of Lemma 6.3 (line 439).**
   Line 439 writes `\Snap{}(r)`, which expands to `S_{}(r)` with an empty subscript. Replace with "do not change the value of $r$" or `$\Snap{u}(r) = \Snap{u-1}(r)$`.

8. **Hyphens instead of en-dashes in bibliography page ranges (lines 749, 755, 784, 790, 812, 818, 849).**
   All seven page ranges in the bibliography use a single hyphen (`3411-3424`, `pages 1-10`, `pages 1-8`, `492-528`, `pages 485-496`, `213-226`, `78-87`) instead of a LaTeX en-dash (`--`).

9. **Justified narrow columns in Appendix A `longtable` (line 867).**
   Line 16 defines `\newcolumntype{L}[1]{>{\raggedright\arraybackslash}p{#1}}` and uses it in Tables 1–3, but line 867 declares `\begin{longtable}{@{}p{0.7cm}p{3.1cm}p{3.8cm}p{1.5cm}p{4.9cm}@{}}`. Because columns 2, 3, and 5 are narrow and contain long inline `\code{...}` identifiers, full justification produces large inter-word gaps and overfull/underfull `\hbox` warnings; replace `p{...}` with `L{...}` in line 867.

10. **Unused LaTeX packages, libraries, environments, and duplicate labels (lines 17–20, 31, 33, 224, 310, 505).**
    - `\usepackage{listings}` and `\lstset{...}` (lines 17–18), `\usepackage{cleveref}` (line 20), `\newtheorem{remark}[theorem]{Remark}` (line 31), and the TikZ library `fit` (line 33) are never used.
    - Lines 224 (`\label{def:tlsc:overlap}`), 310 (`\label{def:tlsc:validation}`), and 505 (`\label{prop:tlsc:eq1-vs-occ}`, which also uses a `prop:` prefix on a `theorem` environment) are duplicate labels that are never referenced.

---

## 3. Weakest Three Paragraphs and Model Rewrite

### Weakest Paragraph 1 (lines 693–697)

> The local landing test is the direct check of Corollary~\ref{cor:tlsc:nolostupdate} under concurrency: 100 writers each committed one new file on the same branch and landed it, and all 100 landed. % M60
> The commit message that reports this run gives a landing p95 of about 450 ms and a commit p95 of about 680 ms; no raw output of the run survives, so these figures are approximate. % M61, M62
> The local commit-cost comparison reports a one-file commit p50 of about 13 ms on a 100-file repository and about 14 ms on a 10,000-file repository, as Proposition~\ref{prop:tlsc:rewrite} predicts; the design notes give 14 and 15 ms for the same comparison, and the discrepancy is unresolved. % M64
> On the hosted deployment, the one-file commit p50 was 1,725 ms at 100 files and 1,627 ms at 3,000 files in one run, and 1,302 ms and 1,085 ms in another; within each run, the larger repository was not slower. % M15, M16, M24, M25
> The hosted figures are dominated by network and object-store round trips, not by the tree rewrite, and they come from 20 edits per repository on one client.

**Critique:** This paragraph violates the one-claim-per-paragraph rule by merging two distinct empirical claims: (1) zero lost updates across 100 concurrent landings (testing Corollary 5.5) and (2) invariance of single-file commit cost to repository size (testing Proposition 4.3). It also interjects archival housekeeping notes ("no raw output of the run survives", "the design notes give 14 and 15 ms for the same comparison, and the discrepancy is unresolved") that disrupt argumentative flow.

### Weakest Paragraph 2 (lines 701–707)

> On the hosted deployment, two runs of 100 concurrent writers had all 100 commits accepted. % M10, M18
> Their landing latency, measured from each writer's land request after its own commit, had p50 and p95 of 5.3 s and 6.7 s in the first run and 3.5 s and 5.0 s in the second. % M11, M21
> A later instrumented run breaks the landing request into its waits. The direct compare-and-swap call had a p50 of 86 ms. % M-P2.24
> The claim calls summed to a p50 of 2.6 s per landing request over an average of 13.6 calls, and the ticket-status polls to a p50 of 2.6 s over 14.6 calls. % M-P2.26, M-P2.28
> The batch-landing call itself appeared in 0.03 of landing requests, roughly three batches per hundred landings, with a p50 of 579 ms. % M-P2.25
> These phase values are sums of waits that overlap, not service times, and the run had 7 of 100 commits fail on an object-store rate limit. % M31
> They still support one conclusion: under this burst, landing latency came from waiting on the lease and polling, not from the atomic append. A completion signal pushed to waiting requests, in place of polling, is the obvious next change.

**Critique:** This paragraph inverts the house style's requirement to state findings directly before evidence and qualification. It recounts three test runs chronologically over six sentences before announcing its governing claim in the penultimate sentence ("They still support one conclusion: under this burst, landing latency came from waiting on the lease and polling, not from the atomic append").

### Weakest Paragraph 3 (line 730)

> The design serializes all landings, and all commit preparation, through one authority per repository. This is a deliberate choice for simplicity, and it bounds throughput per repository. Time travel by timestamp, log compaction and retention, and splitting refs across several authorities are not built. The evidence on performance is thin: local figures without surviving raw output, and hosted runs from one client machine with run-to-run variation large enough that single runs should not be read as precise. Part III states the planned evaluation (Section 9).

**Critique:** Serving as a catch-all at the end of Section 11, this paragraph combines three unrelated claims: an architectural throughput ceiling (per-repository serialization), an inventory of unbuilt features (timestamp reads, compaction, per-ref authorities), and methodological caveats on the latency benchmarks, concluding with a signpost to Part III.

### Model Rewrite (of Weakest Paragraph 2, lines 701–707)

> Hosted landing latency under a 100-writer burst is dominated by lease contention and ticket polling rather than by the atomic log append. Across two 100-writer runs in which all 100 commits landed, end-to-end landing latency reached a p50 of 3.5--5.3 s and a p95 of 5.0--6.7 s. In an instrumented follow-up run, the direct compare-and-swap call took a p50 of 86 ms and the batch-landing call—triggered in roughly three of every hundred landings—took a p50 of 579 ms, whereas each request spent a cumulative p50 of 2.6 s across 13.6 claim attempts and 2.6 s across 14.6 status polls. Although those cumulative phase waits overlap and 7 of 100 commits in the instrumented run failed earlier on an object-store rate limit, the gap between an 86 ms append and multi-second polling shows that replacing client polling with a server-pushed completion signal is the primary lever for reducing landing latency.

---

VERDICT: MAJOR REVISIONS (major issues remain)
