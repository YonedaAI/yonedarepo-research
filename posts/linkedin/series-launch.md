---
platform: linkedin
topic: series-launch
title: "Source Code as a Transactional Abstraction"
url: "https://yonedarepo-research.vercel.app"
status: draft
created: 2026-10-20
---

Source code and source control are now transactional abstractions. A repository is a database, a change is a transaction with a read set and a write set, landing is an optimistic commit, a version is a snapshot, and derived data (search, symbols, checks, Git itself) are views over the log.

The argument rests on precedent. Data lakes moved from files on object stores to tables with a transaction log, snapshots and optimistic concurrency (Delta Lake), with Spark-style computation over snapshots. Scion's published design makes the same move for source control. Our claim: the next evolution in code is transactional.

Four papers: a transaction model, derived data as partitioned views, a serverless realization, and a synthesis. On the hosted reference realization, 1,000 of 1,000 changes landed in each of 6 bursts at 1,000 concurrent writers. Commit p95 was 714 to 1,673 ms with per-writer tokens (2 of 3 runs under 1 s) and 1,140 to 1,614 ms with a shared login.

Open: no sustained-rate run exists, and Scion's figures come from a different workload. The code-evidence appendix cites a private repository.

Papers: https://yonedarepo-research.vercel.app
Repo: https://github.com/YonedaAI/yonedarepo-research

#SoftwareEngineering #SourceControl
