# Source Code as a Transactional Abstraction

Source code and source control are now transactional abstractions. This repository holds four papers that lay the foundations for that view, along with the website that presents them. In the model, a repository is a database, a change is a transaction with a read set and a write set, landing is an optimistic commit, a version is a snapshot, and derived data (search, symbols, checks, and Git itself) are views over the log.

The argument rests on precedent. Data lakes moved from files on object stores to tables with a transaction log, snapshots and optimistic concurrency (Delta Lake), with Spark-style computation over snapshots. Anthropic's published Scion design makes the same move for source control. The papers give definitions, proofs reduced to established results from data systems, and one working serverless realization with measured costs and open problems.

**Website:** https://yonedarepo-research.vercel.app

## Papers

| | Paper | Pages | PDF |
|---|---|---|---|
| Overview | Source Code as a Transactional Abstraction (synthesis) | 26 | [synthesis.pdf](papers/pdf/synthesis.pdf) |
| Part I | A Transaction Log for Source Control | 35 | [transaction-log-source-control.pdf](papers/pdf/transaction-log-source-control.pdf) |
| Part II | Partitioned Derived Data | 36 | [partitioned-derived-data.pdf](papers/pdf/partitioned-derived-data.pdf) |
| Part III | A Cloud-Portable Architecture for Serverless Git | 35 | [serverless-git-on-cloudflare.pdf](papers/pdf/serverless-git-on-cloudflare.pdf) |
| Part IV | Machine-Checked Batch Landing: Merge Resolution and Serializability in a Transactional Model of Source Control | 38 | [machine-checked-batch-landing.pdf](papers/pdf/machine-checked-batch-landing.pdf) |

## Machine-checked proofs (Lean 4)

`lean/` is a Lake project, `YonedaTx`. It contains 180 theorem declarations with no `sorry`, uses only the axioms `propext` and `Quot.sound`, and depends on core Lean 4 v4.35.0 alone (no Mathlib). Build it with `cd lean && lake build`, which takes about 3 s from clean.

- `batch_landing_sound`: an accepted batch of changesets, merges included, equals serial execution in ticket order, and its declared-access serialization graph is acyclic.
- `merge_serial_iff`: a merged landing is serializable exactly when the change is patch-compatible with the head, meaning it never writes a stale base value back over a path the head moved.
- `batch_rule_needed`: without the pairwise check, a two-change batch is accepted, matches neither serial order and has a cycle in its serialization graph.
- `line_merge_refines`: different edits to one file merge cleanly at line granularity, where lines have stable keys.
- `under_declared_*`: reads that are not declared can break serializability. Write checks alone still prevent lost updates, and a tight condition says when undeclared reads are safe.

Not covered: positional diff3 (insertions that shift line numbers), multiple refs, and the implementation code. The theorems are about the model. See `lean/README.md` for the mapping from paper results to Lean theorems. An adversarial Codex review of the Lean code ran 2 rounds. Round 1 found 3 major scope issues: validation was overstated as "exact", merges were file-atomic, and a sufficient condition was called "exact". All 3 were fixed. Round 2 confirmed the fixes.

LaTeX sources are in `papers/latex/`, and HTML versions are in `docs/papers/`.

## What each paper contributes

- **Part I** gives the transaction model. Its results are replay determinism, snapshot immutability, refs that advance only along first-parent chains, and serializability relative to declared read sets, proved by reduction to Kung-Robinson validation and the serialization-graph theorem. It also maps the model onto Delta Lake. The analysis found batch write skew (Adya G2-item) in the land combiner; the fix, a within-batch check, is in the code at `c4c8f47` and on the development branch at `fef94e7`.
- **Part II** treats derived data as incrementally maintained views that are correct at a snapshot. It relies on deep constructive traces and DBSP-style incrementalization, and shows that Git is one of these views: main's Git commits are a deterministic projection of the log. The analysis also found a search-key defect, a view-consistency failure under directory renames, and proves two repairs.
- **Part III** describes a cloud-portable architecture over six primitives, with Cloudflare as the reference realization. It reports measured results, including negative ones, and gives a capacity model built on Denning-Buzen operational laws.
- **Synthesis** argues that the next evolution in code is transactional. It adds composition results, closure coverage for agent transactions, and a mapping to the companion paper, "The Inversion of Software Maintainability in AI-Native Repositories".

## Measured results (hosted, reference realization)

Every number comes from raw benchmark output, and every range covers all runs.

| 1,000 concurrent writers, build `fef94e7` | Per-writer tokens (3 runs) | Shared login (3 runs) |
|---|---|---|
| Landed | 1,000 of 1,000 in every run | 1,000 of 1,000 in every run |
| Commit p95 | 714 to 1,673 ms (2 of 3 under 1 s) | 1,140 to 1,614 ms (0 of 3 under 1 s) |
| Land p95 | 1.21 to 1.87 s | 2.17 to 3.03 s |
| Git projection delay p95 | 3.5 to 4.6 s | 3.2 to 5.4 s |

Controlled comparison at `dd6c9a8`, with 1,000 writers on one deploy. Polling landed 4, the combiner landed 385 and changeset landing landed all 1,000.

Still open:
- No sustained-rate run exists; the landing rates are burst-span averages.
- Reads served by the authority under a burst succeeded 540 of 1,000 times.
- No workload has exercised the write-skew check.
- Scion's published figures come from a different workload, so they are not comparable to these runs.

## Evidence and review

- Each paper ends with a code-evidence appendix: claim, file, commit, and what the code shows. Codex audited every row, and all 128 rows were judged SUPPORTS (Part I 33, Part II 44, Part III 39, synthesis 12). The YonedaRepo source repository is private, so the rows cite files and commits.
- Gemini peer reviews and the responses to them are in `reviews/`. Final verdicts:
  - Part I and the synthesis: minor revisions.
  - Part II: major revisions, with no critical items after five rounds.
  - Part III: major revisions after three rounds, the cap.
  - Every item is fixed or answered in that paper's response file.
- Every bibliography entry was resolved online, and every DOI matched its Crossref metadata.

## Site

The site is a Next.js static export, in `website/`. To rebuild the paper HTML, run `cd website && npm run papers && npm run build`. This step needs `pdflatex` and `pandoc`.

## Citation

Matthew Long and The YonedaAI Collaboration. *Source Code as a Transactional Abstraction*. YonedaAI Research Collective, Chicago, IL, October 2026.

Contact: matthew@yonedaai.com · https://yonedaai.com
