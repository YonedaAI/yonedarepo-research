---
reviewer: Gemini 4 Argon (High)
paper: serverless-git-on-cloudflare
round: 1
date: 2026-10-20T15:53:16Z
---


### Summary Evaluation

This paper—Part III of *Source Control as a Data System*—evaluates a serverless implementation of a transaction-log source control system (YonedaRepo) on Cloudflare Workers, SQLite-backed Durable Objects, R2, Cache API, and Artifacts. Its candor in reporting a negative primary result (100-writer commit acceptance p95 of 2.8–3.7 s against a 1 s target) and its traceability from architectural claims to source files and commit hashes (Appendix A) are commendable strengths.

However, the paper requires major revisions before it is publishable:
1. **Mathematical Correctness and Modeling**: While the elementary queueing lemmas (Lemma 6.5, Propositions 6.6, 6.8, 6.9) are mostly sound, the calibration (Section 7) and capacity projections (Section 8, Appendix B) contain critical methodological flaws. Most notably, Equation (3) fits an "effective" per-call authority service time ($s_{\mathrm{eff}} = 2.43\text{ ms}$) by attributing the *entire* difference between burst and sequential commit p95—including ~275–500 ms of R2 write slowdown and isolate token minting—to the 7 authority calls of a commit, and Section 8 then multiplies this lumped parameter by 30.5 landing calls (28 of which are lightweight SQLite polls that never touch R2 or mint tokens). In addition, the calibration compares a 10-call sequential baseline ($L_0^{95}$) against a 7-call burst without adjusting for the 3 fewer network round trips, uses $N=100$ in $(N-1)c_{\mathrm{commit}}$ for runs where 7–9% of commits failed before completing their calls, treats the endogenous poll count ($c_{\mathrm{land}} = 30.5$) as fixed even when cycle times stretch from 6 s to 850 s above the knee, and mixes an unloaded 95th percentile with a steady-state mean queueing delay.
2. **Completeness and Empirical Rigor**: The two instrumented runs (H3 and H4) that underpin the phase decomposition (Table 3) and half of the calibration (Table 5) were executed from an unrecorded working-tree revision (line 208) and suffered 9% and 7% request failures (line 213)—one from an unrecorded input-validation error and one from an R2 single-key rate limit (error 10058) whose offending key the paper leaves unidentified despite having full access to the Worker code that constructs R2 keys. Furthermore, Parts I and II are cited by section, definition, and theorem number throughout the text but are omitted from the bibliography.
3. **Logical Structure**: Section 2 relies on an opaque catalog of external theorem and definition numbers from Parts I and II rather than stating a self-contained operational model. Section 8.6 ("Validation runs") and Section 9 ("Planned evaluation") duplicate the same unexecuted experiments, and Section 9 includes proposed evaluations of Part II and a companion paper that do not belong in an empirical evaluation of Part III.
4. **LaTeX Quality**: The manuscript loads five unused packages (`graphicx`, `xcolor`, `tikz`, `longtable`, `listings`), uses straight ASCII double quotes (`"..."`) on line 63, uses single hyphens instead of en-dashes (`--`) for page ranges in the bibliography (lines 678, 684, 800), and omits non-breaking spaces before units throughout.
5. **Prose and House Style**: Several sections—particularly Section 5.3—adhere well to the house style, leading with direct claims supported by numbers. Elsewhere, however, the prose falls into multi-claim grab-bag paragraphs (line 131), pure roadmap signposting (line 71), and a 118-word single-sentence definition with nested relative clauses and nominalizations (lines 142–145).

---

### Structured Feedback by Severity

#### Critical Issues

1. **Lumping non-authority delays (R2 slowdown and token minting) into $s_{\mathrm{eff}}$ and applying it to landing polls (Lines 473–480, 503–507, 535–565, 850–853)**
   - In Section 7, Equation (3) fits $s_{\mathrm{eff}} = (T_{95} - L_0^{95}) / ((N-1)c_{\mathrm{commit}}) = 2.43\text{ ms}$ across all commit phases. As lines 503–506 acknowledge, the authority's own phase waits between sequential and burst commits grow by only **1.0 to 1.2 ms per call** under Lemma 6.5; the remaining half of $T_{95} - L_0^{95}$ comes from R2 write degradation under load (median rising by ~265–282 ms in Table 3, line 255) and per-isolate write-token minting (p95 of 512–575 ms, line 275).
   - In Section 8 (Table 6, line 543) and Appendix B (lines 852–853), the model multiplies this lumped $s_{\mathrm{eff}} = 2.433\text{ ms}$ by $c_{\mathrm{commit}} + c_{\mathrm{land}} = 7 + 30.47 = 37.47$ calls per landing cycle to obtain $D_{\mathrm{auth}} = 91.2\text{ ms}$ and a ceiling of $11.0\text{ lands/s}$ for C1 (and $30.47 \times 2.433\text{ ms} = 74.1\text{ ms}$, or $13.5\text{ lands/s}$, for C2).
   - This is mathematically invalid: 28 of the 30.47 landing calls are lightweight SQLite lease/status polls (`claim` and `status`) that never write to R2 or mint Artifacts tokens. Charging every poll for R2 and token-minting overhead understates the authority ceiling in C1 and C2 by roughly a factor of two (at the authority's true phase-derived cost of 1.0–1.2 ms per call, $D_{\mathrm{auth}}$ is 37–45 ms, yielding 22–27 lands/s and making the land combiner at 24.6 lands/s nearly co-bottlenecked even in C1). Conversely, in the 1,000-writer burst extrapolation (line 587), R2 per-object latency and per-isolate token minting do not queue behind a single server $693$ or $6{,}993$ times. You should use the authority-only phase growth ($s_{\mathrm{auth}} \approx 1.0\text{--}1.2\text{ ms}$) for authority queueing and model the R2/push-queue path as a separate stage.

2. **Mismatch in authority call count ($c_{\mathrm{commit}} = 10$ vs. $7$) between $L_0^{95}$ and burst commits in Equation (3) (Lines 147, 250–254, 449–451, 475, 850)**
   - Line 147 and Table 3 (lines 250–254) state that a sequential (unloaded) commit makes **10** authority calls (1 snapshot, 4 prepare, 3 status, 1 record, 1 review-class), taking ~558 ms of authority round trips in H4 sequential ($45 + 215 + 146 + 77 + 75\text{ ms}$). By contrast, a burst commit makes only **7** authority calls (1 snapshot, 2 prepare, 2 status, 1 record, 1 review-class).
   - First, the paper never explains *why* sequential commits make 4 prepare and 3 status calls while burst commits make 2 prepare and 2 status calls (presumably due to different directory depths or auth caching between the sequential and burst benchmark steps).
   - Second, Equation (3) ($\widehat{T}_{95}(N) = L_0^{95} + (N-1)c_{\mathrm{commit}}s$, line 475) uses the 10-call sequential commit p95 as $L_0^{95}$ for a 7-call burst workload. Because each unloaded authority round trip costs ~50 ms of network latency (line 269, 632), the 10-call sequential baseline $L_0^{95}$ includes ~150 ms of unloaded network round-trip time for 3 calls that the burst commits never make. This biases the baseline $L_0^{95}$ upward by ~150 ms and distorts the fitted $s_{\mathrm{eff}}$ in Table 5.

3. **Unaccounted overlap between early landings and tail commits in the burst benchmark (Lines 206, 226–229, 375–382, 472–476)**
   - Section 5.1 (line 206) states that the benchmark "starts 100 writers at once, each of which commits one new file on `main` and then lands it."
   - Because each writer starts landing immediately after its commit completes, writers whose commits finish near the median (2.5–3.3 s in Table 2) begin making landing calls (`enqueue`, `direct land`, and repeated `claim`/`status` polls) to the single-threaded authority *while* the slowest 5% of commits (finishing at 2.8–3.7 s, and up to 5.5 s at max) are still waiting on the authority for their `record` and `review_classes` calls.
   - Yet Section 7 (lines 472–476) applies Lemma 6.5 to the commit phase in isolation, assuming the tail commits compete only against the $(N-1)c_{\mathrm{commit}} = 693$ commit visits of the other writers and zero landing visits from early finishers.

4. **Using $N = 100$ in $(N-1)c_{\mathrm{commit}} = 693$ for runs H3 and H4 where 9 and 7 commits failed (Lines 213, 228–229, 484–496, 850)**
   - In H3, 9 of 100 commits failed with an input-validation error (line 213), so those requests rejected early and did not execute the 7 authority calls of the commit path. With 91 active writers, $(N-1)c_{\mathrm{commit}} = 90 \times 7 = 630$, not $693$—a 10% error in the denominator of $s_{\mathrm{eff}}$ for H3 ($1{,}972 / 630 = 3.13\text{ ms}$ rather than $2.845\text{ ms}$ on line 850).
   - Similarly, in H4, 7 commits failed during the R2 write step (line 188, 213) before reaching the post-push `record` and `review_classes` authority calls.
   - More broadly, relying on two runs from an unrecorded working tree (line 208) with 7–9% failure rates and unrecorded error messages (line 213) for the paper's sole phase-level data (Table 3) and half of its calibration data (Table 5) is an empirical weakness that should be resolved by re-running the instrumented benchmark cleanly on a committed revision.

5. **Endogenous polling count $c_{\mathrm{land}} = 30.5$ treated as fixed above the knee, and mixing p95 with mean latency in Table 6 (Lines 535, 542–556, 561–563, 852, 860–861)**
   - In H4, a landing made 13.62 lease claims and 14.61 status reads (28.23 polls) because it waited ~5.5 s for the land combiner at a poll interval of up to 250 ms (lines 287, 828, 852).
   - When the model extrapolates C1 and C2 to $N = 1{,}000$ and $N = 10{,}000$ (Table 6 and Appendix B, line 861), it holds $c_{\mathrm{land}} = 30.47$ constant even as the cycle time $R(N)$ rises to **31.2 s** ($N=1{,}000$) and **851.7 s** ($N=10{,}000$). In a closed queueing network where polling is time-driven until the combiner completes a batch, the number of polls per landing is a function of the combiner wait time divided by the poll round-trip time, not a structural constant of 28.23 visits per cycle.
   - In addition, Appendix B (lines 860–861) computes above-the-knee commit latency at $N=1{,}000$ and $N=10{,}000$ as $1.70 + 7 \times (R - R_0)/37.47$, where $1.70\text{ s}$ is the unloaded **p95** commit latency, $R_0 = 1.85\text{ s}$ is the unloaded **median (p50)** cycle time (line 857), and $R = N/X_{\max} - Z$ is the **mean** cycle time by Little's law. Table 6 caption (line 535), line 561 ("projected mean commit time"), and line 569 ("commit p95") conflate means, medians, and 95th percentiles.

---

#### Major Issues

1. **Mathematical impossibility between Table 3 (line 255) and Section 7 (line 503) for H4 burst R2 write median**
   - Table 3 (line 255) reports that the overall `Cache write (R2 and edge)` phase (`M-P2.01`), which awaits both the R2 write and the edge cache write, has a median of **1,157 ms** in the H4 burst.
   - Line 503 states that the R2 write sub-phase (`M-P2.03`) inside that cache write had a median of **1,167 ms** in the H4 burst ("its median rises from 892 to 1,167 ms in H4").
   - Because order statistics are monotonically non-decreasing, if every request's total cache-write wait $A_i$ is at least its R2-write wait $B_i$ ($A_i \ge B_i$), then $\mathrm{median}(A) \ge \mathrm{median}(B)$ is an identity over any fixed sample. Having $\mathrm{median}(\text{cache write}) = 1{,}157\text{ ms} < \mathrm{median}(\text{R2 write}) = 1{,}167\text{ ms}$ is mathematically impossible unless `1,167` is a transcription typo for `1,157` or the two medians were computed over different subsets of the 100 requests (e.g., including vs. excluding the 7 R2-failed requests).

2. **Missing self-containedness hypothesis in Proposition 4.2 (Lines 172–179)**
   - Proposition 4.2 claims that if a combined receive-pack of $p_1, \dots, p_m$ with distinct refs is unpacked successfully, the status reported for $r_i$ equals the status $p_i$ would receive if sent alone.
   - The proof (line 178) states: "The combined pack contains every object of every $p_i$, deduplicated by identifier... and every object that $p_i$ needs is present." This holds only if each individual pack $p_i$ is already self-contained (closed under object reachability relative to the repository). If $p_1$ alone is missing a required object $x$ (so $p_1$ alone would fail Git's connectivity check) and $p_2$ happens to include $x$, then $r_1$ will succeed in the combined push but fail alone. Add the hypothesis that each $p_i$'s pack contains all objects reachable from its new target that are not already in the repository.

3. **Unused variable $D = \sum_j D_j$ and ambiguous batch demand $D_j = T(k)/k$ in Definition 6.1 and Proposition 6.6 (Lines 349–352, 386–399)**
   - Proposition 6.6 (line 388) defines $D = \sum_j D_j$ in its preamble but never uses $D$ in Equation (1) or in the proof, because standard operational analysis's $D$ was replaced by $R_0$. Remove $D = \sum_j D_j$ from Proposition 6.6 or explain that $R_0 \ge D$ includes non-serialized waits.
   - Definition 6.1 (line 351) defines the demand of a batch point as $D_j = T(k)/k$ without specifying how $k$ is determined at load $N$. Because batch size $k \le k_{\max}$ increases with arrival rate up to the cap $k_{\max} = 64$, the asymptotic bottleneck bound in Proposition 6.6 requires defining $D_j$ at saturation as $D_j = \min_{1 \le k \le k_{\max}} T(k)/k = T(k_{\max})/k_{\max}$.

4. **Internal contradiction on authority calls during symbol derivation (Lines 144, 147, 250–254)**
   - Definition 3.2 (line 144) states that the commit path runs "in parallel, classification of review classes and derivation of symbol writes, each of which ends in a call to the authority."
   - Line 147 and Table 3 (lines 250–254) count only one authority call during `derive` (`Authority review classes (1 call, inside derive)`), with no authority call for symbol writes. Moreover, if a single commit job did issue two authority calls in parallel, it could hold one visit in service while its second visit waits in the queue, violating the step in the proof of Lemma 6.5 (line 381: "since the waiting job's own visits are not in service"). Correct line 144 to match the actual implementation.

5. **Uninvestigated R2 key collision (error 10058) despite full source-code access (Lines 188–190, 583, 609–610)**
   - Seven commits in H4 failed with R2 error 10058 ("Reduce your concurrent request rate for the same object", line 188). The paper states "Some key is therefore written by many commits. The ledger of this run does not identify it" (line 189) and proposes a future logging experiment in Section 9 (line 609) to identify the key.
   - Inspecting `cloudflare/worker/repo-objects.ts` and `cloudflare/worker/repo-ops.ts` (already cited in Appendix A, lines 821–824) can immediately reveal what R2 key pattern is written on every commit (for example, an identical empty tree/blob hash, a shared repository prefix, or a seed/metadata object). Identifying the key from the source code rather than deferring it to future work will strengthen Sections 4.3 and 8.5.

6. **Missing bibliographic entries for Parts I and II and excessive external pointer soup in Section 2 (Lines 76–82, 607, 656, 666–803)**
   - Parts I and II of *Source Control as a Data System* are never listed in `\begin{thebibliography}` (lines 666–803), even though Section 2 (lines 76–80), Section 5.5 (line 325), Section 9 (line 607), and Section 11 (line 656) cite specific numbered sections, definitions, propositions, theorems, and invariants from them.
   - Add full bibliography entries for Parts I and II, and rewrite Section 2 so that the three invariants (I4, I6, I13) and the operational steps of a commit and batched landing are stated directly without listing a dozen external definition numbers in a single paragraph.

7. **Redundancy between Section 8.6 and Section 9, and out-of-scope planned experiments (Lines 585–611)**
   - Section 8.6 ("Validation runs", lines 585–587) and Section 9 ("Planned evaluation", lines 589–611) describe the same unexecuted validation sweeps (the 100–1,000 writer burst sweep, the C1 open-loop rate sweep, the land combiner batch sweep $T_c(k)$, and the push-size sweep $T_{\mathrm{push}}(m)$).
   - Furthermore, Section 9 includes two paragraphs—`Real-model arms` (line 599) and `Derived data` (line 607)—that propose future experiments to test predictions of the companion paper (`\cite{long2026inversion}`) and Part II rather than Part III. Consolidate the capacity validation runs into a single concise subsection and remove unexecuted test plans for other papers.

---

#### Minor Issues

1. **Inconsistent lease-holder call accounting in C3 (Lines 524, 542, 852–853)**
   - Line 524 and line 853 state that in C3 a landing makes $3 + 1/k = 3.02$ authority calls (`enqueue`, `direct land`, `completion notice`, plus $1/64$ of a batch landing). Yet line 852 shows that in H4 the lease holder also made calls to `claim`, `prepare`, `record`, `classify`, and `read status` when building the octopus merge commit. Clarify why those lease-holder calls are omitted from the $1/k$ term in C3, or why a caller still makes a `direct land` call when a batch already owns the branch.

2. **Straight ASCII quotation marks in LaTeX (Line 63)**
   - Line 63 uses `"authority"`, `"push queue"`, and `"land combiner"`, which render as closing double quotes on both sides under `T1` font encoding. Replace with `` ``authority'' ``, `` ``push queue'' ``, and `` ``land combiner'' ``.

3. **Hyphens instead of en-dashes in bibliography page ranges (Lines 678, 684, 800)**
   - Replace single hyphens with en-dashes (`--`) in `3411-3424` (line 678), `213-226` (line 684), and `78-87` (line 800).

4. **Unused LaTeX packages in preamble (Lines 12–15, 18–19)**
   - Remove `\usepackage{graphicx}`, `\usepackage{xcolor}`, `\usepackage{tikz}`, `\usepackage{longtable}`, `\usepackage{listings}`, and `\lstset{...}`, none of which are used in the document.

5. **Unprotected spaces before units and unbreakable `\texttt` strings (Passim; Line 161)**
   - Use non-breaking spaces (`~` or `\,`) between numbers and units (`1~s`, `892~ms`, `24~MiB`, `10~GB`) to prevent line breaks before units.
   - On line 161, change `\texttt{ERR artifacts\_git\_receive\_pack\_busy}` to `\nolinkurl{ERR artifacts_git_receive_pack_busy}` (or split the string) to avoid an overfull `\hbox`.

6. **Prose house-style violations outside the three weakest paragraphs (Lines 63, 279–281, 328–329, 331–332)**
   - **Line 279–281**: This paragraph describes an uncommitted experimental variant across three sentences before disqualifying it in the final sentence ("It is not evaluated here and is not the system's performance; it shows only that the cost lies where Table 3 puts it"). State the finding and qualification upfront in one sentence or move the paragraph to Threats to Validity (where it is already repeated on lines 643–644!).
   - **Lines 328–329**: Discusses a commit-message number (1.06 s) for two sentences before concluding "so we treat 1.06 s as unconfirmed." State directly at the start of the paragraph that the 1.06 s commit-message figure is not reproduced by the raw H2 benchmark output (1,085 ms and 1,302 ms).

---

### Weakest Three Paragraphs and Model Rewrite

#### Weakest Paragraph 1 (Line 76)

> This Part imports its system model from Parts I and II and redefines nothing that they own. Part I (its Section 3) divides a repository into four components: immutable objects, workspace changesets (commits that no protected ref points at yet), protected refs, and stateless compute. Its Section 4 defines the transaction log $L = (e_1, \dots, e_n)$ of one repository (Definitions 4.8 to 4.10), the snapshot $S_v$, the ref map after version $v$ (Definition 4.11), checkpoints (Definition 4.12), read and write sets (Definition 4.6), the proposal $P = (r, b, o, W, R)$ to land on ref $r$ from base version $b$ together with backward validation and its outcomes fast-forward, rebase, merge and conflict (Definition 4.15), and the atomic append that moves a ref and writes its log entry in one transaction (Definition 4.16). Its Section 7 defines the land combiner (Definition 7.1), which lands a batch $B = (t_1, \dots, t_k)$ of $k \le 64$ changes under a lease with an epoch, and proves that it preserves the single-writer discipline of the append (Theorem 7.2). Part I also shows that members of one batch can exhibit write skew with each other (Theorem 7.3), so the batch size of the combiner has a semantic cost as well as the latency cost studied here.

- **Why it fails the house style**: It opens with meta-signposting ("This Part imports its system model... and redefines nothing that they own"), has no single governing claim, packs an 84-word enumeration of six formal definitions with ten parenthetical pointers to an uncited manuscript into its third sentence, and tacks a separate substantive claim about write skew onto the final sentence.

#### Weakest Paragraph 2 (Lines 142–145)

> \begin{definition}[Commit path and land path]
> \label{def:sgoc:path}
> The commit path of a one-file commit in the measured code is the sequence of waits in \texttt{commit()}: a snapshot of the target ref from the authority; one or more prepare calls in which the authority asks for exactly the trees on changed paths and the Worker supplies them; a write of the new objects to R2 and the edge cache, started alongside the push; a push of a single-ref receive-pack through the push queue; a readback of the commit from Artifacts, which waits for the cache write to finish; a record call to the authority; dispatch of check runs; and, in parallel, classification of review classes and derivation of symbol writes, each of which ends in a call to the authority. Authorization adds calls that read the repository's status. The land path is an enqueue to the authority, a direct land attempt, and, when a batch owns the branch, waits on the land combiner's lease (claims) and on the landing's status.
> \end{definition}

- **Why it fails the house style**: The first sentence is a 118-word, eight-item semicolon list burdened with nominalizations ("classification of review classes and derivation of symbol writes", "a readback of the commit") and nested subordinate clauses ("in which the authority asks...", "which waits for...", "each of which ends in..."). It also wedges an omitted step ("Authorization adds calls...") between two distinct definitions and contradicts line 147 and Table 3 on the number of authority calls in the derivation step.

#### Weakest Paragraph 3 (Line 131)

> Work that need not finish before a response goes to a queue: deriving search segments and symbols after a landing (Part II), projecting branch refs to Artifacts, and dispatching check runs. The queue consumer takes one message at a time with three retries and a dead-letter queue. Importing an external Git repository runs as a Workflow, which makes a long import resumable. Checks run in Containers on the exact commit under test, with at most eight instances of the standard-1 type; a run on a commit near a branch head starts from a warm-start seed in R2 and fetches only the blobs that differ. A change-log stream to Basin, Cloudflare's Iceberg-based analytics service, exists on an unmerged branch and is designed to stay off the commit and landing paths \cite{cfbasin}.

- **Why it fails the house style**: It violates the one-claim-per-paragraph rule by stringing together four unrelated components—Queues, Workflows, Containers with R2 warm-start seeds, and an unmerged Basin analytics stream—while repeating configuration parameters already tabulated in Table 1.

---

#### Model Rewrite (of Weakest Paragraph 2, Lines 142–145)

```latex
\begin{definition}[Commit path and land path]
\label{def:sgoc:path}
A commit request executes five sequential stages in \texttt{commit()} after reading repository status for authorization:
(1) it reads a snapshot of the target ref from the authority and supplies the existing trees along changed paths in one or more prepare calls;
(2) it starts writing the new objects to R2 and the edge cache while pushing a single-ref receive-pack through the push queue;
(3) once both the push and the cache write finish, it reads the commit back from Artifacts;
(4) it records the commit at the authority and dispatches check runs; and
(5) it derives symbol writes and classifies review classes in parallel, recording the review classes at the authority.
A land request enqueues the change at the authority, attempts a direct compare-and-swap, and, if an active batch already holds the branch lease, waits by polling the lease and landing status until the batch completes.
\end{definition}
```

---

VERDICT: MAJOR REVISIONS (major issues remain)
