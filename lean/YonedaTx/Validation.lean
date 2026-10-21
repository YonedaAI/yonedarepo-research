import YonedaTx.Log

/-!
# Validation

Part I, Definition 4.15 (proposal and validation) on one ref at one granularity, and
Proposition 6.10 (coarsening is sound).
-/

namespace YonedaTx

/-- The four outcomes of validation. -/
inductive Outcome where
  | conflict
  | merge
  | rebase
  | fastForward
  deriving DecidableEq, Repr

/-- Validation of a proposal with read set `R` and write set `W` against the write sets
`later` of the entries after its base (Definition 4.15): Conflict if `R` meets a later
write; otherwise FastForward if there are no later entries; otherwise Rebase if `W`
meets no later write; otherwise Merge. -/
def validate (later : List Access) (R W : Access) : Outcome :=
  if later.any (fun Wv => meetsSet R Wv) then .conflict
  else if later.isEmpty then .fastForward
  else if later.any (fun Wv => meetsSet W Wv) then .merge
  else .rebase

/-- Validation of a proposal with base `b` against the log at head version `n`. -/
def validateAt (log : Log) (n : Nat) (R W : Access) (b : Nat) : Outcome :=
  validate (laterWrites log b n) R W

/-- The outcomes under which Theorem 6.4 claims serializability. -/
def Outcome.clean : Outcome → Bool
  | .fastForward | .rebase => true
  | _ => false

theorem validate_eq_conflict_iff {later : List Access} {R W : Access} :
    validate later R W = .conflict ↔ ∃ Wv ∈ later, meetsSet R Wv = true := by
  unfold validate
  by_cases h : later.any (fun Wv => meetsSet R Wv) = true
  · simp only [h, ite_true]; simpa [List.any_eq_true] using h
  · simp only [h]; simp only [Bool.not_eq_true] at h
    simp only [Bool.false_eq_true, ite_false]
    constructor
    · intro h'; split at h' <;> (try split at h') <;> cases h'
    · intro ⟨Wv, hm, hr⟩
      have := List.any_eq_true.2 ⟨Wv, hm, hr⟩
      rw [h] at this; cases this

theorem no_stale_read {later : List Access} {R W : Access} (h : validate later R W ≠ .conflict) :
    ∀ Wv ∈ later, meetsSet R Wv = false := by
  intro Wv hm
  cases hr : meetsSet R Wv
  · rfl
  · exact absurd (validate_eq_conflict_iff.2 ⟨Wv, hm, hr⟩) h

theorem no_write_overlap {later : List Access} {R W : Access}
    (h : (validate later R W).clean = true) : ∀ Wv ∈ later, meetsSet W Wv = false := by
  intro Wv hm
  cases hw : meetsSet W Wv
  · rfl
  · exfalso
    have hany : later.any (fun Wv => meetsSet W Wv) = true := List.any_eq_true.2 ⟨Wv, hm, hw⟩
    have hne : later.isEmpty = false := by cases later <;> simp_all
    revert h; unfold validate
    split
    · simp [Outcome.clean]
    · simp [hne, Outcome.clean]

/-- A clean outcome means that neither `R` nor `W` meets any later write. -/
theorem clean_disjoint {later : List Access} {R W : Access}
    (h : (validate later R W).clean = true) : ∀ Wv ∈ later, meetsSet (R ++ W) Wv = false := by
  have hc : validate later R W ≠ .conflict := by intro e; rw [e] at h; cases h
  intro Wv hm
  simp [no_stale_read hc Wv hm, no_write_overlap h Wv hm]

/-- Rebase, characterized. -/
theorem validate_eq_rebase_iff {later : List Access} {R W : Access} :
    validate later R W = .rebase ↔
      later ≠ [] ∧ ∀ Wv ∈ later, meetsSet R Wv = false ∧ meetsSet W Wv = false := by
  unfold validate
  cases later with
  | nil => simp
  | cons W₀ rest =>
    simp only [List.any_cons, List.isEmpty_cons, ne_eq, reduceCtorEq, not_false_eq_true,
      List.mem_cons, forall_eq_or_imp, true_and]
    by_cases h₁ : (meetsSet R W₀ || rest.any fun Wv => meetsSet R Wv) = true
    · simp only [h₁, ite_true]
      simp only [Bool.or_eq_true, List.any_eq_true] at h₁
      constructor
      · intro h; cases h
      · rintro ⟨⟨hR, -⟩, hrest⟩
        rcases h₁ with h₁ | ⟨Wv, hm, hv⟩
        · rw [hR] at h₁; cases h₁
        · rw [(hrest Wv hm).1] at hv; cases hv
    · simp only [Bool.not_eq_true] at h₁
      simp only [h₁, Bool.false_eq_true, ite_false]
      simp only [Bool.or_eq_false_iff, List.any_eq_false] at h₁
      by_cases h₂ : (meetsSet W W₀ || rest.any fun Wv => meetsSet W Wv) = true
      · simp only [h₂, ite_true]
        simp only [Bool.or_eq_true, List.any_eq_true] at h₂
        constructor
        · intro h; cases h
        · rintro ⟨⟨-, hW⟩, hrest⟩
          rcases h₂ with h₂ | ⟨Wv, hm, hv⟩
          · rw [hW] at h₂; cases h₂
          · rw [(hrest Wv hm).2] at hv; cases hv
      · simp only [Bool.not_eq_true] at h₂
        simp only [h₂, Bool.false_eq_true, ite_false, true_iff]
        simp only [Bool.or_eq_false_iff, List.any_eq_false] at h₂
        refine ⟨⟨h₁.1, h₂.1⟩, fun Wv hm => ⟨?_, ?_⟩⟩
        · have := h₁.2 Wv hm; simpa using this
        · have := h₂.2 Wv hm; simpa using this

theorem validate_nil (R W : Access) : validate [] R W = .fastForward := rfl

/-! ## Validated logs -/

/-- A log in which every entry was validated, at its landing, against the log before it,
and the outcome was not a Conflict (the authority refuses those). -/
def NoConflict (log : Log) : Prop :=
  ∀ i e, log[i]? = some e →
    e.base ≤ i ∧ validateAt log i e.txn.R e.txn.W e.base ≠ .conflict

/-- A log in which every landing was validated FastForward or Rebase (no Conflict, no
Merge): the hypothesis of the serializability statement of Theorem 6.4. -/
def Validated (log : Log) : Prop :=
  ∀ i e, log[i]? = some e →
    e.base ≤ i ∧ (validateAt log i e.txn.R e.txn.W e.base).clean = true

theorem Validated.noConflict {log : Log} (h : Validated log) : NoConflict log := by
  intro i e he
  obtain ⟨hb, hc⟩ := h i e he
  exact ⟨hb, fun e' => by rw [e'] at hc; cases hc⟩

/-! ## Proposition 6.10: coarsening is sound -/

/-- Pointwise coarsening of a list of write sets. -/
inductive CoarsensAll : List Access → List Access → Prop where
  | nil : CoarsensAll [] []
  | cons {W' W : Access} {l' l : List Access} :
      Coarsens W' W → CoarsensAll l' l → CoarsensAll (W' :: l') (W :: l)

theorem CoarsensAll.exists {l' l : List Access} (h : CoarsensAll l' l) {W : Access}
    (hW : W ∈ l) : ∃ W' ∈ l', Coarsens W' W := by
  induction h with
  | nil => cases hW
  | cons hc _ ih =>
    rcases List.mem_cons.1 hW with rfl | hW
    · exact ⟨_, List.mem_cons_self, hc⟩
    · obtain ⟨W', hm, h⟩ := ih hW; exact ⟨W', List.mem_cons_of_mem _ hm, h⟩

theorem CoarsensAll.isEmpty_eq {l' l : List Access} (h : CoarsensAll l' l) :
    l'.isEmpty = l.isEmpty := by
  cases h <;> rfl

theorem any_meets_coarsen {X X' : Access} {l l' : List Access} (hX : Coarsens X' X)
    (hl : CoarsensAll l' l) (h : l.any (fun Wv => meetsSet X Wv) = true) :
    l'.any (fun Wv => meetsSet X' Wv) = true := by
  obtain ⟨W, hm, hW⟩ := List.any_eq_true.1 h
  obtain ⟨W', hm', hc⟩ := hl.exists hm
  exact List.any_eq_true.2 ⟨W', hm', meetsSet_coarsen hX hc hW⟩

/-- Proposition 6.10 (coarsening is sound), validation part. Coarsening the read set,
the write set and the later write sets keeps every Conflict a Conflict, and every Merge
a Merge or a Conflict. -/
theorem coarsening_sound {R R' W W' : Access} {later later' : List Access}
    (hR : Coarsens R' R) (hW : Coarsens W' W) (hl : CoarsensAll later' later) :
    (validate later R W = .conflict → validate later' R' W' = .conflict) ∧
    (validate later R W = .merge →
      validate later' R' W' = .conflict ∨ validate later' R' W' = .merge) := by
  constructor
  · intro h
    obtain ⟨Wv, hm, hr⟩ := validate_eq_conflict_iff.1 h
    obtain ⟨Wv', hm', hc⟩ := hl.exists hm
    exact validate_eq_conflict_iff.2 ⟨Wv', hm', meetsSet_coarsen hR hc hr⟩
  · intro h
    unfold validate at h ⊢
    by_cases h₁ : later'.any (fun Wv => meetsSet R' Wv) = true
    · simp [h₁]
    · right
      simp only [h₁, Bool.false_eq_true, ite_false, hl.isEmpty_eq]
      split at h
      · cases h
      · split at h
        · cases h
        · next h₂ h₃ =>
          split at h
          · next h₄ =>
            simp only [h₃, Bool.false_eq_true, ite_false, any_meets_coarsen hW hl h₄, ite_true]
          · cases h

/-- Proposition 6.10: the write-set frame (Assumption 6.2) survives coarsening. -/
theorem coarsening_preserves_frame {W W' : Access} {s t : State} (hW : Coarsens W' W)
    (h : ChangesWithin W s t) : ChangesWithin W' s t :=
  h.coarsen hW

/-! ## Independence (Part I, Definition 4.7) -/

/-- Eq. 1: `W_i ⋈̸ (R_j ∪ W_j)` and `W_j ⋈̸ (R_i ∪ W_i)`. -/
def Independent (Ri Wi Rj Wj : Access) : Prop :=
  meetsSet Wi (Rj ++ Wj) = false ∧ meetsSet Wj (Ri ++ Wi) = false

/-- Proposition 6.10: a pair independent after coarsening was independent before. -/
theorem independent_of_coarsened {Ri Wi Rj Wj Ri' Wi' Rj' Wj' : Access}
    (hRi : Coarsens Ri' Ri) (hWi : Coarsens Wi' Wi) (hRj : Coarsens Rj' Rj)
    (hWj : Coarsens Wj' Wj) (h : Independent Ri' Wi' Rj' Wj') : Independent Ri Wi Rj Wj := by
  constructor
  · cases hm : meetsSet Wi (Rj ++ Wj)
    · rfl
    · have := meetsSet_coarsen hWi (hRj.append hWj) hm
      rw [h.1] at this; cases this
  · cases hm : meetsSet Wj (Ri ++ Wi)
    · rfl
    · have := meetsSet_coarsen hWj (hRi.append hWi) hm
      rw [h.2] at this; cases this

/-- Theorem 6.7, validation part: Eq. 1 holds iff, in both landing orders, the second
change is validated Rebase against the single entry of the first. -/
theorem independence_iff_rebase (Ri Wi Rj Wj : Access) :
    Independent Ri Wi Rj Wj ↔ validate [Wi] Rj Wj = .rebase ∧ validate [Wj] Ri Wi = .rebase := by
  have e₁ : meetsSet Wi (Rj ++ Wj) = (meetsSet Rj Wi || meetsSet Wj Wi) := by
    rw [meetsSet_symm, meetsSet_append_left]
  have e₂ : meetsSet Wj (Ri ++ Wi) = (meetsSet Ri Wj || meetsSet Wi Wj) := by
    rw [meetsSet_symm, meetsSet_append_left]
  simp only [validate_eq_rebase_iff, ne_eq, reduceCtorEq, not_false_eq_true, List.mem_singleton,
    forall_eq, true_and, Independent, e₁, e₂, Bool.or_eq_false_iff]

end YonedaTx
