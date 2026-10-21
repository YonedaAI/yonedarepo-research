/-!
# Locations, overlap and access sets

Part I, Definition 4.4 (location tree and overlap) and Lemma 4.5 (overlap).

A location is a list of components. Directories, files and symbols are all
nodes of one tree, so a symbol `src/lib.rs#Policy::backoff` is modelled as the
path `["src", "lib.rs", "Policy", "backoff"]`. The ancestor-or-equal relation
`a ⊑ b` is "`a` is a component-wise prefix of `b`", which is exactly the
component-boundary prefix test of the implementation (`src/a` is not an
ancestor of `src/ab`, because `"a" ≠ "ab"`).
-/

namespace YonedaTx

/-- A node of the location tree (Part I, Definition 4.4). -/
abbrev Path := List String

/-- `anc a b` decides `a ⊑ b`: `a` is an ancestor of `b` or equal to it. -/
def anc : Path → Path → Bool
  | [], _ => true
  | _ :: _, [] => false
  | x :: xs, y :: ys => decide (x = y) && anc xs ys

@[simp] theorem anc_nil_left (b : Path) : anc [] b = true := by
  cases b <;> rfl

@[simp] theorem anc_cons_nil (x : String) (xs : Path) : anc (x :: xs) [] = false := rfl

@[simp] theorem anc_cons_cons (x y : String) (xs ys : Path) :
    anc (x :: xs) (y :: ys) = (decide (x = y) && anc xs ys) := rfl

/-- `a ⊑ b` iff `b` extends `a`. -/
theorem anc_iff {a b : Path} : anc a b = true ↔ ∃ t, b = a ++ t := by
  induction a generalizing b with
  | nil => simp
  | cons x xs ih =>
    cases b with
    | nil => simp
    | cons y ys =>
      simp only [anc_cons_cons, Bool.and_eq_true, decide_eq_true_eq, ih, List.cons_append,
        List.cons.injEq]
      constructor
      · rintro ⟨rfl, t, rfl⟩; exact ⟨t, rfl, rfl⟩
      · rintro ⟨t, rfl, rfl⟩; exact ⟨rfl, t, rfl⟩

theorem anc_refl (a : Path) : anc a a = true := anc_iff.2 ⟨[], by simp⟩

theorem anc_trans {a b c : Path} (h₁ : anc a b = true) (h₂ : anc b c = true) :
    anc a c = true := by
  obtain ⟨t, rfl⟩ := anc_iff.1 h₁
  obtain ⟨t', rfl⟩ := anc_iff.1 h₂
  exact anc_iff.2 ⟨t ++ t', by simp⟩

/-- The ancestors of a node form a chain: two ancestors of one node are comparable. -/
theorem anc_comparable {a b x : Path} (ha : anc a x = true) (hb : anc b x = true) :
    anc a b = true ∨ anc b a = true := by
  induction a generalizing b x with
  | nil => exact Or.inl (anc_nil_left b)
  | cons ah as ih =>
    cases b with
    | nil => exact Or.inr (anc_nil_left _)
    | cons bh bt =>
      cases x with
      | nil => simp at ha
      | cons xh xt =>
        simp only [anc_cons_cons, Bool.and_eq_true, decide_eq_true_eq] at ha hb ⊢
        obtain ⟨rfl, ha⟩ := ha
        obtain ⟨rfl, hb⟩ := hb
        rcases ih ha hb with h | h
        · exact Or.inl ⟨rfl, h⟩
        · exact Or.inr ⟨rfl, h⟩

/-- Overlap `a ⋈ b`: one access is an ancestor of the other (Part I, Definition 4.4). -/
def meets (a b : Path) : Bool := anc a b || anc b a

theorem meets_iff {a b : Path} : meets a b = true ↔ anc a b = true ∨ anc b a = true := by
  simp [meets]

/-- Lemma 4.5, first claim: `a ⋈ b` iff `sub(a) ∩ sub(b) ≠ ∅`, where `sub(a) = {x | a ⊑ x}`. -/
theorem overlap_iff_common_descendant {a b : Path} :
    meets a b = true ↔ ∃ x, anc a x = true ∧ anc b x = true := by
  constructor
  · intro h
    rcases meets_iff.1 h with h | h
    · exact ⟨b, h, anc_refl b⟩
    · exact ⟨a, anc_refl a, h⟩
  · rintro ⟨x, ha, hb⟩
    exact meets_iff.2 (anc_comparable ha hb)

/-- Lemma 4.5: overlap is reflexive. -/
theorem overlap_refl (a : Path) : meets a a = true := by simp [meets, anc_refl]

/-- Lemma 4.5: overlap is symmetric. -/
theorem overlap_symm (a b : Path) : meets a b = meets b a := by
  simp [meets, Bool.or_comm]

/-- Lemma 4.5, last claim (coarsening is monotone): if `a' ⊑ a` and `a ⋈ b` then `a' ⋈ b`. -/
theorem overlap_coarsen {a a' b : Path} (h : anc a' a = true) (hab : meets a b = true) :
    meets a' b = true := by
  rcases meets_iff.1 hab with hab | hba
  · exact meets_iff.2 (Or.inl (anc_trans h hab))
  · exact meets_iff.2 (anc_comparable h hba)

theorem meets_of_anc {a b : Path} (h : anc a b = true) : meets a b = true :=
  meets_iff.2 (Or.inl h)

/-! ## Access sets -/

/-- A finite set of accesses, as a list (Part I, Definition 4.6). -/
abbrev Access := List Path

/-- `X ⋈ Y`: some element of `X` overlaps some element of `Y`. -/
def meetsSet (X Y : Access) : Bool := X.any fun x => Y.any fun y => meets x y

/-- `covered X p` decides `p ∈ ⋃_{x ∈ X} sub(x)`. -/
def covered (X : Access) (p : Path) : Bool := X.any fun x => anc x p

/-- `region X p` decides whether `p` overlaps some element of `X`. Agreement on `X`
(see `Agree`) is agreement on this region. -/
def region (X : Access) (p : Path) : Bool := X.any fun x => meets x p

theorem meetsSet_iff {X Y : Access} :
    meetsSet X Y = true ↔ ∃ x ∈ X, ∃ y ∈ Y, meets x y = true := by
  simp [meetsSet, List.any_eq_true]

theorem covered_iff {X : Access} {p : Path} :
    covered X p = true ↔ ∃ x ∈ X, anc x p = true := by
  simp [covered, List.any_eq_true]

theorem region_iff {X : Access} {p : Path} :
    region X p = true ↔ ∃ x ∈ X, meets x p = true := by
  simp [region, List.any_eq_true]

theorem meetsSet_symm (X Y : Access) : meetsSet X Y = meetsSet Y X := by
  apply Bool.eq_iff_iff.2
  simp only [meetsSet_iff]
  constructor
  · rintro ⟨x, hx, y, hy, h⟩; exact ⟨y, hy, x, hx, by rw [overlap_symm]; exact h⟩
  · rintro ⟨y, hy, x, hx, h⟩; exact ⟨x, hx, y, hy, by rw [overlap_symm]; exact h⟩

@[simp] theorem meetsSet_append_left (X X' Y : Access) :
    meetsSet (X ++ X') Y = (meetsSet X Y || meetsSet X' Y) := by
  simp [meetsSet, List.any_append]

@[simp] theorem meetsSet_nil_left (Y : Access) : meetsSet [] Y = false := rfl

@[simp] theorem region_append (X X' : Access) (p : Path) :
    region (X ++ X') p = (region X p || region X' p) := by
  simp [region, List.any_append]

theorem region_of_covered {X : Access} {p : Path} (h : covered X p = true) :
    region X p = true := by
  obtain ⟨x, hx, h⟩ := covered_iff.1 h
  exact region_iff.2 ⟨x, hx, meets_of_anc h⟩

/-- Two sets that both cover `p` meet. -/
theorem meetsSet_of_covered {X Y : Access} {p : Path}
    (hX : covered X p = true) (hY : covered Y p = true) : meetsSet X Y = true := by
  obtain ⟨x, hx, hxp⟩ := covered_iff.1 hX
  obtain ⟨y, hy, hyp⟩ := covered_iff.1 hY
  exact meetsSet_iff.2 ⟨x, hx, y, hy, meets_iff.2 (anc_comparable hxp hyp)⟩

/-- If `X ⋈̸ Y` and `Y` covers `p`, then `X` does not. -/
theorem not_covered_of_disjoint {X Y : Access} {p : Path} (hd : meetsSet X Y = false)
    (hY : covered Y p = true) : covered X p = false := by
  cases hX : covered X p
  · rfl
  · rw [meetsSet_of_covered hX hY] at hd; exact absurd hd (by simp)

/-- If `p` lies in the region of `X` and is covered by `W`, then `X ⋈ W`. This is the
step of the frame lemma: a change below `w` is visible to `x` only if `x ⋈ w`. -/
theorem meetsSet_of_region_covered {X W : Access} {p : Path}
    (hX : region X p = true) (hW : covered W p = true) : meetsSet X W = true := by
  obtain ⟨x, hx, hxp⟩ := region_iff.1 hX
  obtain ⟨w, hw, hwp⟩ := covered_iff.1 hW
  refine meetsSet_iff.2 ⟨x, hx, w, hw, ?_⟩
  rcases meets_iff.1 hxp with h | h
  · exact meets_iff.2 (anc_comparable h hwp)
  · exact meets_iff.2 (Or.inr (anc_trans hwp h))

/-! ## Coarsening (Part I, Proposition 6.10) -/

/-- `Coarsens X' X`: every access of `X` has an ancestor-or-equal in `X'`. -/
def Coarsens (X' X : Access) : Prop := ∀ a ∈ X, ∃ a' ∈ X', anc a' a = true

theorem Coarsens.refl (X : Access) : Coarsens X X := fun a ha => ⟨a, ha, anc_refl a⟩

/-- Replace every occurrence of the access `a` by `a'` (the operation of Proposition 6.10). -/
def replaceAccess (X : Access) (a a' : Path) : Access := X.map fun x => if x = a then a' else x

/-- Replacing an access by an ancestor is a coarsening. -/
theorem coarsens_replaceAccess {X : Access} {a a' : Path} (h : anc a' a = true) :
    Coarsens (replaceAccess X a a') X := by
  intro x hx
  by_cases hxa : x = a
  · subst hxa
    exact ⟨a', List.mem_map.2 ⟨x, hx, by simp⟩, h⟩
  · exact ⟨x, List.mem_map.2 ⟨x, hx, by simp [hxa]⟩, anc_refl x⟩

theorem Coarsens.append {X X' Y Y' : Access} (hX : Coarsens X' X) (hY : Coarsens Y' Y) :
    Coarsens (X' ++ Y') (X ++ Y) := by
  intro a ha
  rcases List.mem_append.1 ha with ha | ha
  · obtain ⟨a', h', h⟩ := hX a ha; exact ⟨a', List.mem_append.2 (Or.inl h'), h⟩
  · obtain ⟨a', h', h⟩ := hY a ha; exact ⟨a', List.mem_append.2 (Or.inr h'), h⟩

/-- Overlap persists under coarsening of both sides (Lemma 4.5 lifted to sets). -/
theorem meetsSet_coarsen {X X' Y Y' : Access} (hX : Coarsens X' X) (hY : Coarsens Y' Y)
    (h : meetsSet X Y = true) : meetsSet X' Y' = true := by
  obtain ⟨x, hx, y, hy, hxy⟩ := meetsSet_iff.1 h
  obtain ⟨x', hx', hxx⟩ := hX x hx
  obtain ⟨y', hy', hyy⟩ := hY y hy
  have h1 : meets x' y = true := overlap_coarsen hxx hxy
  have h2 : meets y' x' = true := by
    rw [overlap_symm] at h1; exact overlap_coarsen hyy h1
  exact meetsSet_iff.2 ⟨x', hx', y', hy', by rw [overlap_symm]; exact h2⟩

theorem covered_coarsen {X X' : Access} {p : Path} (hX : Coarsens X' X)
    (h : covered X p = true) : covered X' p = true := by
  obtain ⟨x, hx, hxp⟩ := covered_iff.1 h
  obtain ⟨x', hx', hxx⟩ := hX x hx
  exact covered_iff.2 ⟨x', hx', anc_trans hxx hxp⟩

end YonedaTx
