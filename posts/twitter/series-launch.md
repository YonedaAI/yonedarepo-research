---
platform: twitter
topic: series-launch
title: "Source Code as a Transactional Abstraction"
url: "https://yonedarepo-research.vercel.app"
status: draft
created: 2026-10-20
---

1/4 Source code and source control are now transactional abstractions. A repo is a database, a change is a transaction with read and write sets, landing is an optimistic commit. A 4-paper series makes the argument.
https://yonedarepo-research.vercel.app

2/4 The precedent: data lakes moved from files on object stores to tables with a transaction log, snapshots and optimistic concurrency (Delta Lake), with Spark computing over snapshots. Scion's published design makes the same move for source control.

3/4 Hosted reference realization: 1,000 of 1,000 landed in each of 6 bursts at 1,000 concurrent writers. Commit p95: 714 to 1,673 ms with per-writer tokens (2 of 3 runs under 1 s), 1,140 to 1,614 ms with a shared login.

4/4 Open: no sustained-rate run exists, and Scion's figures come from a different workload, so they are not comparable. The code-evidence appendix cites a private repository.
https://github.com/YonedaAI/yonedarepo-research #SourceControl #Research
