import YonedaTx.Graph

/-!
# Batch landing soundness

The headline theorem `batch_landing_sound`. Take a batch of members accepted by the
authority: each is validated against the log since its base as FastForward, Rebase,
or a file-level Merge with no conflict path, and the pairwise rule of Part I,
Proposition 7.4, holds in ticket order. Then:

* (a) the batch installs serial execution of the members' transactions in ticket order,
  each applied to the state current at its turn, provided every Merge member is
  patch-compatible with the head; and
* (b) the declared-access serialization graph of the resulting log is acyclic. For
  Merge members, which also read the head, the serializability content is (a) with
  patch-compatibility; (b) records declared reads and writes only.

The resulting log is the log followed by the members in ticket order, as in the proof
of Proposition 7.4, part 2. Its final snapshot is the state of the single batch entry.

Companions:
* `batch_landing_merged`: without patch-compatibility, (a) still holds with each
  member's change merged by `merge3` (`serialMerge`), and (b) holds.
* `merge_not_serial`: patch-compatibility cannot be dropped. A blind write whose merged
  path is not in its read set already breaks (a).
* `batch_rule_needed`: the pairwise rule cannot be dropped.
-/

namespace YonedaTx

variable {init : State} {log : Log} {ms : List Entry}

/-- A member the authority accepts at head `log.length`: validated against the log since
its base as FastForward or Rebase, or as a Merge whose file-level merge with the head
has no conflict path. -/
def MemberAccepted (init : State) (log : Log) (e : Entry) : Prop :=
  e.base ≤ log.length ∧
    match validateAt log log.length e.txn.R e.txn.W e.base with
    | .fastForward | .rebase => True
    | .merge => ∀ p, ¬ ConflictAt (snap init log e.base) (snap init log log.length)
        (e.txn.f (snap init log e.base)) p
    | .conflict => False

/-- A batch the authority accepts: every member accepted, and the pairwise rule
`(R_j ∪ W_j) ⋈̸ W_i` for `i < j` in ticket order. -/
structure BatchAccepted (init : State) (log : Log) (ms : List Entry) : Prop where
  member : ∀ e ∈ ms, MemberAccepted init log e
  rule : ms.Pairwise fun ei ej => BatchRule ei.txn ej.txn

theorem MemberAccepted.of_clean {e : Entry} (hb : e.base ≤ log.length)
    (hc : (validateAt log log.length e.txn.R e.txn.W e.base).clean = true) :
    MemberAccepted init log e := by
  refine ⟨hb, ?_⟩
  revert hc
  cases validateAt log log.length e.txn.R e.txn.W e.base <;> simp [Outcome.clean]

theorem MemberAccepted.of_merge {e : Entry} (hb : e.base ≤ log.length)
    (hv : validateAt log log.length e.txn.R e.txn.W e.base = .merge)
    (hnc : ∀ p, ¬ ConflictAt (snap init log e.base) (snap init log log.length)
      (e.txn.f (snap init log e.base)) p) :
    MemberAccepted init log e :=
  ⟨hb, by rw [hv]; exact hnc⟩

theorem MemberAccepted.not_conflict {e : Entry} (h : MemberAccepted init log e) :
    validateAt log log.length e.txn.R e.txn.W e.base ≠ .conflict := by
  obtain ⟨-, h⟩ := h
  intro hc; rw [hc] at h; exact h

theorem MemberAccepted.no_conflict_path {e : Entry} (h : MemberAccepted init log e) (p : Path) :
    ¬ ConflictAt (snap init log e.base) (snap init log log.length)
      (e.txn.f (snap init log e.base)) p := by
  obtain ⟨hb, h⟩ := h
  revert h
  cases hv : validateAt log log.length e.txn.R e.txn.W e.base <;> intro h
  · exact h.elim
  · exact h p
  · exact no_conflict_path_of_clean hb (by rw [hv]; rfl) p
  · exact no_conflict_path_of_clean hb (by rw [hv]; rfl) p

theorem BatchAccepted.writesDisjoint (h : BatchAccepted init log ms) :
    WritesDisjoint (ms.map (toMember init log)) := by
  apply List.pairwise_map.2
  refine h.rule.imp fun {ei ej} hr => ?_
  show meetsSet ei.txn.W ej.txn.W = false
  have : meetsSet (ej.txn.R ++ ej.txn.W) ei.txn.W = false := hr
  rw [meetsSet_append_left, Bool.or_eq_false_iff] at this
  rw [meetsSet_symm]; exact this.2

/-- Landing the members one by one after `log` gives, after `j` of them, the sequential
landing of the first `j` members on the head. -/
theorem snap_append_members (hb : ∀ e ∈ ms, e.base ≤ log.length) :
    ∀ j, j ≤ ms.length → snap init (log ++ ms) (log.length + j) =
      seqLand (snap init log log.length) ((ms.take j).map (toMember init log)) := by
  intro j
  induction j with
  | zero => intro _; simp [snap_append, seqLand]
  | succ j ih =>
    intro hj
    have hjl : j < ms.length := by omega
    have he : ms[j]? = some ms[j] := List.getElem?_eq_getElem hjl
    have hbase : ms[j].base ≤ log.length := hb _ (List.getElem_mem hjl)
    have hget : (log ++ ms)[log.length + j]? = some ms[j] := by
      rw [List.getElem?_append_right (by omega), Nat.add_sub_cancel_left, he]
    rw [← Nat.add_assoc, snap_succ hget (by omega), ih (by omega),
      snap_append _ _ hbase, List.take_add_one, he]
    simp only [Option.toList, List.map_append, List.map_cons, List.map_nil, seqLand,
      List.foldl_append, List.foldl_cons, List.foldl_nil]
    rfl

/-- The log followed by an accepted batch, member by member, has no Conflict landing. -/
theorem noConflict_append_batch (hlog : NoConflict log) (hacc : BatchAccepted init log ms) :
    NoConflict (log ++ ms) := by
  intro i e he
  rcases Nat.lt_or_ge i log.length with hi | hi
  · -- an entry of `log`: its validation is unchanged
    rw [List.getElem?_append_left hi] at he
    obtain ⟨hb, hc⟩ := hlog i e he
    refine ⟨hb, ?_⟩
    rw [validateAt, laterWrites_append_le _ _ (Nat.le_of_lt hi)]
    exact hc
  · -- the `j`-th member, validated after the log and the `j` earlier members
    obtain ⟨j, rfl⟩ : ∃ j, i = log.length + j := ⟨i - log.length, by omega⟩
    rw [List.getElem?_append_right hi, Nat.add_sub_cancel_left] at he
    have hmem : e ∈ ms := List.mem_of_getElem? he
    have hacc' := hacc.member e hmem
    refine ⟨by have := hacc'.1; omega, ?_⟩
    rw [validateAt, laterWrites_append_batch _ _ j hacc'.1]
    refine (batch_sequential_validates (fun Wi hWi => ?_) hacc'.not_conflict).1
    -- `Wi` belongs to an earlier member, so the rule applies
    obtain ⟨ei, hei, rfl⟩ := List.mem_map.1 hWi
    have hsplit := hacc.rule
    rw [← List.take_append_drop j ms, List.pairwise_append] at hsplit
    have hed : e ∈ ms.drop j := by
      apply List.mem_of_getElem? (i := 0)
      rw [List.getElem?_drop, Nat.add_zero, he]
    exact hsplit.2.2 ei hei e hed

/-- **Batch landing soundness, merge form.** For a log with no Conflict landing and a
batch the authority accepts at its head `H`:
(a) the batch entry installs serial execution of the members in ticket order, with
each member's change merged by `merge3` (location by location), and this is also the
final state of the log followed by the members; and
(b) the declared-access serialization graph of that log is acyclic. -/
theorem batch_landing_merged (hlog : NoConflict log) (hacc : BatchAccepted init log ms) :
    let H := snap init log log.length
    let batch := landBatch H (ms.map (toMember init log))
    batch = serialMerge H (ms.map (toMember init log)) ∧
    snap init (log ++ ms) (log.length + ms.length) = batch ∧
    ∀ i, ¬ SReach (log ++ ms) i i := by
  intro H batch
  have hW := hacc.writesDisjoint
  refine ⟨?_, ?_, sgraph_acyclic (noConflict_append_batch hlog hacc)⟩
  · apply batch_merge_sound _ hW
    intro m hm p
    obtain ⟨e, he, rfl⟩ := List.mem_map.1 hm
    exact (hacc.member e he).no_conflict_path p
  · rw [snap_append_members (fun e he => (hacc.member e he).1) ms.length (Nat.le_refl _),
      List.take_length]
    exact (landBatch_eq_seqLand _ hW H).symm

/-- Every accepted member that is not a Merge is patch-compatible with the head. -/
theorem MemberAccepted.patchCompatible {e : Entry} (h : MemberAccepted init log e)
    (hm : validateAt log log.length e.txn.R e.txn.W e.base ≠ .merge) :
    PatchCompatible (toMember init log e) (snap init log log.length) := by
  apply patchCompatible_of_agree
  show Agree (e.txn.R ++ e.txn.W) (snap init log e.base) (snap init log log.length)
  apply clean_agree h.1
  have := h.not_conflict
  revert hm this
  cases validateAt log log.length e.txn.R e.txn.W e.base <;> simp [Outcome.clean]

/-- **Batch landing soundness.** Let `log` have no Conflict landing, and let the batch
`ms` be accepted at the head `H` (FastForward, Rebase, or conflict-free Merge members,
and the pairwise rule in ticket order). Suppose every Merge member is patch-compatible
with `H`. Then
(a) the batch state is serial execution of the members' transactions in ticket order,
each applied to the state current at its turn, and it is the final snapshot of the log
followed by the members; and
(b) the declared-access serialization graph of that log is acyclic. (For Merge members
the semantic content is (a); the graph records declared reads and writes only.) -/
theorem batch_landing_sound (hlog : NoConflict log) (hacc : BatchAccepted init log ms)
    (hpatch : ∀ e ∈ ms, validateAt log log.length e.txn.R e.txn.W e.base = .merge →
      PatchCompatible (toMember init log e) (snap init log log.length)) :
    let H := snap init log log.length
    let batch := landBatch H (ms.map (toMember init log))
    batch = serialTxns H (ms.map (·.txn)) ∧
    snap init (log ++ ms) (log.length + ms.length) = batch ∧
    ∀ i, ¬ SReach (log ++ ms) i i := by
  intro H batch
  obtain ⟨ha, hb, hc⟩ := batch_landing_merged hlog hacc
  refine ⟨?_, hb, hc⟩
  show landBatch (snap init log log.length) (ms.map (toMember init log)) = _
  rw [ha]
  have := serialMerge_eq_serialTxns (ms.map (toMember init log))
    (by rw [List.map_map]; exact List.pairwise_map.2 hacc.rule) H
    (fun m hm p => by
      obtain ⟨e, he, rfl⟩ := List.mem_map.1 hm
      exact (hacc.member e he).no_conflict_path p)
    (fun m hm => by
      obtain ⟨e, he, rfl⟩ := List.mem_map.1 hm
      by_cases hmerge : validateAt log log.length e.txn.R e.txn.W e.base = .merge
      · exact hpatch e he hmerge
      · exact (hacc.member e he).patchCompatible hmerge)
  rw [this, List.map_map]
  rfl

/-- When every member is FastForward or Rebase, the batch is plain serial execution of
the members' transactions in ticket order (Proposition 7.4). -/
theorem batch_landing_serial (hacc : BatchAccepted init log ms)
    (hclean : ∀ e ∈ ms, (validateAt log log.length e.txn.R e.txn.W e.base).clean = true) :
    landBatch (snap init log log.length) (ms.map (toMember init log)) =
      serialTxns (snap init log log.length) (ms.map (·.txn)) :=
  batch_serializable_log ms hacc.rule fun e he => ⟨(hacc.member e he).1, hclean e he⟩

/-! ## The pairwise rule is needed -/

open WriteSkew in
/-- **The rule is needed** (Theorem 7.3). Without the pairwise rule, the two-member
write-skew batch is accepted member by member: both are Rebase against the log. Its
batch state equals neither serial order, and the log with the members has a cycle in
its serialization graph (`c_a → c_b → c_a`, two read–write anti-dependencies:
Adya's G2-item). -/
theorem batch_rule_needed :
    let ms : List Entry := [⟨ca, 0⟩, ⟨cb, 0⟩]
    let H := snap s0 WriteSkew.log 1
    let batch := landBatch H (ms.map (toMember s0 WriteSkew.log))
    (∀ e ∈ ms, MemberAccepted s0 WriteSkew.log e) ∧
    ¬ ms.Pairwise (fun ei ej => BatchRule ei.txn ej.txn) ∧
    batch ≠ serialTxns H [ca, cb] ∧ batch ≠ serialTxns H [cb, ca] ∧
    SReach (WriteSkew.log ++ ms) 1 1 := by
  intro ms H batch
  have hskew := batch_write_skew
  refine ⟨?_, ?_, hskew.2.2.2.2.2.1, hskew.2.2.2.2.2.2.1, ?_⟩
  · intro e he
    simp only [ms, List.mem_cons, List.not_mem_nil, or_false] at he
    rcases he with rfl | rfl
    · exact MemberAccepted.of_clean (by decide) (by decide)
    · exact MemberAccepted.of_clean (by decide) (by decide)
  · intro h
    have := List.pairwise_cons.1 h
    have hr : meetsSet (cb.R ++ cb.W) ca.W = false := this.1 ⟨cb, 0⟩ List.mem_cons_self
    revert hr; decide
  · -- read–write edges both ways between `c_a` (index 1) and `c_b` (index 2)
    have e₁₂ : SEdge (WriteSkew.log ++ ms) 1 2 :=
      ⟨⟨ca, 0⟩, ⟨cb, 0⟩, rfl, rfl, by decide, Or.inr (Or.inr ⟨by decide, by decide⟩)⟩
    have e₂₁ : SEdge (WriteSkew.log ++ ms) 2 1 :=
      ⟨⟨cb, 0⟩, ⟨ca, 0⟩, rfl, rfl, by decide, Or.inr (Or.inr ⟨by decide, by decide⟩)⟩
    exact .tail (.edge e₁₂) e₂₁


/-! ## Patch-compatibility is needed -/

namespace MergeCE

open WriteSkew

/-- `c_x` sets `x := 1`. -/
def cx : Txn := Txn.changeset [] [pX] (setAt s0 pX (some 1))

/-- `m`, built on version 0, is a blind write with no reads: it writes `x` back with its
base value `0` and sets `y := 1`. -/
def m : Txn := Txn.changeset [] [pX, pY] (setAt s0 pY (some 1))

def mlog : Log := [⟨cx, 0⟩]

theorem msnap0 : snap s0 mlog 0 = s0 := snap_zero _ _

theorem msnap1 : snap s0 mlog 1 = cx.f s0 := by
  rw [snap_succ (e := ⟨cx, 0⟩) rfl (Nat.le_refl 0), snap_zero, landOn_self]

end MergeCE

open WriteSkew MergeCE in
/-- **Patch-compatibility is needed.** The single member `m` is a blind write (a
changeset) with an empty read set, so its merged path `x` is not in `R`. It is
validated as a Merge against the log (`c_x` wrote `x`) with no conflict path, and the
batch is accepted. Yet the batch state differs from running `m` on the head: the merge
keeps `c_x`'s `x = 1`, which `m` never changed, while running `m` writes back `x = 0`.
`m` is exactly not patch-compatible: it writes a stale base value over a newer one. -/
theorem merge_not_serial :
    let ms : List Entry := [⟨m, 0⟩]
    let H := snap s0 MergeCE.mlog 1
    validateAt MergeCE.mlog 1 m.R m.W 0 = .merge ∧ m.R = [] ∧
    BatchAccepted s0 MergeCE.mlog ms ∧
    landBatch H (ms.map (toMember s0 MergeCE.mlog)) ≠ serialTxns H [m] ∧
    ¬ PatchCompatible (toMember s0 MergeCE.mlog ⟨m, 0⟩) H := by
  intro ms H
  have hH : H = cx.f s0 := msnap1
  have hv : validateAt MergeCE.mlog 1 m.R m.W 0 = .merge := by decide
  refine ⟨hv, rfl, ⟨?_, List.pairwise_singleton _ _⟩, ?_, ?_⟩
  · intro e he
    simp only [ms, List.mem_singleton] at he
    subst he
    refine MemberAccepted.of_merge (by decide) hv ?_
    rintro p ⟨h₁, h₂, -⟩
    rw [msnap0] at h₁ h₂
    rw [show mlog.length = 1 from rfl, msnap1] at h₁
    -- `m` changes only `y`, and the head did not move `y`
    by_cases hp : p = pY
    · subst hp; revert h₁; decide
    · apply h₂
      simp only [m, Txn.changeset, overlay, setAt, hp, ite_false]
      split <;> rfl
  · intro h
    have := congrFun h pX
    simp only [ms, List.map_cons, List.map_nil, toMember, hH, msnap0] at this
    revert this; decide
  · intro h
    have := h pX (by decide)
    simp only [toMember, hH, msnap0] at this
    revert this; decide

end YonedaTx
