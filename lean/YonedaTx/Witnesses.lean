import YonedaTx.Soundness
import YonedaTx.UnderDeclared

/-!
# Non-vacuity witnesses

Concrete, machine-checked instances whose premises hold, for the main positive
theorems:

* `line_merge_witness`: two edits to different lines of one file. Declared at file
  granularity, the second is a Merge whose file-level merge conflicts, but the
  line-granular merge is clean and keeps both edits (Part I, Proposition 6.5, at line
  granularity with stable line keys).
* `batch_witness`: a `BatchAccepted` batch on a non-empty log, with a Merge member that
  is patch-compatible, to which `batch_landing_sound` applies.
* `serializability_witness`, `frame_witness`, `under_declared_safe_witness`: non-empty
  logs with a landing whose base is below its own version.
-/

namespace YonedaTx

namespace Witnesses

/-- File `F`, its lines `F/1` and `F/2`, and a second file `G`. -/
def fF : Path := ["F"]
def fL1 : Path := ["F", "1"]
def fL2 : Path := ["F", "2"]
def gG : Path := ["G"]

/-- Version 0: `F/1 = 10`, `F/2 = 20`. -/
def s0 : State := fun p => if p = fL1 then some 10 else if p = fL2 then some 20 else none

theorem s0_ne_21 (p : Path) : s0 p ≠ some 21 := by
  unfold s0; split
  · simp
  · split <;> simp

theorem coarsens_F1 : Coarsens [fF] [fL1] := fun a ha => by
  simp only [List.mem_singleton] at ha; subst ha; exact ⟨fF, by simp, by decide⟩

theorem coarsens_F2 : Coarsens [fF] [fL2] := fun a ha => by
  simp only [List.mem_singleton] at ha; subst ha; exact ⟨fF, by simp, by decide⟩

/-- `c₀` edits line 1 of `F` (`F/1 := 11`) and declares the whole file. -/
def c0 : Txn := Txn.patch [] [fF] [fL1] (fun _ => some 11) coarsens_F1

/-- `m₁` edits line 2 of `F` (`F/2 := 21`) and declares the whole file. -/
def m1 : Txn := Txn.patch [] [fF] [fL2] (fun _ => some 21) coarsens_F2

/-- `m₂` increments file `G`, reading it. -/
def m2 : Txn := Txn.write1 [gG] gG (fun s => some ((s gG).getD 0 + 1))
  (fun s t h => by rw [h gG (by decide)])

/-- The preceding log: `c₀` lands as a fast-forward at version 1. -/
def log : Log := [⟨c0, 0⟩]

/-- The batch, in ticket order. Both members are built on version 0. -/
def ms : List Entry := [⟨m1, 0⟩, ⟨m2, 0⟩]

theorem snap0 : snap s0 log 0 = s0 := snap_zero _ _

theorem snap1 : snap s0 log 1 = c0.f s0 := by
  rw [snap_succ (e := ⟨c0, 0⟩) rfl (Nat.le_refl 0), snap_zero, landOn_self]

/-- The file-level merge of `m₁` with the head has no conflict path: `c₀` and `m₁` change
disjoint lines. -/
theorem m1_no_conflict (p : Path) : ¬ ConflictAt s0 (c0.f s0) (m1.f s0) p := fun h =>
  merge_no_conflict_of_disjoint (Txn.patch_changesWithin s0) (Txn.patch_changesWithin s0)
    (by decide : meetsSet [fL1] [fL2] = false) p ((merge3_conflict_iff _ _ _ _).2 h)

/-- **Line-level merge witness.** Declared at file granularity, `m₁` is validated as a
Merge against `c₀`, and the file-granular merge of `F` conflicts: both sides changed `F`,
to different contents. Declared at line granularity, the same pair would be a Rebase.
At line granularity the merge has no conflict path, `line_merge_refines` applies, and the
landed file keeps both edits: `F/1 = 11` and `F/2 = 21`. -/
theorem line_merge_witness :
    let H := snap s0 log 1
    let C := m1.f s0
    validateAt log 1 m1.R m1.W 0 = .merge ∧
    validate [[fL1]] [] [fL2] = .rebase ∧
    FileConflict s0 H C fF ∧
    (∀ p, ¬ ConflictAt s0 H C p) ∧
    (∀ ℓ, lines H fF ℓ = lines s0 fF ℓ ∨ lines C fF ℓ = lines s0 fF ℓ) ∧
    landOn s0 H C fL1 = some 11 ∧ landOn s0 H C fL2 = some 21 := by
  intro H C
  have hH : H = c0.f s0 := snap1
  refine ⟨by decide, by decide, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hH]
    refine ⟨fun h => ?_, fun h => ?_, fun h => ?_⟩
    · have := congrFun h "1"; revert this; decide
    · have := congrFun h "2"; revert this; decide
    · have := congrFun h "1"; revert this; decide
  · rw [hH]; exact m1_no_conflict
  · intro ℓ
    rw [hH]
    simp only [lines]
    cases hc : covered [fL1] (fF ++ [ℓ])
    · exact Or.inl (Txn.patch_changesWithin s0 _ hc)
    · exact Or.inr (Txn.patch_changesWithin s0 _
        (not_covered_of_disjoint (by decide : meetsSet [fL2] [fL1] = false) hc))
  · rw [hH]; decide
  · rw [hH]; decide

theorem log_noConflict : NoConflict log := by
  intro i e he
  rcases i with _ | i
  · simp only [log, List.getElem?_cons_zero, Option.some.injEq] at he
    subst he; exact ⟨Nat.le_refl 0, by decide⟩
  · simp [log] at he

theorem ms_accepted : BatchAccepted s0 log ms := by
  refine ⟨fun e he => ?_, ?_⟩
  · simp only [ms, List.mem_cons, List.not_mem_nil, or_false] at he
    rcases he with rfl | rfl
    · refine MemberAccepted.of_merge (by decide) (by decide) ?_
      rw [snap0]
      show ∀ p, ¬ ConflictAt s0 (snap s0 log 1) (m1.f s0) p
      rw [snap1]; exact m1_no_conflict
    · exact MemberAccepted.of_clean (by decide) (by decide)
  · refine List.Pairwise.cons (fun a ha => ?_) (List.Pairwise.cons (fun _ h => by cases h)
      List.Pairwise.nil)
    simp only [List.mem_singleton] at ha
    subst ha
    show meetsSet (m2.R ++ m2.W) m1.W = false
    decide

/-- **Batch witness.** A non-empty preceding log, and an accepted batch whose first member
is a Merge (patch-compatible with the head) and whose second is a Rebase.
`batch_landing_sound` applies. Both edits to `F` and the increment of `G` survive. -/
theorem batch_witness :
    let H := snap s0 log 1
    log ≠ [] ∧ NoConflict log ∧ BatchAccepted s0 log ms ∧
    validateAt log 1 m1.R m1.W 0 = .merge ∧
    PatchCompatible (toMember s0 log ⟨m1, 0⟩) H ∧
    landBatch H (ms.map (toMember s0 log)) = serialTxns H [m1, m2] ∧
    serialTxns H [m1, m2] fL1 = some 11 ∧ serialTxns H [m1, m2] fL2 = some 21 ∧
    serialTxns H [m1, m2] gG = some 1 := by
  intro H
  have hH : H = c0.f s0 := snap1
  have hpc : PatchCompatible (toMember s0 log ⟨m1, 0⟩) H := by
    show PatchCompatible ⟨m1, snap s0 log 0⟩ H
    rw [snap0]
    exact patch_patchCompatible_iff.2 fun p _ hΦ => absurd hΦ.symm (s0_ne_21 p)
  have hsound := batch_landing_sound log_noConflict ms_accepted (fun e he hm => by
    simp only [ms, List.mem_cons, List.not_mem_nil, or_false] at he
    rcases he with rfl | rfl
    · exact hpc
    · exact absurd hm (by decide))
  refine ⟨by simp [log], log_noConflict, ms_accepted, by decide, hpc, hsound.1, ?_, ?_, ?_⟩
  all_goals rw [hH]; decide

/-! ## Serializability, frame and under-declared witnesses -/

/-- A log of two entries: `c₀` (fast-forward), then `m₂` built on version 0 and landed at
version 2 (a Rebase, base below its version). -/
def log2 : Log := [⟨c0, 0⟩, ⟨m2, 0⟩]

theorem log2_validated : Validated log2 := by
  intro i e he
  rcases i with _ | _ | i
  · simp only [log2, List.getElem?_cons_zero, Option.some.injEq] at he
    subst he; exact ⟨Nat.le_refl 0, by decide⟩
  · simp only [log2, List.getElem?_cons_succ, List.getElem?_cons_zero,
      Option.some.injEq] at he
    subst he; exact ⟨Nat.zero_le 1, by decide⟩
  · simp [log2] at he

/-- **Serializability witness.** `log2` is validated, and `serializability` gives its final
state as serial execution; the base of `m₂` (version 0) is below its version. -/
theorem serializability_witness :
    Validated log2 ∧ validateAt log2 1 m2.R m2.W 0 = .rebase ∧
    snap s0 log2 2 = serial s0 log2 2 ∧ serial s0 log2 2 gG = some 1 ∧
    serial s0 log2 2 fL1 = some 11 :=
  ⟨log2_validated, by decide, (serializability log2_validated).1 2, by decide, by decide⟩

/-- **Frame witness**, with `b = 0 < v = 1`: between versions 0 and 1 the file `F`
changes, but `G` meets no write set in between, so the snapshots agree on `G`. -/
theorem frame_witness :
    snap s0 log2 1 fL1 ≠ snap s0 log2 0 fL1 ∧ Agree [gG] (snap s0 log2 0) (snap s0 log2 1) := by
  refine ⟨?_, ?_⟩
  · rw [snap_succ (e := ⟨c0, 0⟩) rfl (Nat.le_refl 0), snap_zero, landOn_self]; decide
  · apply frame_lemma (Nat.zero_le 1)
    intro i e _ hi he
    have : i = 0 := by omega
    subst this
    simp only [log2, List.getElem?_cons_zero, Option.some.injEq] at he
    subst he; decide

/-- **Under-declared safe witness.** `m₂` truly reads `G` but declares nothing; the
undeclared read meets no write landed after its base (`c₀` writes `F`), so
`under_declared_safe` applies to `log2`. -/
theorem under_declared_safe_witness :
    ValidatedDecl log2 (fun _ => []) ∧ undeclared m2.R [] = [gG] ∧
    snap s0 log2 2 = serial s0 log2 2 := by
  have hv : ValidatedDecl log2 (fun _ => []) := by
    intro i e he
    rcases i with _ | _ | i
    · simp only [log2, List.getElem?_cons_zero, Option.some.injEq] at he
      subst he; exact ⟨Nat.le_refl 0, by decide⟩
    · simp only [log2, List.getElem?_cons_succ, List.getElem?_cons_zero,
        Option.some.injEq] at he
      subst he; exact ⟨Nat.zero_le 1, by decide⟩
    · simp [log2] at he
  refine ⟨hv, by decide, (under_declared_safe hv fun i e he W hW => ?_).1 2⟩
  rcases i with _ | _ | i
  · simp only [log2, List.getElem?_cons_zero, Option.some.injEq] at he
    subst he; simp [laterWrites] at hW
  · simp only [log2, List.getElem?_cons_succ, List.getElem?_cons_zero,
      Option.some.injEq] at he
    subst he
    have : laterWrites log2 0 1 = [c0.W] := rfl
    rw [show (⟨m2, 0⟩ : Entry).base = 0 from rfl, this, List.mem_singleton] at hW
    subst hW; decide
  · simp [log2] at he

end Witnesses

end YonedaTx
