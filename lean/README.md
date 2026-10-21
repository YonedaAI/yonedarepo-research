# YonedaTx: Lean 4 proofs of merge-conflict resolution in the transactional model

This is a machine-checked formalization of the concurrency-control core of Part I
(`papers/latex/transaction-log-source-control.tex`) and of the Git projection lemma
of Part II (`papers/latex/partitioned-derived-data.tex`, Lemma 13.2). It uses
core Lean 4 only: no Mathlib and no dependencies. The proofs contain no `sorry` or
`admit` and add no `axiom`.

## Build

```sh
cd lean && lake build               # toolchain: leanprover/lean4:v4.35.0 (lean-toolchain)
lake env lean AxiomsReport.lean     # prints the axioms of every main theorem
```

A clean build takes about 2–3 s (wall clock) on the author's machine and reports 0 warnings.

## Headline theorem: batch landing soundness

`batch_landing_sound` (`YonedaTx/Soundness.lean`). Take a log with no Conflict landing
and a batch that the authority accepts at the log's head `H` (`BatchAccepted`).
Accepted means:
- each member was validated against the log since its base as FastForward, Rebase, or a
  **Merge** whose file-level merge with `H` has no conflict path;
- the members satisfy the pairwise rule `(R_j ∪ W_j) ⋈̸ W_i` for `i < j` in ticket order;
- every Merge member is **patch-compatible** with `H` (see below).

Then:

* **(a)** the batch state equals `serialTxns H txns`: serial execution of the members'
  transactions in ticket order, each applied to the state current at its turn. It is also
  the final snapshot of the log followed by the members.
* **(b)** the *declared-access* serialization graph of that log is acyclic. Its edges
  come from the members' declared reads and writes (`SEdge`). A Merge landing also depends
  on the head, which these edges do not record. So for Merge members the
  serializability content of the theorem comes from (a) plus `PatchCompatible`, not from (b).

**Line-level merges.** A file's lines are modelled as child locations `f/ℓ` with
*stable* line keys `ℓ`. Two edits to different lines of one file are then:
- a Rebase when declared at line granularity;
- a Merge when declared at file granularity, whose file-granular merge conflicts
  (`FileConflict`) but whose line-granular merge is clean.

`line_merge_refines` proves the second case in general. If two sides change disjoint
sets of lines of `f`, the line-granular `merge3` has no conflict on `f`, and it equals
applying both diffs. `Witnesses.line_merge_witness` and `Witnesses.batch_witness` give a
concrete instance, to which `batch_landing_sound` applies. **Not covered:** positional
`diff3`, where insertions shift line numbers and hunks must be aligned. Stable line keys
are an abstraction of that.

**The extra hypothesis for Merge members, and why it is exact.** Without it, (a) is
false. `PatchCompatible m H` says that on its write set, running the member's
transaction on `H` gives the member's diff against its own base applied to `H`.
- `merge3State_eq_applyDiff`: a conflict-free three-way merge applies the diff of
  `theirs` to `ours`. So the merged landing always applies the member's diff.
- `merge_serial_iff`: for a conflict-free member, merged landing = running the
  transaction on `H` **iff** `PatchCompatible`. The hypothesis is therefore necessary and
  sufficient for each member.
- `patchCompatible_of_agree`: every FastForward or Rebase member satisfies it
  automatically, so the hypothesis only constrains Merge members.
- `changeset_patchCompatible_iff`: for a changeset (a blind write of `Φ` on `W`), it says
  that no written path whose new content equals its base content was moved by the head.
  In other words, the changeset never writes a stale base value back over a newer one.

**The brief's two candidate hypotheses are not enough.** `merge_not_serial` gives an
accepted single-member Merge batch whose member is a blind write with `R = []`, so its
merged path `x` is not in `R`. It touches `x` without changing it, while `c_x` moved `x`
in between. The merge keeps `x = 1`, but running the member writes back `x = 0`.

Supporting results:
* `batch_landing_merged`: with no patch-compatibility hypothesis, (a) holds in merge form.
  The batch equals `serialMerge H members`: serial execution in ticket order, with each
  member's change merged by `merge3` into the state left by the earlier members.
  (b) holds as well.
* `batch_landing_serial`: when every member is FastForward or Rebase, (a) holds with no
  extra hypothesis.
* `batch_rule_needed`: without the pairwise rule, the two-member write-skew batch is
  accepted member by member, equals neither serial order, and has a cycle `c_a → c_b → c_a`
  in its serialization graph.

The lemmas behind them are `landBatch_eq_seqLand`, `seqLand_eq_serialMerge`,
`batch_merge_sound`, `serialMerge_eq_serialTxns` and `noConflict_append_batch`, together
with the frame lemma, the `merge3` laws and `sgraph_acyclic`.

## Under-declared reads (`YonedaTx/UnderDeclared.lean`)

A transaction's `R` is its *true* read set `R*`. Validation uses declared sets `D i`,
which may miss part of `R*`. Part I's guarantees hold relative to declared reads;
these results say what remains when the declaration is incomplete. (The brief calls this
dropping the "sound refinement" assumption. Part I's Assumption 6.2 concerns refined
*write* sets, so the formal premise dropped here is that declared reads cover the true
reads.)

| Theorem | Statement |
|---|---|
| `under_declared_no_lost_update` | The file-level write check (`WriteChecked`: no conflict path, with no read check) is enough. The value of `p` at version `i` survives to every later `v`, unless a landing in between wrote `p` from a base that held the then-current value of `p`. |
| `under_declared_counterexample` | `c_b: x := y+1` (declared), then `c_a: y := x+1` with no reads declared. Both pass validation and the write check, yet the final state equals neither serial order. With its true reads, `c_a` would be a Conflict. |
| `under_declared_safe` | Sufficient condition: if `R* ∖ D` meets no write set landed after the base, for every entry, then the serializability theorem holds. |
| `under_declared_tight` | The condition cannot be weakened in general. Suppose `R* ∖ D` meets an intervening write set `Wᵢ` while `D` and `Wⱼ ≠ []` do not, so the landing is accepted as a Rebase. Then there exist transactions with write sets `Wᵢ`, `Wⱼ` and true reads `R*` whose final state equals neither serial order. (This is existential. A particular transaction whose "true" read is irrelevant to its output may still be serializable, since `Txn.R` is an upper bound on dependence.) |


## Files

| File | Contents |
|---|---|
| `YonedaTx/Paths.lean` | Paths, `anc` (⊑), overlap `meets` (⋈), access sets, coarsening |
| `YonedaTx/State.lean` | Tree states, agreement `Agree X s t` (≡_X), `ChangesWithin`, transactions `Txn`, changesets |
| `YonedaTx/Merge.lean` | File-level three-way merge `merge3`, its laws, the landing state `landOn` |
| `YonedaTx/Log.lean` | Log entries, snapshots `snap`, `laterWrites`, frame lemma |
| `YonedaTx/Validation.lean` | `validate` (Conflict / FastForward / Rebase / Merge), validated logs, coarsening, Eq. 1 |
| `YonedaTx/Serializability.lean` | Theorem 6.4, Proposition 6.5, Theorem 6.7, Proposition 8.3(3) |
| `YonedaTx/Batch.lean` | Land combiner batches: Theorem 7.2(4), Theorem 7.3, Proposition 7.4 |
| `YonedaTx/Graph.lean` | Serialization graph, refs and first-parent chains, Git projection |
| `YonedaTx/Soundness.lean` | **Headline:** batch landing soundness, and the rule-is-needed companion |
| `YonedaTx/UnderDeclared.lean` | Under-declared reads: no lost update, counterexample, sufficient condition, tightness |
| `YonedaTx/Witnesses.lean` | Non-vacuity witnesses: line-level merge, accepted batch with a Merge member, serializability, frame, under-declared safe |

## Paper result → Lean theorem

| Paper result | Lean theorem(s) | File |
|---|---|---|
| Def. 4.4 location tree, overlap | `anc`, `meets`, `meetsSet`, `covered` | Paths |
| Lemma 4.5 (overlap): ⋈ iff common descendant | `overlap_iff_common_descendant` | Paths |
| Lemma 4.5: reflexive, symmetric | `overlap_refl`, `overlap_symm` | Paths |
| Lemma 4.5: `a' ⊑ a`, `a ⋈ b` ⇒ `a' ⋈ b` | `overlap_coarsen`, `meetsSet_coarsen` (sets) | Paths |
| Def. 4.7 independence (Eq. 1) | `Independent` | Validation |
| Def. 4.8–4.11 log, snapshot | `Entry`, `Log`, `snap` | Log |
| Def. 4.15 validation, **adapted**: one granularity (the same write sets for both checks), no opaque entries, one ref | `validate`, `validateAt` | Validation |
| Thm. 5.4 refs advance along first-parent chains (claim 1) | `refs_advance` | Graph |
| Thm. 5.4 (claim 2): equal values ⇒ no entry names the ref | `refs_unchanged_no_entry` | Graph |
| Cor. 5.5 no lost update | `no_lost_update` | Graph |
| Thm. 5.6 snapshot immutability (tree states) | `snap_append`, `snap_of_take_eq` | Log |
| Assumption 6.2 (sound refinement), one step | `ChangesWithin`, `Txn.frame`, `snap_step_changesWithin` | State, Log |
| Lemma 6.3 frame (**adapted**: `Agree` includes ancestors and directory nodes) | `frame_lemma`, `frame_point`, `frame_of_laterWrites` | Log |
| Thm. 6.4 part 1 (reads current; **adapted** `Agree`) | `reads_current` | Serializability |
| Thm. 6.4 part 2 (FastForward) | `fastForward_landing` | Serializability |
| Thm. 6.4 part 3 (Rebase = C on W, head elsewhere) | `rebase_landing`, `landOn_rebase` | Serializability, Merge |
| Thm. 6.4 serializability (FF/Rebase logs ≡ serial in log order; reads equal serial reads; **adapted** `Agree`) | `serializability` | Serializability |
| Prop. 6.5 merged writes, file level (ours/theirs/base) | `merge3_spec` | Merge |
| Prop. 6.5: uniqueness of the merged state | `merge3_unique`, `merge3_spec_iff` | Merge |
| Prop. 6.5 in the log (outside W, W∖M, M) | `merged_writes` | Serializability |
| merge3 commutativity, identities, idempotence | `merge3_comm`, `merge3State_comm`, `merge3_base_left`, `merge3_base_right`, `merge3_idem` | Merge |
| Conflict characterization; disjoint write sets ⇒ no conflict | `merge_conflict_characterization`, `merge3_conflict_iff`, `merge_no_conflict_of_disjoint` | Merge |
| Thm. 6.7 independence ⇔ second landing is Rebase in both orders | `independence_iff_rebase` | Validation |
| Thm. 6.7: both orders give the same state (= both serial orders) | `independence` | Serializability |
| Prop. 6.10 coarsening is sound (outcomes) | `coarsening_sound`, `coarsens_replaceAccess` | Validation, Paths |
| Prop. 6.10 (Eq. 1 after coarsening ⇒ before; Assumption 6.2 preserved) | `independent_of_coarsened`, `coarsening_preserves_frame` | Validation |
| Thm. 7.2 property 4 (member reads current; **adapted** `Agree`) | `combiner_member_reads` | Batch |
| Thm. 7.3 batch write skew (concrete history) | `batch_write_skew` | Batch |
| Prop. 7.4 serializable batches (batch = sequential = serial) | `batch_serializable`, `batch_serializable_log` | Batch |
| Prop. 7.4 part 1, validation half | `batch_sequential_validates` | Batch |
| Proof of Thm. 6.4 via BHG Thm. 2.1: edges forward, graph acyclic | `sgraph_edge_forward`, `sgraph_reach_forward`, `sgraph_acyclic` | Graph |
| Prop. 7.4 with Merge members, at the log (headline) | `batch_landing_sound`, `batch_landing_merged`, `batch_landing_serial` | Soundness |
| Merged landing = serial step iff patch-compatible; counterexample | `merge3State_eq_applyDiff`, `merge_serial_iff`, `changeset_patchCompatible_iff`, `patch_patchCompatible_iff`, `merge_not_serial` | Merge, Batch, Soundness |
| Thm. 7.3 / Prop. 7.4: the rule is needed (G2-item cycle) | `batch_rule_needed` | Soundness |
| Batch of disjoint writes = sequential landing = serial merges | `landBatch_eq_seqLand`, `seqLand_eq_serialMerge`, `batch_merge_sound` | Batch |
| Under-declared reads (no lost update, counterexample, sufficient condition, tightness) | `under_declared_no_lost_update`, `under_declared_counterexample`, `under_declared_safe`, `under_declared_tight` | UnderDeclared |
| Prop. 6.5 at line granularity (stable line keys) | `line_merge_refines`, `Witnesses.line_merge_witness` | Merge, Witnesses |
| Non-vacuity of the headline and of Thm. 6.4 / Lemma 6.3 / `under_declared_safe` | `Witnesses.batch_witness`, `serializability_witness`, `frame_witness`, `under_declared_safe_witness` | Witnesses |
| Prop. 8.3 part 3 (changeset landing applies Φ) | `changeset_landing` | Serializability |
| Part II Lemma 13.2 (projection is a function of the prefix) | `projection_deterministic`, `projection_stable` | Graph |
| Part I Assumption 8.2 / Part II: first parent of P(j+1) is P(j) | `projection_first_parent`, `projection_tree` | Graph |
| Prop. 8.3 part 5 (projected commits form a first-parent chain) | `projection_chain` | Graph |

180 theorem declarations in total (`grep -cE '^(@\[[^]]*\] )?theorem ' YonedaTx/*.lean`: 173 plain and 7 with attributes), helpers included. `AxiomsReport.lean` checks the 72 main ones.

## The model

* **Paths.** `Path = List String`. `anc a b` (a ⊑ b) is component-wise prefix, so
  `src/a` is not an ancestor of `src/ab`. Symbols are extra path components
  (`src/lib.rs#P::f` ↦ `["src","lib.rs","P","f"]`). Access sets are `List Path`.
* **States.** `State = Path → Option Nat`; `none` is ⊥. Blobs are `Nat`.
* **Agreement.** `Agree X s t`: `s p = t p` for every `p` that overlaps some element of
  `X`. This contains the paper's region `⋃ sub(x)`.
* **Transactions.** `Txn` has `R`, `W` and `f : State → State` with
  `frame`: `f s p = s p` when `p` is not covered by `W` (paper: changed locations lie in
  `⋃_{w∈W} sub(w)`, Assumption 6.2); and `reads`: on locations covered by `W`, `f s`
  depends only on `s` restricted to `R ∪ W`.
* **Log.** `snap init log 0 = init`; entry `v+1` lands `f (snap base)` onto `snap v` by
  `landOn` = three-way merge with base `snap base`, ours = head, theirs = the change.
* **Validation.** Definition 4.15 at a single granularity, without opaque entries or
  per-ref filtering. The stale-read and write-overlap tests both use the later entries'
  declared write sets.
* **Merge.** `merge3 b o t p` = `ok (t p)` if `o p = b p`, else `ok (o p)` if
  `t p = b p`, else `ok (o p)` if `o p = t p`, else `conflict`.
* **Batches.** Each member is merged against the head; the octopus merge takes, at
  each location, the first member whose merged change differs from the head.
* **Refs.** A ref log of `(ref, new commit)` entries; parents are a function
  `CommitId → List CommitId`; Lemma 5.3 (append discipline) and the generation
  ordering are hypotheses (`AppendDiscipline`, `GenOk`).
* **Projection.** `GitCommit` is the data a commit's bytes encode. Equal data means
  equal commits, which models content addressing with no hash collision.

## Differences from the paper

Statements that changed, and why:

1. **merge3 definition.** The brief's literal definition
   (`if ours = base then theirs else if theirs = base then ours else conflict`)
   makes `merge3 b x x` a conflict wherever `x ≠ b`, so idempotence would be false.
   The model adds the standard `diff3`/Git clause "both sides made the same change ⇒ no
   conflict". With it, a conflict path is exactly "changed on both sides to *different*
   values" (`merge3_conflict_iff`), which is the brief's own characterization.
2. **Agreement vs. write frame.** Agreement uses the brief's region (locations that
   *overlap* `X`, i.e. `sub(x)` plus the ancestors of `x`), which is stronger than the
   paper's `⋃ sub(x)`. The write frame must then use the paper's `⋃ sub(w)`, not the
   overlap region of `W`. With both on the overlap region the frame lemma is false:
   `X = {a/b}`, `W = {a/c}` do not overlap, yet a write allowed at the shared ancestor
   `a` would change a location in the region of `X`.
3. **Reads depend on R ∪ W, not R alone.** Allowing writes to depend on the written
   locations (read-modify-write, patches) is a weaker requirement on transactions, so
   every theorem is at least as strong as with "depends on R only".
4. **Per-location merge; lines via stable keys.** `merge3` merges per location. If a file
   is a single location, two different edits to it always conflict. Modelling its lines as
   sub-locations `f/ℓ` with stable keys recovers the clean combination of edits to
   different lines (`line_merge_refines`, `Witnesses.line_merge_witness`). Positional
   `diff3` is not modelled: insertions and deletions that shift line numbers, and the
   alignment of hunks. So `merge3_comm` and `merge3_idem` hold here, but would not carry
   over to positional `diff3` (Khanna, Kunal and Pierce). `merged_writes` holds for every
   landing, not only for Merge outcomes.
5. **Conflicting landings.** In the paper a merge conflict is refused. `landOn` falls
   back to the change's value on a conflict path, so the log stays total. No theorem uses
   the fallback beyond "a landing changes only `W`". The serializability results exclude
   Merge, and under Rebase there are no conflict paths.
6. **One ref, one granularity.** Entries on other refs, opaque entries (empty touched
   list, kind not commit/merge) and refined write sets `W^ρ` are not modelled. Stale-read
   and write-overlap tests use the same sets, so Corollary 6.8 (symbol granularity) is
   not formalized.
7. **Consistent base is built in.** A change is computed on `snap base`, so
   Assumption 6.1 holds by construction, as for changesets (Prop. 8.3(2)). Commits and
   `fp(c)` do not appear in the transaction log. Thm. 6.4 part 2 therefore says
   "FastForward ⇒ base = head version and the change is installed", not
   "`Snap(v−1) = fp(c)`". The log starts at version 0 rather than at an arbitrary `v₀`.
8. **FastForward.** Following Def. 4.15, FastForward means "no later entries"; with a
   base ≤ head this is equivalent to `b = n` (`fastForward_landing`), the brief's phrasing.
9. **Theorem 6.7.** The paper's equivalence is proved at the validation level
   (`independence_iff_rebase`). The state equality is the forward direction only
   (`independence`). "No other entry in between" is modelled as `pre.length = b`.
10. **Proposition 6.10.** Coarsening is allowed on R, W and every later write set at
    once (`CoarsensAll`). FastForward/Rebase are not claimed to be preserved: coarsening
    may strengthen them, as in the paper.
11. **Theorem 7.3.** Proved for a concrete history built in the model:
    `c₀` writes `z`, `c_a: y := x+1`, `c_b: x := y+1`, both based at version 0. It is not
    a statement about the code at `cfa4845`. The adapter's deferral rule is modelled as
    disjoint *declared* write sets (`meetsSet ca.W cb.W = false`), not merged paths. The
    authority's re-validation is per-member `validateAt` against the log.
12. **Proposition 7.4.** Part 1 is proved for members whose reads and writes agree between
    base and head, which FastForward/Rebase validation gives (`batch_serializable_log`).
    Members validated as Merge (line-level) are not covered. Part 2 ("conflict-serializable")
    is proved semantically: the batch state equals serial execution in ticket order.
13. **BHG Theorem 2.1.** The generic theorem "acyclic serialization graph ⇒ serializable"
    is not formalized. The model proves the direction Part I uses: every edge of a
    no-Conflict log's graph points forward, so the graph is acyclic and log order is a
    topological order. It then proves serializability directly as a state equality
    (`serializability`). The acyclicity result needs only "no Conflict", so it also holds
    with Merge landings. There, however, it is a statement about the *declared-access*
    graph only. A Merge landing reads the head, which `SEdge` does not record, so for Merge
    members the semantic content is `batch_landing_sound` (a) with `PatchCompatible`.
14. **Refs.** Lemma 5.3 is a property of the code. Here it is the hypothesis
    `AppendDiscipline`. Generations are a hypothesis `GenOk` (parents have a smaller
    generation). There is no ref deletion, matching the implemented kinds.
15. **Projection.** Versions are counted from `u`, so `P(0) = h_u`. The history before `h_u`
    is not modelled (its `firstParent` is `none`). Hashing is abstracted as above.
    "Rebuilt after a crash reproduces the ids" is `projection_deterministic`: the
    projection is a pure function of the prefix.

16. **Headline: the resulting log.** The paper appends *one* batch entry, with the union
    of the read sets and the smallest base. The model's `Entry` holds one transaction and its
    base, so it represents the batch by the members appended individually in ticket order,
    as the paper's proof of Prop. 7.4(2) does. `batch_landing_sound` proves that the final
    snapshot of that log equals the single batch entry's state (`landBatch`).
17. **Headline: acceptance.** `MemberAccepted` also allows FastForward members, which the
    paper lands alone; allowing them only makes the theorem more general. Part (a) uses only
    the write half of the rule (pairwise disjoint write sets) and no conflict path. The read
    half is used for (b) and for `batch_landing_serial`. Part (a)'s "serial execution with
    file-level merges" is `serialMerge`: each member's change, computed on its own base,
    merged by `merge3` into the state left by the earlier members. Under write skew this
    still equals the batch (`batch_rule_needed` shows it is not a serial order of the
    *transactions*). Prop. 7.4 in the paper excludes Merge members. The headline covers them,
    under the extra hypothesis `PatchCompatible`, which `merge_serial_iff` shows is exact
    and `merge_not_serial` shows cannot be dropped.
18. **Under-declared reads.** "The base held the then-current value" compares values,
    not versions, so an ABA history counts as seen. The no-lost-update theorem assumes the
    write check `WriteChecked` directly. `ValidatedDecl.writeChecked` shows that validation
    with any declared sets implies it. The counterexample uses the two transactions of the
    write-skew example, landed one at a time.

Not formalized: Prop. 4.3 (rewrite cost), Thm. 5.1 (replay determinism), Prop. 5.2
(tamper evidence), checkpoints, Thm. 7.2 properties 1–3 and 5 (versions, epochs, leases),
Cor. 6.8, Def. 7.5 (repairs), and the Kung–Robinson correspondence as a theorem.

## Axioms report

`lake env lean AxiomsReport.lean` prints, for every main theorem, a subset of
`[propext, Quot.sound]`. No theorem uses `Classical.choice`, `sorryAx` or any added
axiom. `overlap_symm`, `merge3_spec`, `projection_first_parent`, `projection_tree`,
`changeset_patchCompatible_iff` and `line_merge_refines` use only `propext`. The other theorems use `propext` and `Quot.sound`. `Quot.sound`
comes in through `funext` (state equality) and core `simp` lemmas.
