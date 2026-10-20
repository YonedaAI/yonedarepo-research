---
platform: facebook
topic: series-launch
title: "Source Code as a Transactional Abstraction"
url: "https://yonedarepo-research.vercel.app"
status: draft
created: 2026-10-20
---

Source code is starting to look like a database. A change is a transaction and landing it is an optimistic commit. Data lakes made the same move, from loose files to tables with a transaction log (Delta Lake), and Scion's published design does it for source control.

We wrote four papers making the argument. In a hosted test, 1,000 of 1,000 changes landed in each of 6 bursts at 1,000 concurrent writers. No sustained-rate run exists yet, and the code-evidence appendix cites a private repository.

https://yonedarepo-research.vercel.app

#SourceControl #Research
