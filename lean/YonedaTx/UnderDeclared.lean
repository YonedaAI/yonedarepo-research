import YonedaTx.Batch

/-!
# Under-declared reads

What survives when a writer declares fewer reads than it makes. A transaction's own
`R` field is its *true* read set `R*`. Validation uses separately *declared* read sets
`D i`, one per entry, which may miss part of `R*`.

* `under_declared_no_lost_update`: no landed write is lost. The file-level write check
  alone guarantees it; no read set is involved.
* `under_declared_counterexample`: serializability can fail.
* `under_declared_safe`: if the undeclared part `R* ∖ D` meets no write landed after
  the base, serializability holds.
* `under_declared_tight`: the condition cannot be weakened in general. Whenever an
  undeclared read meets an intervening write (and the landing is otherwise accepted as a
  Rebase), some transactions with exactly those read and write sets give a state equal
  to no serial order.
-/

namespace YonedaTx

variable {init : State} {log : Log}

/-- Declared read sets, indexed by the entry's position in the log. -/
abbrev Declared := Nat → Access

/-- Every landing validated FastForward or Rebase against its declared read set. -/
def ValidatedDecl (log : Log) (D : Declared) : Prop :=
  ∀ i e, log[i]? = some e → e.base ≤ i ∧ (validateAt log i (D i) e.txn.W e.base).clean = true

/-- The file-level write check: every landing's three-way merge with the head has no
conflict path. Read sets play no part. -/
def WriteChecked (init : State) (log : Log) : Prop :=
  ∀ j e, log[j]? = some e → e.base ≤ j ∧
    ∀ p, ¬ ConflictAt (snap init log e.base) (snap init log j) (e.txn.f (snap init log e.base)) p

/-- The undeclared part `R* ∖ R` of a true read set. -/
def undeclared (Rstar R : Access) : Access := Rstar.filter fun x => decide (x ∉ R)

/-- Validation with any declared read sets passes the write check. -/
theorem ValidatedDecl.writeChecked {D : Declared} (hv : ValidatedDecl log D) :
    WriteChecked init log := fun j e he =>
  ⟨(hv j e he).1, no_conflict_path_of_clean (hv j e he).1 (hv j e he).2⟩

/-- Under the write check, a landing changes the head at `p` only if it writes `p` and
its base held the head's current value at `p`, that is, it overwrote what it had seen. -/
theorem change_seen (hw : WriteChecked init log) {j : Nat} {e : Entry} (he : log[j]? = some e)
    {p : Path} (hch : snap init log (j + 1) p ≠ snap init log j p) :
    covered e.txn.W p = true ∧ snap init log e.base p = snap init log j p := by
  obtain ⟨hb, hnc⟩ := hw j e he
  rw [snap_succ he hb] at hch
  -- the change moved `p`, so `p` is written
  have hCB : e.txn.f (snap init log e.base) p ≠ snap init log e.base p :=
    fun h => hch (landOn_of_unchanged h)
  refine ⟨?_, ?_⟩
  · cases hcov : covered e.txn.W p
    · exact absurd (e.txn.frame _ p hcov) hCB
    · rfl
  · -- if the head had moved away from the base at `p`, the merge would keep the head
    -- (both sides equal) or report a conflict
    apply Decidable.byContradiction
    intro hHB
    have hHC : snap init log j p = e.txn.f (snap init log e.base) p :=
      Decidable.byContradiction fun h => hnc p ⟨fun h' => hHB h'.symm, hCB, h⟩
    apply hch
    simp [landOn, merge3, merge3Cell, Cell.getD, hCB, hHC]

/-- **No lost update under under-declared reads.** With only the file-level write check,
the content of `p` at version `i` is still there at every later version `v`, unless
some landing in between wrote `p` from a base that held the then-current value of `p`. -/
theorem under_declared_no_lost_update (hw : WriteChecked init log) {i : Nat} {p : Path} :
    ∀ v, i ≤ v → snap init log v p = snap init log i p ∨
      ∃ j e, i ≤ j ∧ j < v ∧ log[j]? = some e ∧ covered e.txn.W p = true ∧
        snap init log e.base p = snap init log j p ∧
        snap init log (j + 1) p ≠ snap init log j p := by
  intro v hiv
  induction v with
  | zero => left; rw [Nat.le_zero.1 hiv]
  | succ v ih =>
    rcases Nat.lt_or_ge v i with hvi | hvi
    · left; have : i = v + 1 := by omega
      rw [this]
    · rcases ih hvi with h | ⟨j, e, hij, hjv, rest⟩
      · by_cases hstep : snap init log (v + 1) p = snap init log v p
        · exact Or.inl (hstep.trans h)
        · right
          cases he : log[v]? with
          | none => exact absurd (by rw [snap_succ_none he]) hstep
          | some e =>
            obtain ⟨hcov, hseen⟩ := change_seen hw he hstep
            exact ⟨v, e, hvi, by omega, he, hcov, hseen, hstep⟩
      · exact Or.inr ⟨j, e, hij, by omega, rest⟩

/-- **Sufficient condition.** If, for every entry, the undeclared part of its true read set
meets no write set landed after its base, the serializability theorem holds: every
snapshot is serial execution in log order, and each transaction's true reads at its base
equal its reads in that order. -/
theorem under_declared_safe {D : Declared} (hv : ValidatedDecl log D)
    (hsafe : ∀ i e, log[i]? = some e →
      ∀ W ∈ laterWrites log e.base i, meetsSet (undeclared e.txn.R (D i)) W = false) :
    (∀ n, snap init log n = serial init log n) ∧
    (∀ i e, log[i]? = some e → Agree e.txn.R (snap init log e.base) (serial init log i)) := by
  apply serializability_of_laterDisjoint
  intro i e he
  obtain ⟨hb, hc⟩ := hv i e he
  refine ⟨hb, fun W hW => ?_⟩
  have hdecl := clean_disjoint hc W hW
  rw [meetsSet_append_left, Bool.or_eq_false_iff] at hdecl ⊢
  refine ⟨?_, hdecl.2⟩
  -- a true read either was declared (validation) or is undeclared (`hsafe`)
  cases hm : meetsSet e.txn.R W
  · rfl
  · obtain ⟨x, hx, y, hy, hxy⟩ := meetsSet_iff.1 hm
    by_cases hxD : x ∈ D i
    · have := hdecl.1
      rw [meetsSet_iff.2 ⟨x, hxD, y, hy, hxy⟩] at this; cases this
    · have hu : x ∈ undeclared e.txn.R (D i) := List.mem_filter.2 ⟨hx, by simp [hxD]⟩
      have := hsafe i e he W hW
      rw [meetsSet_iff.2 ⟨x, hu, y, hy, hxy⟩] at this; cases this

namespace UnderDeclared

open WriteSkew

/-- `c_b` (reads `y`, writes `x := y + 1`) lands first, then `c_a` (truly reads `x`,
writes `y := x + 1`), both built on version 0. -/
def ulog : Log := [⟨cb, 0⟩, ⟨ca, 0⟩]

/-- `c_b` declares its read of `y`; `c_a` declares no reads. -/
def D : Declared := fun i => if i = 0 then [pY] else []

theorem snap2 : snap s0 ulog 2 = landOn s0 (cb.f s0) (ca.f s0) := by
  have h1 : snap s0 ulog 1 = cb.f s0 := by
    rw [snap_succ (e := ⟨cb, 0⟩) rfl (Nat.le_refl 0), snap_zero, landOn_self]
  rw [snap_succ (e := ⟨ca, 0⟩) rfl (Nat.zero_le 1), snap_zero, h1]

end UnderDeclared

open WriteSkew UnderDeclared in
/-- **Serializability can fail under under-declared reads.** In `ulog`, `c_a` reads `x`
without declaring it, and `x` is written in between by `c_b`. Validation against the
declared sets accepts both landings, and the write check passes. The undeclared read
meets the intervening write, and the final state equals neither serial order. With its
true read set, `c_a` would have been refused as a Conflict. -/
theorem under_declared_counterexample :
    ValidatedDecl ulog D ∧ WriteChecked s0 ulog ∧
    meetsSet (undeclared ca.R (D 1)) cb.W = true ∧
    snap s0 ulog 2 ≠ serialTxns s0 [cb, ca] ∧
    snap s0 ulog 2 ≠ serialTxns s0 [ca, cb] ∧
    validateAt ulog 1 ca.R ca.W 0 = .conflict := by
  have hv : ValidatedDecl ulog D := by
    intro i e he
    rcases i with _ | _ | i
    · simp only [ulog, List.getElem?_cons_zero, Option.some.injEq] at he
      subst he; exact ⟨Nat.le_refl 0, by decide⟩
    · simp only [ulog, List.getElem?_cons_succ, List.getElem?_cons_zero,
        Option.some.injEq] at he
      subst he; exact ⟨Nat.zero_le 1, by decide⟩
    · simp [ulog] at he
  refine ⟨hv, hv.writeChecked, by decide, ?_, ?_, by decide⟩
  · intro h
    have := congrFun h pY
    rw [snap2] at this
    revert this; decide
  · intro h
    have := congrFun h pX
    rw [snap2] at this
    revert this; decide

/-- The empty tree. -/
def emptyState : State := fun _ => none

/-- **Tightness of `under_declared_safe`.** Let the undeclared part of a true read set
`R*` meet the write set `Wᵢ` of an intervening landing, while the declared set `D` and
the write set `Wⱼ ≠ []` do not meet `Wᵢ`, so the landing is accepted as a Rebase. Then
there are transactions `cᵢ` (writing `Wᵢ`) and `cⱼ` (true reads `R*`, writes `Wⱼ`),
both built on version 0 and landed in that order, whose final state equals neither
serial order. -/
theorem under_declared_tight {Rstar D Wi Wj : Access}
    (hmeet : meetsSet (undeclared Rstar D) Wi = true)
    (hD : meetsSet D Wi = false) (hW : meetsSet Wj Wi = false) (hne : Wj ≠ []) :
    ∃ ci cj : Txn, ci.W = Wi ∧ cj.R = Rstar ∧ cj.W = Wj ∧
      ValidatedDecl [⟨ci, 0⟩, ⟨cj, 0⟩] (fun i => if i = 0 then [] else D) ∧
      snap emptyState [⟨ci, 0⟩, ⟨cj, 0⟩] 2 ≠ serialTxns emptyState [ci, cj] ∧
      snap emptyState [⟨ci, 0⟩, ⟨cj, 0⟩] 2 ≠ serialTxns emptyState [cj, ci] := by
  -- `p`: a location written by `cᵢ` and truly read by `cⱼ`
  obtain ⟨x, hx, w, hw, hxw⟩ := meetsSet_iff.1 hmeet
  have hxR : x ∈ Rstar := (List.mem_filter.1 hx).1
  obtain ⟨p, hpW, hpR⟩ : ∃ p, covered Wi p = true ∧ region Rstar p = true := by
    rcases meets_iff.1 hxw with h | h
    · exact ⟨w, covered_iff.2 ⟨w, hw, anc_refl w⟩, region_iff.2 ⟨x, hxR, meets_of_anc h⟩⟩
    · exact ⟨x, covered_iff.2 ⟨w, hw, h⟩, region_iff.2 ⟨x, hxR, overlap_refl x⟩⟩
  -- `q`: a location written by `cⱼ`
  obtain ⟨q, qs, rfl⟩ : ∃ q qs, Wj = q :: qs := by
    cases Wj with
    | nil => exact absurd rfl hne
    | cons q qs => exact ⟨q, qs, rfl⟩
  have hqW : covered (q :: qs) q = true := covered_iff.2 ⟨q, List.mem_cons_self, anc_refl q⟩
  -- `cᵢ : p := q + 1` and `cⱼ : q := p + 1`
  let ci := Txn.assign [q] Wi p hpW (fun s => some ((s q).getD 0 + 1))
    (fun s t h => by rw [h q (region_iff.2 ⟨q, List.mem_cons_self, overlap_refl q⟩)])
  let cj := Txn.assign Rstar (q :: qs) q hqW (fun s => some ((s p).getD 0 + 1))
    (fun s t h => by rw [h p hpR])
  let log : Log := [⟨ci, 0⟩, ⟨cj, 0⟩]
  have hlater : laterWrites log 0 1 = [Wi] := rfl
  have hv : ValidatedDecl log (fun i => if i = 0 then [] else D) := by
    intro i e he
    rcases i with _ | _ | i
    · simp only [log, List.getElem?_cons_zero, Option.some.injEq] at he
      subst he; exact ⟨Nat.le_refl 0, rfl⟩
    · simp only [log, List.getElem?_cons_succ, List.getElem?_cons_zero,
        Option.some.injEq] at he
      subst he
      refine ⟨Nat.zero_le 1, ?_⟩
      have : validate [Wi] D (q :: qs) = .rebase :=
        validate_eq_rebase_iff.2 ⟨by simp, by simp [hD, hW]⟩
      show (validate (laterWrites log 0 1) D (q :: qs)).clean = true
      rw [hlater, this]; rfl
    · simp [log] at he
  have s1 : snap emptyState log 1 = ci.f emptyState := by
    rw [snap_succ (e := ⟨ci, 0⟩) rfl (Nat.le_refl 0), snap_zero, landOn_self]
  have s2 : snap emptyState log 2 = landOn emptyState (ci.f emptyState) (cj.f emptyState) := by
    rw [snap_succ (e := ⟨cj, 0⟩) rfl (Nat.zero_le 1), snap_zero, s1]
  -- the landed state: `p = 1` and `q = 1`
  have hland : ∀ r, landOn emptyState (ci.f emptyState) (cj.f emptyState) r =
      if covered (q :: qs) r = true then cj.f emptyState r else ci.f emptyState r :=
    landOn_rebase (cj.changesWithin _) fun r hr =>
      ci.frame _ r (not_covered_of_disjoint (by rw [meetsSet_symm]; exact hW) hr)
  have hpq' : covered (q :: qs) p = false := not_covered_of_disjoint hW hpW
  refine ⟨ci, cj, rfl, rfl, rfl, hv, ?_, ?_⟩
  · -- serial `cᵢ; cⱼ` gives `q = 2`
    intro h
    have := congrFun h q
    rw [s2, hland q, hqW] at this
    simp [ci, cj, Txn.assign, serialTxns, setAt, emptyState] at this
  · -- serial `cⱼ; cᵢ` gives `p = 2`
    intro h
    have := congrFun h p
    rw [s2, hland p, hpq'] at this
    simp [ci, cj, Txn.assign, serialTxns, setAt, emptyState] at this

end YonedaTx
