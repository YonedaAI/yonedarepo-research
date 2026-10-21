import YonedaTx.State

/-!
# File-level three-way merge

Part I, Proposition 6.5 (merged writes) and the three-way merge used in part 3 of
Theorem 6.4. The merge works per location: a location is either taken whole from one
side or is a conflict. Lines are modelled as sub-locations `f/ℓ` with stable keys
(`line_merge_refines` below), so different edits to one file merge cleanly at
line granularity. Positional `diff3` (insertions that shift line numbers, hunk
alignment) is not modelled (see the README).
-/

namespace YonedaTx

/-- The result of merging one location: a value, or a conflict. -/
inductive Cell (α : Type) where
  | ok (v : α)
  | conflict
  deriving DecidableEq, Repr

/-- The value of a cell, with a fallback for a conflict. -/
def Cell.getD {α : Type} : Cell α → α → α
  | .ok v, _ => v
  | .conflict, d => d

section
variable {α : Type} [DecidableEq α]

/-- Three-way merge of one location: take the side that differs from the base. Both
sides changed to the same value is not a conflict (as in `diff3` and Git). -/
def merge3Cell (b o t : α) : Cell α :=
  if o = b then .ok t else if t = b then .ok o else if o = t then .ok o else .conflict

theorem merge3Cell_eq_conflict_iff (b o t : α) :
    merge3Cell b o t = .conflict ↔ o ≠ b ∧ t ≠ b ∧ o ≠ t := by
  unfold merge3Cell
  by_cases h1 : o = b <;> by_cases h2 : t = b <;> by_cases h3 : o = t <;> simp [h1, h2, h3]

theorem merge3Cell_comm (b o t : α) : merge3Cell b o t = merge3Cell b t o := by
  unfold merge3Cell
  by_cases h1 : o = b <;> by_cases h2 : t = b
  · subst h1; subst h2; simp
  · simp [h1, h2]
  · simp [h1, h2]
  · by_cases h3 : o = t
    · subst h3; simp
    · have h4 : ¬t = o := fun h => h3 h.symm
      simp [h1, h2, h3, h4]

theorem merge3Cell_base_left (b t : α) : merge3Cell b b t = .ok t := by simp [merge3Cell]

theorem merge3Cell_base_right (b o : α) : merge3Cell b o b = .ok o := by
  unfold merge3Cell; by_cases h : o = b <;> simp [h]

theorem merge3Cell_same (b x : α) : merge3Cell b x x = .ok x := by
  unfold merge3Cell; by_cases h : x = b <;> simp [h]

end

/-- Three-way merge of tree states, location by location: `base`, `ours`, `theirs`. -/
def merge3 (b o t : State) (p : Path) : Cell (Option Blob) := merge3Cell (b p) (o p) (t p)

/-- A conflict path: changed on both sides, to different values. -/
def ConflictAt (b o t : State) (p : Path) : Prop := o p ≠ b p ∧ t p ≠ b p ∧ o p ≠ t p

/-- The merged state, with conflicting locations resolved to `ours`. Only used where
there is no conflict. -/
def merge3State (b o t : State) : State := fun p => (merge3 b o t p).getD (o p)

/-- The merge specification of Proposition 6.5: `m` agrees with `ours` where ours
changed, with `theirs` where theirs changed, and with the base elsewhere. -/
def MergeSpec (b o t m : State) : Prop :=
  ∀ p, (o p ≠ b p → m p = o p) ∧ (t p ≠ b p → m p = t p) ∧
    (o p = b p → t p = b p → m p = b p)

/-- Conflict characterization: the merge has a conflict at `p` iff `p` is changed on
both sides to different values. -/
theorem merge3_conflict_iff (b o t : State) (p : Path) :
    merge3 b o t p = .conflict ↔ ConflictAt b o t p :=
  merge3Cell_eq_conflict_iff _ _ _

/-- Without a conflict path, every location of the merge is a value, namely the
location of `merge3State`. -/
theorem merge3_ok_of_no_conflict {b o t : State} (h : ∀ p, ¬ ConflictAt b o t p) (p : Path) :
    merge3 b o t p = .ok (merge3State b o t p) := by
  have hp := h p
  rw [← merge3_conflict_iff] at hp
  simp only [merge3State]
  cases hm : merge3 b o t p with
  | ok v => rfl
  | conflict => exact absurd hm hp

/-- Proposition 6.5 (merged writes), file level: with no conflict path the merge takes
`ours` where ours changed, `theirs` where theirs changed and the base elsewhere. -/
theorem merge3_spec {b o t : State} (h : ∀ p, ¬ ConflictAt b o t p) :
    MergeSpec b o t (merge3State b o t) := by
  intro p
  have hp := h p
  simp only [ConflictAt] at hp
  simp only [merge3State, merge3, merge3Cell]
  by_cases h1 : o p = b p <;> by_cases h2 : t p = b p <;> by_cases h3 : o p = t p <;>
    simp_all [Cell.getD]

/-- Proposition 6.5, uniqueness: any state meeting the merge specification is the merge.
The specification cannot be met at a conflict path, so no hypothesis is needed. -/
theorem merge3_unique {b o t m : State} (hm : MergeSpec b o t m) : m = merge3State b o t := by
  funext p
  obtain ⟨h₁, h₂, h₃⟩ := hm p
  simp only [merge3State, merge3, merge3Cell]
  by_cases e1 : o p = b p <;> by_cases e2 : t p = b p
  · simp [e1, Cell.getD, h₃ e1 e2, e2]
  · simp [e1, Cell.getD, h₂ e2]
  · simp [e1, e2, Cell.getD, h₁ e1]
  · by_cases e3 : o p = t p
    · simp [e2, e3, Cell.getD, h₂ e2]
    · exact absurd ((h₁ e1).symm.trans (h₂ e2)) e3

/-- The merge state satisfies the specification iff it is `merge3State`, when there is
no conflict path. -/
theorem merge3_spec_iff {b o t : State} (h : ∀ p, ¬ ConflictAt b o t p) (m : State) :
    MergeSpec b o t m ↔ m = merge3State b o t :=
  ⟨merge3_unique, fun e => e ▸ merge3_spec h⟩

/-- Commutativity: at file level the merge does not depend on which side is `ours`,
including where it reports a conflict. -/
theorem merge3_comm (b o t : State) : merge3 b o t = merge3 b t o := by
  funext p; exact merge3Cell_comm _ _ _

theorem merge3State_comm {b o t : State} (h : ∀ p, ¬ ConflictAt b o t p) :
    merge3State b o t = merge3State b t o := by
  funext p
  have e₁ := merge3_ok_of_no_conflict h p
  have h' : ∀ p, ¬ ConflictAt b t o p := by
    intro p ⟨a, c, d⟩; exact h p ⟨c, a, fun e => d e.symm⟩
  have e₂ := merge3_ok_of_no_conflict h' p
  rw [merge3_comm] at e₁
  rw [e₁] at e₂
  exact Cell.ok.inj e₂

/-- Identity: merging an unchanged `ours` gives `theirs`. -/
theorem merge3_base_left (b t : State) : merge3 b b t = fun p => .ok (t p) := by
  funext p; exact merge3Cell_base_left _ _

/-- Identity: merging an unchanged `theirs` gives `ours`. -/
theorem merge3_base_right (b o : State) : merge3 b o b = fun p => .ok (o p) := by
  funext p; exact merge3Cell_base_right _ _

/-- Idempotence: merging a state with itself gives that state. -/
theorem merge3_idem (b x : State) : merge3 b x x = fun p => .ok (x p) := by
  funext p; exact merge3Cell_same _ _

/-- Conflict characterization, whole-tree form. -/
theorem merge_conflict_characterization (b o t : State) :
    (∃ p, merge3 b o t p = .conflict) ↔ ∃ p, o p ≠ b p ∧ t p ≠ b p ∧ o p ≠ t p := by
  simp only [merge3_conflict_iff, ConflictAt]

/-- If the two sides change only within write sets that do not overlap, there is no
conflict. -/
theorem merge_no_conflict_of_disjoint {b o t : State} {Wo Wt : Access}
    (ho : ChangesWithin Wo b o) (ht : ChangesWithin Wt b t) (hd : meetsSet Wo Wt = false)
    (p : Path) : merge3 b o t p ≠ .conflict := by
  rw [Ne, merge3_conflict_iff]
  rintro ⟨h₁, h₂, -⟩
  cases c₁ : covered Wo p
  · exact h₁ (ho p c₁)
  · cases c₂ : covered Wt p
    · exact h₂ (ht p c₂)
    · rw [meetsSet_of_covered c₁ c₂] at hd; exact absurd hd (by simp)

/-- The diff of a change `c` against its base `b`, applied to a state `h`: take `c`
where it differs from `b`, and `h` elsewhere. -/
def applyDiff (b c h : State) : State := fun p => if c p = b p then h p else c p

/-- A conflict-free three-way merge applies the diff of `theirs` (against the base) to
`ours`. -/
theorem merge3State_eq_applyDiff {b h c : State} (hnc : ∀ p, ¬ ConflictAt b h c p) :
    merge3State b h c = applyDiff b c h := by
  funext p
  have hp := hnc p
  simp only [ConflictAt] at hp
  simp only [merge3State, merge3, merge3Cell, applyDiff]
  by_cases h1 : h p = b p <;> by_cases h2 : c p = b p <;> by_cases h3 : h p = c p <;>
    simp_all [Cell.getD]

/-! ## Lines as sub-locations

A file's lines are modelled as child locations `f ++ [ℓ]` with *stable* line keys `ℓ`.
Positional `diff3` (insertions that shift line numbers, alignment of hunks) is not
modelled. -/

/-- The lines of file `f` in state `s`: line `ℓ` is the location `f ++ [ℓ]`. -/
def lines (s : State) (f : Path) : String → Option Blob := fun ℓ => s (f ++ [ℓ])

/-- A file-granular conflict: both sides changed file `f`, to different contents. -/
def FileConflict (b o t : State) (f : Path) : Prop :=
  lines o f ≠ lines b f ∧ lines t f ≠ lines b f ∧ lines o f ≠ lines t f

/-- Line-level refinement. If the two sides change disjoint sets of lines of `f`, the
line-granular merge has no conflict on any line of `f`, and on each line it applies the
diff of `theirs` to `ours`, which is also the diff of `ours` applied to `theirs`. No
hypothesis excludes a file-granular conflict (`FileConflict`); see
`Witnesses.line_merge_witness` for a case where both happen. -/
theorem line_merge_refines {b o t : State} {f : Path}
    (hdisj : ∀ ℓ, lines o f ℓ = lines b f ℓ ∨ lines t f ℓ = lines b f ℓ) (ℓ : String) :
    ¬ ConflictAt b o t (f ++ [ℓ]) ∧
    merge3 b o t (f ++ [ℓ]) = .ok (applyDiff b t o (f ++ [ℓ])) ∧
    applyDiff b t o (f ++ [ℓ]) = applyDiff b o t (f ++ [ℓ]) := by
  have h := hdisj ℓ
  simp only [lines] at h
  simp only [ConflictAt, merge3, merge3Cell, applyDiff]
  rcases h with h | h <;> by_cases h₁ : t (f ++ [ℓ]) = b (f ++ [ℓ]) <;>
    by_cases h₂ : o (f ++ [ℓ]) = b (f ++ [ℓ]) <;> simp_all

/-! ## The state installed by a landing -/

/-- The state installed when a change `c`, built on base `b`, lands on head `h`: the
three-way merge with the head as `ours` and the change as `theirs`. A conflicting
location falls back to the change's value. Validation refuses such landings in the
paper; no theorem below depends on the fallback beyond `landOn_changesWithin`. -/
def landOn (b h c : State) : State := fun p => (merge3 b h c p).getD (c p)

/-- Landing on the base itself (a fast-forward) installs the change. -/
theorem landOn_self (b c : State) : landOn b b c = c := by
  funext p; simp [landOn, merge3, merge3Cell_base_left, Cell.getD]

/-- A landing changes the head only where the change differs from its base. -/
theorem landOn_of_unchanged {b h c : State} {p : Path} (hp : c p = b p) :
    landOn b h c p = h p := by
  simp [landOn, merge3, hp, merge3Cell_base_right, Cell.getD]

/-- A landing changes the head only within the change's write set. -/
theorem landOn_changesWithin {W : Access} {b h c : State} (hc : ChangesWithin W b c) :
    ChangesWithin W h (landOn b h c) := fun p hp => landOn_of_unchanged (hc p hp)

/-- A landing at `p` depends on the head only through its value at `p`. -/
theorem landOn_congr_head {b h h' c : State} {p : Path} (hp : h p = h' p) :
    landOn b h c p = landOn b h' c p := by
  simp [landOn, merge3, hp]

/-- Without a conflict path, a landing installs the three-way merge. -/
theorem landOn_eq_merge3State {b h c : State} (hnc : ∀ p, ¬ ConflictAt b h c p) :
    landOn b h c = merge3State b h c := by
  funext p
  show (merge3 b h c p).getD (c p) = merge3State b h c p
  rw [merge3_ok_of_no_conflict hnc p]; rfl

/-- Part 3 of Theorem 6.4: if the head agrees with the base on the change's write set,
the landing equals the change on `W` and the head elsewhere. -/
theorem landOn_rebase {W : Access} {b h c : State} (hc : ChangesWithin W b c)
    (hh : ∀ p, covered W p = true → h p = b p) (p : Path) :
    landOn b h c p = if covered W p = true then c p else h p := by
  split
  · next hp => simp [landOn, merge3, hh p hp, merge3Cell_base_left, Cell.getD]
  · next hp => exact landOn_of_unchanged (hc p (by simpa using hp))

end YonedaTx
