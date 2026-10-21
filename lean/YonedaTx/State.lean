import YonedaTx.Paths

/-!
# Tree states, agreement and transactions

Part I, Section 4.2 (content and agreement `≡_X`) and the transaction model used
by Theorem 6.4. A tree state assigns optional content to every location; `none`
is the paper's `⊥` (absent).
-/

namespace YonedaTx

/-- File content. The paper's blobs are identified by hash; any type with decidable
equality would do, and `Nat` keeps the concrete examples computable. -/
abbrev Blob := Nat

/-- A tree state: content of every location, `none` when absent. -/
abbrev State := Path → Option Blob

/-- Agreement `s ≡_X t`: `s` and `t` assign the same content to every location that
overlaps some element of `X`. This contains the paper's region `⋃_{x ∈ X} sub(x)`
and also the ancestors of each `x`. -/
def Agree (X : Access) (s t : State) : Prop := ∀ p, region X p = true → s p = t p

theorem Agree.refl (X : Access) (s : State) : Agree X s s := fun _ _ => rfl

theorem Agree.symm {X : Access} {s t : State} (h : Agree X s t) : Agree X t s :=
  fun p hp => (h p hp).symm

theorem Agree.trans {X : Access} {s t u : State} (h₁ : Agree X s t) (h₂ : Agree X t u) :
    Agree X s u := fun p hp => (h₁ p hp).trans (h₂ p hp)

theorem Agree.left {X Y : Access} {s t : State} (h : Agree (X ++ Y) s t) : Agree X s t :=
  fun p hp => h p (by simp [hp])

theorem Agree.right {X Y : Access} {s t : State} (h : Agree (X ++ Y) s t) : Agree Y s t :=
  fun p hp => h p (by simp [hp])

/-- `ChangesWithin W s t`: `t` differs from `s` only at locations covered by `W`.
This is Part I, Assumption 6.2 (sound refinement) for one step. -/
def ChangesWithin (W : Access) (s t : State) : Prop := ∀ p, covered W p = false → t p = s p

theorem ChangesWithin.coarsen {W W' : Access} {s t : State} (hW : Coarsens W' W)
    (h : ChangesWithin W s t) : ChangesWithin W' s t := by
  intro p hp
  apply h p
  cases hc : covered W p
  · rfl
  · rw [covered_coarsen hW hc] at hp; exact absurd hp (by simp)

/-- The frame step: a change within `W` is invisible on any `X` with `X ⋈̸ W`. -/
theorem agree_of_changesWithin {X W : Access} {s t : State} (h : ChangesWithin W s t)
    (hX : meetsSet X W = false) : Agree X s t := by
  intro p hp
  cases hc : covered W p
  · exact (h p hc).symm
  · rw [meetsSet_of_region_covered hp hc] at hX; exact absurd hX (by simp)

/-- A transaction with declared read set `R` and write set `W`.

* `frame`: it changes only locations covered by `W` (Assumption 6.2 at path granularity).
* `reads`: the values it writes depend only on the state restricted to `R ∪ W`.
  Allowing a dependence on `W` as well as `R` covers read-modify-write patches such
  as line edits, and is weaker than requiring dependence on `R` alone. -/
structure Txn where
  R : Access
  W : Access
  f : State → State
  frame : ∀ s p, covered W p = false → f s p = s p
  reads : ∀ s t, Agree (R ++ W) s t → ∀ p, covered W p = true → f s p = f t p

theorem Txn.changesWithin (c : Txn) (s : State) : ChangesWithin c.W s (c.f s) :=
  fun p hp => c.frame s p hp

/-- `overlay s t W`: `s` with every location covered by `W` replaced by its value in `t`. -/
def overlay (s t : State) (W : Access) : State := fun p => if covered W p then t p else s p

/-- A changeset (Part I, Definition 8.1): declared reads `R`, written paths `W`, and the
new content `Φ` (with `none` for a deletion) on the locations covered by `W`. -/
def Txn.changeset (R W : Access) (Φ : State) : Txn where
  R := R
  W := W
  f s := overlay s Φ W
  frame s p hp := by simp [overlay, hp]
  reads s t _ p hp := by simp [overlay, hp]

/-- Overwrite one location. -/
def setAt (s : State) (q : Path) (v : Option Blob) : State := fun p => if p = q then v else s p

/-- A transaction that reads `R` and sets the single location `q` to `g s`, where `g`
depends only on `R`. Used for the concrete examples. -/
def Txn.write1 (R : Access) (q : Path) (g : State → Option Blob)
    (hg : ∀ s t, Agree R s t → g s = g t) : Txn where
  R := R
  W := [q]
  f s := setAt s q (g s)
  frame s p hp := by
    simp only [setAt]
    split
    · next h => subst h; simp [covered, anc_refl] at hp
    · rfl
  reads s t hst p hp := by
    simp only [setAt]
    split
    · exact hg s t hst.left
    · exact hst p (by simp [region_of_covered hp])

/-- Like `Txn.write1`, but with a declared write set `W` that covers the written
location `q`. -/
def Txn.assign (R W : Access) (q : Path) (hq : covered W q = true) (g : State → Option Blob)
    (hg : ∀ s t, Agree R s t → g s = g t) : Txn where
  R := R
  W := W
  f s := setAt s q (g s)
  frame s p hp := by
    simp only [setAt]
    split
    · next h => subst h; rw [hq] at hp; cases hp
    · rfl
  reads s t hst p hp := by
    simp only [setAt]
    split
    · exact hg s t hst.left
    · exact hst p (by simp [region_of_covered hp])

/-- A patch: declared write set `W`, but it changes only the locations covered by
`D ⊑ W`, setting them to `Φ`. This is a change declared at a coarser granularity than
the one it acts at, for example a whole file `W = {f}` for an edit of one line
`D = {f/ℓ}`. -/
def Txn.patch (R W D : Access) (Φ : State) (hD : Coarsens W D) : Txn where
  R := R
  W := W
  f s := overlay s Φ D
  frame s p hp := by
    have : covered D p = false := by
      cases h : covered D p
      · rfl
      · rw [covered_coarsen hD h] at hp; cases hp
    simp [overlay, this]
  reads s t hst p hp := by
    simp only [overlay]
    split
    · rfl
    · exact hst p (by simp [region_of_covered hp])

theorem Txn.patch_changesWithin {R W D : Access} {Φ : State} {hD : Coarsens W D} (s : State) :
    ChangesWithin D s ((Txn.patch R W D Φ hD).f s) := fun p hp => by
  simp [Txn.patch, overlay, hp]

end YonedaTx
