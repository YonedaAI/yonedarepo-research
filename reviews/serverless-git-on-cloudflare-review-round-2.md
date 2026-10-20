---
reviewer: Gemini 4 Argon (High)
paper: serverless-git-on-cloudflare
round: 2
date: 2026-10-20T16:56:26Z
---


### Summary Assessment

This paper evaluates the serverless implementation of a transaction-log source control system (YonedaRepo) on Cloudflare's edge stack (Workers, SQLite-backed Durable Objects, R2, Cache API, and Artifacts) and extrapolates its capacity to large agent fleets using a closed queueing model. Its empirical honesty is exemplary: negative results (missing the 1 s p95 commit target across all committed-code runs, losing commits to an undocumented `receive-pack` concurrency limit and an unidentified R2 key contention error, and relying on commit-message records where raw outputs were not preserved) are stated upfront without evasion.

However, several mathematical and methodological inconsistencies in the capacity model, calibration cross-checks, and path definitions require resolution before publication, alongside targeted prose revisions to meet the house style.

---

### High-Level Evaluation by Criterion

* **Mathematical Correctness:** The proofs of Lemma 6.6, Propositions 4.2, 6.7, 6.8, and 6.9, and Corollaries 6.7 and 6.10 are valid as stated. However, the parameterization and numerical solution of the capacity model have four substantive flaws:
  1. Both the prose (line 506) and Table 5 (line 486) state the inverted ratio for the poll iteration time $\tau$ (dividing poll count by landing time, which yields a rate in $\text{s}^{-1}$, rather than landing time by poll count), and the resulting value ($\tau = 0.42\text{ s}$) violates Definition 6.2 (line 368) because it includes $\sim 250\text{ ms}$ of burst queueing delay at the authority per poll pair.
  2. Section 6.2 (line 443) claims that the open-system $M/D/1$ waiting formula (Eq. 2) is used *only* to show that queueing below saturation is negligible, yet Section 8.2 (line 567) and Appendix B (line 921) use Eq. 2 inside the fixed-point solver to compute the collapsed saturation state at $N = 2{,}000$ and $N = 10{,}000$, while leaving the fixed-point map undefined when $U \ge 1$.
  3. The hosted cross-check of the authority service time $s$ (lines 505, 911) subtracts the 10-call sequential authority p95 sum from the 7-call burst authority p95 sum without applying the depth/call-count correction $\delta$ used in Eq. 3 (lines 517, 907).
  4. The validation extrapolation of Eq. 3 to a 1,000-writer burst (lines 627, 634) holds the push-step growth $\Delta_T = 524\text{ ms}$ constant, ignoring that 1,000 commits require $\lceil 1000/64 \rceil = 16$ sequential batches at the push queue ($\sim 7.0\text{ s}$ of serial send time).
* **Clarity and Completeness:** The system architecture and measurement tables are mostly clear, but Definition 3.2 (lines 148–155) contradicts both the code evidence (Table 7, line 882) and the call-count ledger (line 913) on the order of operations in the land path and the number of status calls on the commit path. Table 4 (lines 253–275) also omits the "tree reads" phase used in the critical-path sum on line 251.
* **Logical Structure:** The progression from system model (\S 2) to platform mapping (\S 3), limits (\S 4), measurements (\S 5), capacity model (\S 6), calibration (\S 7), projections (\S 8), planned evaluation (\S 9), Scion comparison (\S 10), and threats to validity (\S 11) is logical and well-proportioned. Section 1's final roadmap paragraph (line 71) duplicates the end of line 61, and Section 6's opening paragraph (line 355) is pure signposting.
* **LaTeX Quality:** Generally clean, with proper use of `booktabs`, `cleveref`, and `tabularx`. Minor defects include single hyphens instead of en-dashes in page ranges and compound names, narrow `p{...}` columns without hyphenation support (`\hspace{0pt}` or `ragged2e`), and an undefined reference to "Ledger rows" in Table 5's caption (line 477).
* **Prose Quality (House Style):** Most of the manuscript adheres well to the house style: claims are stated directly at the start of paragraphs, negative findings precede qualifications, and technical vocabulary is used soberly. Where the prose lapses, it does so by bundling residual observations into multi-claim paragraphs (lines 341–342, 504–507), inserting structural signposting (lines 71, 355, 504), or personifying mathematical quantities ("The poll iteration time divides...", line 506).

---

### Weakest Three Paragraphs and Model Rewrite

#### 1. Paragraph 1 (Lines 504–507)
> Four inputs need comment. The service time $s$ comes from a local benchmark of an earlier authority class in which the Worker and the Durable Object ran in one process, so 1.51~ms per command includes some Worker work and is more likely high than low. % M71
> The hosted cross-check divides the growth of the authority's p95 waits between sequential and burst commits by $(N_{\mathrm{ok}} - 1)c$, which equals $s$ only if the tail commit waits for the full bound of \cref{lem:sgoc:burst}; it gives 1.14~ms for H3 and 1.30~ms for H4, in agreement with the local value. % M30, M31
> The poll iteration time divides the mean number of claim and status calls per landing, 14.1 to 16.5 pairs, by the median landing time of 6.3 to 6.6~s. % M-P1.22, M-P1.24, M-P2.26, M-P2.28, M32
> The combiner cycle is the sum of the median phases of the landing request that held the lease, and each of those medians is over only three or four such requests per run; the upper end of its range allows for the lease claim and for merge computation in the Worker, which was not timed. The lease holder's calls per cycle (about three prepares, two status reads, a record, a review-class record, a claim and the batch landing) give $n_c = 9$. % M-P2.29, M-P2.31, M-P2.32, M-P2.25, M-P2.30

* **Why it fails the house style:** It opens with pure signposting ("Four inputs need comment") instead of an identifiable claim, bundles four distinct parameter derivations ($s$, the cross-check of $s$, $\tau$, and $T_c, n_c$) into one catalog paragraph, uses nested non-restrictive clauses, and personifies quantities ("The hosted cross-check divides...", "The poll iteration time divides..."), which directly masks the inverted fraction on line 506.

#### 2. Paragraph 2 (Lines 341–342)
> A full \texttt{git clone} of a small projected repository took 2.0~s, while the first API read of one file took 278~ms at the median. % M27, M28
> This is the comparison Scion's design argues from \cite{anthropic2026scion}, but one 3,000-file repository and one client support no general claim. The Container measurement is a single cold run and a single seeded run; the seeded run's time is dominated by not starting a new container, and the commit message attributes most of the cold time to container start. % M35

* **Why it fails the house style:** It combines two unrelated claims—API blob reads versus `git clone`, and cold versus warm Container check runs—into a single leftover paragraph. The second half delays its quantitative finding (already split across Table 5) behind methodological qualification and uses awkward phrasing ("argues from"; "the seeded run's time is dominated by not starting a new container"—an elapsed duration cannot be dominated by a non-event).

#### 3. Paragraph 3 (Line 71)
> The paper makes four contributions. It gives a mapping of the four components of Part I onto Cloudflare products together with the documented and observed limits that bind each (\cref{sec:sgoc:mapping,sec:sgoc:limits}). It reports the hosted and local measurements with their failures, including a phase-level account of where commit time goes (\cref{sec:sgoc:measured}). It states a capacity model with proofs of the bounds it uses and a calibration against the measurements (\cref{sec:sgoc:capacity,sec:sgoc:calibration}). Finally, it projects capacity for three configurations and four fleet sizes, with sensitivity ranges and validation runs (\cref{sec:sgoc:projected}), and states the planned evaluation that the other Parts cite (\cref{sec:sgoc:planned}).

* **Why it fails the house style:** It is pure meta-discourse and structural signposting that repeats the section outline already given at the end of line 61 and relies on weak nominalizations ("gives a mapping of", "states a capacity model"). It also announces "four contributions" while listing five distinct items across seven sections.

#### Model Rewrite (of Lines 504–507, split into two focused paragraphs with one claim each and corrected math)
> Independent local and hosted estimates place the authority's per-call service time $s$ between 1.1 and 1.6~ms. The baseline value of 1.51~ms comes from the inverse of 662 commands per second in a single local `workerd` process; because that process ran both the Worker and the Durable Object, the figure includes Worker overhead and is an upper bound on object service time. On the hosted platform, the authority p95 wait after adjusting for the three extra calls of the sequential workload grows by 874 to 992~ms across the burst's $(N_{\mathrm{ok}}-1)c$ interfering calls, giving 1.39~ms in H3 and 1.54~ms in H4 when the tail commit experiences the full bound of \cref{lem:sgoc:burst}.
>
> The landing parameters $\tau$, $T_c$, and $n_c$ are derived from the burst's per-request call counts and lease-holder phases, which makes them less precise than the commit timings. Dividing the median landing duration of 6.3 to 6.6~s by the mean of 14.1 to 16.5 poll pairs per landing yields an apparent poll cycle of 0.40 to 0.45~s, though this figure includes burst queueing at the authority. The combiner cycle $T_c = 2.6$~s (range 2.4 to 2.8~s) sums the median phases of the three to four lease-holding requests per run, with the upper bound allowing for untimed merge computation in the Worker across the lease holder's $n_c = 9$ authority calls (three prepares, two status reads, one record, one review-class record, one lease claim, and the batch landing).

---

### Structured Feedback by Severity

#### Critical Issues
None. No flaw invalidates the core empirical contribution or requires rejecting the paper outright.

#### Major Issues

1. **Inverted definition and queueing contamination of the poll iteration time $\tau$ (Lines 297, 368, 486, 506, 919, 921):**
   * *Inverted ratio in text and table:* Line 506 states that $\tau$ "divides the mean number of claim and status calls per landing, 14.1 to 16.5 pairs, by the median landing time of 6.3 to 6.6~s," and Table 5 (line 486) lists the source as "Polls per landing over landing median, H3 and H4." Dividing $14.1\text{--}16.5\text{ pairs}$ by $6.3\text{--}6.6\text{ s}$ gives $2.1\text{--}2.6\text{ polls/s}$, the reciprocal of $\tau$. The value $0.42\text{ s}$ ($0.40\text{--}0.45\text{ s}$) is the median landing time divided by the mean number of poll pairs.
   * *Violation of Definition 6.2:* Definition 6.2 (line 368) defines $\tau$ as the poll iteration time *excluding* the time the poller's own calls wait at the authority, and line 921 writes the denominator of the poll rate as $\tau + 2W$. However, $6.3\text{--}6.6\text{ s}$ divided by $14.1\text{--}16.5$ pairs *includes* the authority wait during the 100-writer burst: line 297 reports that $13.6\text{--}16.0$ lease claims and $14.6\text{--}17.0$ status reads summed to $5.1\text{--}5.5\text{ s}$ of authority wait ($\sim 350\text{ ms}$ per pair), whereas two unloaded authority round trips (~45–49 ms each, Table 4) plus a 5–25 ms sleep (line 364) take only $\sim 0.11\text{--}0.12\text{ s}$. Using $\tau = 0.42\text{ s}$ in Corollary 6.10 (line 919) and the fixed-point solver (line 921) double-counts burst queueing and inflates the poll-saturation threshold $Q^* = (\tau + 2s)/(2s)$ from $\sim 40$ waiting landings to $\sim 140$. Furthermore, clarify the discrepancy between line 364/882 ("sleeps for 5 to 25~ms") and line 883 ("`claim` answers a held lease with a retry of at most 250~ms").

2. **Contradictory and ill-posed application of the open-queue $M/D/1$ formula in the saturated regime (Lines 430–443, 567, 921):**
   * Line 443 explicitly asserts: "The model applies \cref{eq:sgoc:md1} only to show that queueing below saturation is negligible next to the unloaded path, because $s$ is a millisecond or two while $R_0$ is seconds."
   * Contradicting line 443, Section 8.2 (line 567) and Appendix B (line 921) use Eq. 2 ($W = Us/(2(1-U))$) at every $N$, including the collapsed saturation regime ($N = 2{,}000$, where $W \approx 2.6\text{ s}$ and $U \approx 0.9997$; and $N = 10{,}000$, where $W \approx 14.9\text{ s}$ and $U \approx 0.99995$). In that regime, arrivals are dominated by closed-loop pollers rather than an open Poisson process, and the solver relies on the open-queue singularity $(1-U)^{-1}$ at $U \to 1^-$ to force $2Q/(\tau + 2W) \approx 1/s - X c_{\mathrm{open}}$.
   * In addition, line 921 defines the fixed-point iteration step as "$W = Us/(2(1-U))$ by \cref{eq:sgoc:md1} when $U < 1$." Forward iteration from any small initial $W$ at $N \ge 2{,}000$ immediately yields $U > 1$, where the map is undefined. State the exact root-finding equation solved for $W \ge 0$ (namely $U(W) = 2W / (2W + s)$) and revise line 443 so it does not misrepresent how Eq. 2 is used.

3. **Omitted call-count correction in the hosted cross-check of $s$ (Lines 157–158, 488, 505, 907, 911):**
   * Sequential commits make 10 authority calls (4 prepare, 3 status, 1 snapshot, 1 record, 1 review-classes), whereas burst commits make 7 (2 prepare, 2 status, 1 snapshot, 1 record, 1 review-classes).
   * In Eq. 3 (line 517) and line 907, the calibration subtracts $\delta = 161\text{ ms}$ (155 ms of which is the two extra prepare calls and one extra status call) from the sequential commit latency to compare 7-call paths.
   * Two paragraphs later (line 911, and lines 488, 505), the hosted cross-check of $s$ subtracts the unadjusted 10-call sequential authority p95 sum (601 ms in H3, 770 ms in H4) from the 7-call burst authority p95 sum (1,320 ms in H3, 1,607 ms in H4). Failing to deduct the three extra sequential authority calls ($\sim 155\text{--}230\text{ ms}$) biases the estimated burst wait growth downward and yields $s = 1.14\text{--}1.30\text{ ms}$ instead of $\sim 1.39\text{--}1.58\text{ ms}$.

4. **Unmodeled push-queue batching delay when extrapolating Eq. 3 to $N = 1{,}000$ (Lines 517, 627, 634):**
   * In Eq. 3, $\Delta_T = 524\text{ ms}$ is the empirical growth of the push step's p95 in a 100-writer burst, where 100 commits fit into two batches of $m_{\max} = 64$ and wait behind at most one in-flight combined push ($\sim 440\text{ ms}$, lines 286–287).
   * Lines 627 and 634 apply Eq. 3 with a constant $\Delta_T = 524\text{ ms}$ to predict $\widehat{T}_{95} = 12.6\text{ s}$ for a 1,000-writer burst. However, 1,000 concurrent commits require $\lceil 1000 / 64 \rceil = 16$ sequential batches at the push queue ($\sim 16 \times 0.44\text{ s} = 7.0\text{ s}$ of total serial service time at the push queue, comparable to the $10.6\text{ s}$ of total service time at the authority). Because commits exit the authority's `prepare` stage at up to $\sim 132\text{ commits/s}$ (5 early-stage authority calls $\times 1.51\text{ ms} = 7.55\text{ ms}$ per commit) while the push queue drains at $145\text{ commits/s}$, variations in batch fill below 64 or token minting can cause multi-batch queueing at the push queue that a constant $\Delta_T$ ignores.

5. **Contradictions between Definition 3.2 and the implementation/data (Lines 148–158, 264, 882, 913):**
   * *Land path order (line 154 vs. lines 882, 913):* Definition 3.2 (line 154) states that a land request "enqueues the change at the authority and attempts a direct compare-and-swap." Table 7 (line 882) states the opposite order ("`landWithMerge` tries a direct land, enqueues on `MERGE_REQUIRED`"), which is confirmed by the H4 call counts on line 913 (1.00 direct land calls and 0.99 enqueues per landing).
   * *Status read count (line 148 vs. lines 157–158, 264):* Definition 3.2 (line 148) specifies a single status read for authorization at the start of a commit request, whereas Table 4 (line 264) and lines 157–158 report 2 status reads per commit in the burst and 3 in sequential commits. Even if the third read in sequential commits is unexplained (line 158), the second status read present in every commit should be accounted for in Definition 3.2.

6. **House-style violations in multi-claim and signposting paragraphs (Lines 71, 341–342, 355, 504–507, 689):**
   * Eliminate or merge pure signposting paragraphs (lines 71, 355), split multi-claim paragraphs so each paragraph advances a single claim (lines 341–342, 504–507), and state the primary threat to validity at the beginning rather than the end of line 689.

#### Minor Issues

1. **Conflation of the formal knee $N^*$ with the pre-collapse polling peak in Table 6 (Lines 425, 571, 587, 917):**
   * Corollary 6.7 (line 425) defines $N^* = (R_0 + Z)/D_{\max}$, which equals $1{,}609$ agents for all three configurations (line 917). Line 571 states that Table 6 gives "the knee $N^*$ of \cref{cor:sgoc:knee}", but Table 6 (line 587) reports `about 1,550` for C1 and `about 1,600` for C2 and C3. Distinguish the analytical knee $N^* \approx 1{,}600$ from the empirical peak of C1's polling curve ($\approx 1{,}500\text{--}1{,}550$).

2. **Missing "Tree reads" row in Table 4 (Lines 251, 253–275, 907):**
   * Line 251 sums the critical path of a sequential H4 commit from Table 4, including `tree reads (8 ms)` (and line 907 cites `9 ms` for H3 sequential and `8 ms` for H4 sequential), but Table 4 omits the tree-reads phase row. Add this row to Table 4 so the table matches the text.

3. **Lease-holder commit calls in Configuration C2 (Lines 563, 582, 913):**
   * Line 563 defines C2 as moving working refs and commit records to per-workspace Durable Objects while keeping $c_{\mathrm{land}} = 2.24$ and $n_c = 9$ on the repository authority. As lines 507 and 913 show, 7 of the lease holder's $n_c = 9$ calls (and $0.22$ of the $2.24$ calls per landing) are `prepare`, `status`, `record`, and `review-classes` calls to build the octopus merge commit. State explicitly that the combiner builds merge commits on the repository authority even in C2 and C3, and note that $0.03$ batch landings and $0.22$ lease-holder calls per landing in $c_{\mathrm{land}} = 2.24$ were measured at the H4 batch size ($k \approx 31$) rather than at the saturation cap ($k = 64$, where $9/64 = 0.14$).

4. **Implicit assumptions in Proposition 4.2 (Lines 184–191):**
   * Proposition 4.2 assumes the server applies commands of a non-atomic `receive-pack` independently by checking only each command's old ref value and object completeness. Note briefly that repository-wide quotas (such as Artifacts' 1 GB repository limit in Table 1, line 103) can still couple commands in a combined push if the combined pack crosses the quota.

5. **Undefined term "Ledger rows" in Table 5 caption (Line 477):**
   * Line 477 says "Ledger rows are the measurements of \cref{sec:sgoc:measured}", referring to an internal measurement ledger (the `% M...` comments in the TeX source) that does not exist in the rendered text. Replace "Ledger rows" with "Measured rows".

6. **LaTeX typography and formatting (Lines 16, 96, 440, 723, 729, 854, 871, 882):**
   * Use en-dashes (`--`) instead of hyphens in `Pollaczek--Khinchine` (line 440) and in bibliography page ranges (`3411--3424` on line 723, `213--226` on line 729, `78--87` on line 854).
   * In line 16, `\newcolumntype{L}[1]{>{\raggedright\arraybackslash}p{#1}}` suppresses hyphenation of the first word in narrow columns (`L{2.4cm}` in Table 1, `L{3.0cm}` in Table 7); prepend `\hspace{0pt}` or use `\RaggedRight` from `ragged2e`.
   * Add a non-breaking space in `5 to 25~ms` on line 882 to match line 364.

---

VERDICT: MAJOR REVISIONS (major issues remain)
