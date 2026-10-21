import YonedaTx.Batch

/-!
# Graphs: serialization graph, commit graph and the Git projection

* The serialization graph of a validated log (the direction of Bernstein, Hadzilacos
  and Goodman's Theorem 2.1 used in the proof of Part I, Theorem 6.4).
* Refs advance along first-parent chains (Part I, Lemma 5.3, Theorem 5.4 and
  Corollary 5.5).
* The Git projection is deterministic (Part II, Lemma 13.2; Part I, Assumption 8.2 and
  Proposition 8.3(5)).
-/

namespace YonedaTx

/-! ## Serialization graph -/

/-- Edge `i → j` of the serialization graph of a log, between the entries at indices `i`
and `j`. Entry `i` reads its read set at version `base_i` and writes its write set at
version `i + 1`. There is an edge when an operation of `i` precedes a conflicting
(overlapping, at least one a write) operation of `j`:
write–write (`i < j`), write–read (`i + 1 ≤ base_j`), or read–write (`base_i ≤ j`). -/
def SEdge (log : Log) (i j : Nat) : Prop :=
  ∃ ei ej, log[i]? = some ei ∧ log[j]? = some ej ∧ i ≠ j ∧
    ((i < j ∧ meetsSet ei.txn.W ej.txn.W = true) ∨
     (i + 1 ≤ ej.base ∧ meetsSet ei.txn.W ej.txn.R = true) ∨
     (ei.base ≤ j ∧ meetsSet ei.txn.R ej.txn.W = true))

/-- Paths in the serialization graph. -/
inductive SReach (log : Log) : Nat → Nat → Prop where
  | edge {i j : Nat} : SEdge log i j → SReach log i j
  | tail {i j k : Nat} : SReach log i j → SEdge log j k → SReach log i k

/-- Every edge of the serialization graph of a log with no Conflict landing points
forward in log order. A read–write edge from `i` back to an earlier `j` would mean that
`j` lies in `Later` of `i` and `R_i ⋈ W_j`, which validation refuses. -/
theorem sgraph_edge_forward {log : Log} (h : NoConflict log) {i j : Nat}
    (he : SEdge log i j) : i < j := by
  obtain ⟨ei, ej, hi, hj, hne, hww | hwr | hrw⟩ := he
  · exact hww.1
  · have := (h j ej hj).1; omega
  · obtain ⟨hb, hm⟩ := hrw
    rcases Nat.lt_or_ge i j with hij | hij
    · exact hij
    · have hji : j < i := by omega
      have hstale := no_stale_read (h i ei hi).2 _ (mem_laterWrites hb hji hj)
      rw [hm] at hstale; cases hstale

theorem sgraph_reach_forward {log : Log} (h : NoConflict log) {i j : Nat}
    (hr : SReach log i j) : i < j := by
  induction hr with
  | edge he => exact sgraph_edge_forward h he
  | tail _ he ih => exact Nat.lt_trans ih (sgraph_edge_forward h he)

/-- The serialization graph of a log with no Conflict landing is acyclic, and log order
is a topological order of it. The graph is built from declared reads and writes; a
Merge landing's dependence on the head is not an edge. With Theorem 2.1 of Bernstein, Hadzilacos and Goodman this
gives conflict-serializability; `serializability` proves the state equality directly. -/
theorem sgraph_acyclic {log : Log} (h : NoConflict log) (i : Nat) : ¬ SReach log i i :=
  fun hr => Nat.lt_irrefl i (sgraph_reach_forward h hr)

/-! ## Commit graph and refs -/

/-- Commit identifiers. -/
abbrev CommitId := Nat

/-- Ref names. -/
abbrev RefName := String

/-- A ref-log entry: the ref it names and the commit it installs. Implemented kinds are
commit, merge, revert and import, so the new value is never `⊥` (Lemma 5.3). -/
structure RefEntry where
  ref : RefName
  new : CommitId

/-- Snapshot of all refs at version `v` (Definition 4.11): the fold of entries `1..v`. -/
def refSnap (log : List RefEntry) : Nat → RefName → Option CommitId
  | 0 => fun _ => none
  | v + 1 =>
    match log[v]? with
    | none => refSnap log v
    | some e => fun r => if r = e.ref then some e.new else refSnap log v r

/-- First parent, from the parent list (first parent first). -/
def fp (parents : CommitId → List CommitId) (c : CommitId) : Option CommitId :=
  (parents c).head?

/-- Lemma 5.3 (append discipline), as a hypothesis on the log: an entry naming `r`
either starts `r` or installs a commit whose first parent is the current value. -/
def AppendDiscipline (parents : CommitId → List CommitId) (log : List RefEntry) : Prop :=
  ∀ v e, log[v]? = some e →
    refSnap log v e.ref = none ∨ fp parents e.new = refSnap log v e.ref

/-- `FPChain parents y x`: `x` is reached from `y` by following first parents. -/
inductive FPChain (parents : CommitId → List CommitId) : CommitId → CommitId → Prop where
  | refl (x : CommitId) : FPChain parents x x
  | step {y z x : CommitId} : fp parents y = some z → FPChain parents z x → FPChain parents y x

/-- `Ancestor parents y x`: `x` is reached from `y` by following any parents. -/
inductive Ancestor (parents : CommitId → List CommitId) : CommitId → CommitId → Prop where
  | refl (x : CommitId) : Ancestor parents x x
  | step {y z x : CommitId} : z ∈ parents y → Ancestor parents z x → Ancestor parents y x

theorem FPChain.ancestor {parents : CommitId → List CommitId} {y x : CommitId}
    (h : FPChain parents y x) : Ancestor parents y x := by
  induction h with
  | refl x => exact .refl x
  | step hz _ ih =>
    refine .step ?_ ih
    simp only [fp] at hz
    exact List.mem_of_head? hz

theorem Ancestor.trans {parents : CommitId → List CommitId} {a b c : CommitId}
    (h₁ : Ancestor parents a b) (h₂ : Ancestor parents b c) : Ancestor parents a c := by
  induction h₁ with
  | refl => exact h₂
  | step hz _ ih => exact .step hz (ih h₂)

theorem FPChain.trans {parents : CommitId → List CommitId} {a b c : CommitId}
    (h₁ : FPChain parents a b) (h₂ : FPChain parents b c) : FPChain parents a c := by
  induction h₁ with
  | refl => exact h₂
  | step hz _ ih => exact .step hz (ih h₂)

/-- Generations: every parent has a smaller generation, so the parent relation is acyclic. -/
def GenOk (parents : CommitId → List CommitId) (gen : CommitId → Nat) : Prop :=
  ∀ c p, p ∈ parents c → gen p < gen c

theorem FPChain.gen_le {parents : CommitId → List CommitId} {gen : CommitId → Nat}
    (hg : GenOk parents gen) {y x : CommitId} (h : FPChain parents y x) : gen x ≤ gen y := by
  induction h with
  | refl => exact Nat.le_refl _
  | step hz _ ih =>
    have := hg _ _ (List.mem_of_head? (by simpa [fp] using hz))
    omega

variable {parents : CommitId → List CommitId} {log : List RefEntry}

theorem refSnap_succ_other {v : Nat} {e : RefEntry} {r : RefName} (he : log[v]? = some e)
    (hr : r ≠ e.ref) : refSnap log (v + 1) r = refSnap log v r := by
  simp [refSnap, he, hr]

theorem refSnap_succ_self {v : Nat} {e : RefEntry} (he : log[v]? = some e) :
    refSnap log (v + 1) e.ref = some e.new := by
  simp [refSnap, he]

/-- Theorem 5.4 (refs advance along first-parent chains), first claim: if `r` holds `x`
at version `u`, then at every later version `v` it holds some `y` from which `x` is
reached by first parents. -/
theorem refs_advance (hd : AppendDiscipline parents log) {u : Nat} {r : RefName} {x : CommitId}
    (hx : refSnap log u r = some x) :
    ∀ v, u ≤ v → ∃ y, refSnap log v r = some y ∧ FPChain parents y x := by
  intro v huv
  induction v with
  | zero => rw [Nat.le_zero.1 huv] at hx; exact ⟨x, hx, .refl x⟩
  | succ v ih =>
    rcases Nat.lt_or_ge v u with hvu | hvu
    · have : u = v + 1 := by omega
      subst this; exact ⟨x, hx, .refl x⟩
    · obtain ⟨y, hy, hc⟩ := ih hvu
      cases hl : log[v]? with
      | none => exact ⟨y, by simp [refSnap, hl, hy], hc⟩
      | some e =>
        by_cases hr : r = e.ref
        · subst hr
          refine ⟨e.new, refSnap_succ_self hl, ?_⟩
          rcases hd v e hl with h | h
          · rw [h] at hy; cases hy
          · rw [hy] at h; exact .step h hc
        · exact ⟨y, by rw [refSnap_succ_other hl hr, hy], hc⟩

/-- Once a ref is defined it stays defined. -/
theorem refs_defined (hd : AppendDiscipline parents log) {u v : Nat} {r : RefName}
    (huv : u ≤ v) (h : refSnap log u r ≠ none) : refSnap log v r ≠ none := by
  cases hx : refSnap log u r with
  | none => exact absurd hx h
  | some x =>
    obtain ⟨y, hy, -⟩ := refs_advance hd hx v huv
    rw [hy]; simp

/-- Theorem 5.4, second claim: if `r` has the same value at `u` and `v` (including `⊥` at
both), no entry with version in `(u, v]` names `r`. -/
theorem refs_unchanged_no_entry {gen : CommitId → Nat} (hd : AppendDiscipline parents log)
    (hg : GenOk parents gen) {u v : Nat} {r : RefName}
    (heq : refSnap log u r = refSnap log v r) :
    ∀ i e, u ≤ i → i < v → log[i]? = some e → e.ref ≠ r := by
  intro i e hui hiv he hr
  subst hr
  have hdef : refSnap log (i + 1) e.ref = some e.new := refSnap_succ_self he
  cases hx : refSnap log u e.ref with
  | none =>
    have := refs_defined hd (u := i + 1) (v := v) (by omega) (by rw [hdef]; simp)
    rw [← heq, hx] at this; exact this rfl
  | some x =>
    obtain ⟨y₁, hy₁, hc₁⟩ := refs_advance hd hx i hui
    have hfp : fp parents e.new = some y₁ := by
      rcases hd i e he with h | h
      · rw [hy₁] at h; cases h
      · rw [h, hy₁]
    obtain ⟨y₂, hy₂, hc₂⟩ := refs_advance hd hdef v (by omega)
    have g₁ := hc₁.gen_le hg
    have g₂ := hc₂.gen_le hg
    have g₃ := hg _ _ (List.mem_of_head? (by simpa [fp] using hfp))
    rw [← heq, hx] at hy₂
    cases hy₂
    omega

/-- Corollary 5.5 (no lost update): if `c` landed on `r` at the entry with index `i`
(the entry installs `c`, or a merge with `c` among its parents), then `c` is an
ancestor of the value of `r` at every later version. -/
theorem no_lost_update (hd : AppendDiscipline parents log) {i : Nat} {e : RefEntry}
    {c : CommitId} (he : log[i]? = some e) (hc : e.new = c ∨ c ∈ parents e.new) :
    ∀ v, i + 1 ≤ v → ∃ y, refSnap log v e.ref = some y ∧ Ancestor parents y c := by
  intro v hv
  obtain ⟨y, hy, hch⟩ := refs_advance hd (refSnap_succ_self he) v hv
  refine ⟨y, hy, hch.ancestor.trans ?_⟩
  rcases hc with rfl | hc
  · exact .refl _
  · exact .step hc (.refl c)

/-! ## The Git projection -/

/-- A changeset entry on main after version `u`: the landed commit, its landing time and
its touched paths (Part II, Definition 13.1). -/
structure ChangesetEntry where
  landed : CommitId
  time : Nat
  W : Access

/-- A Git commit, as the data its bytes encode. Equal data gives an equal identifier
(content addressing with no collision, Part II's collision assumption), so a commit is
identified with its data. -/
inductive GitCommit where
  /-- The commit `h_u` that main held at version `u`. -/
  | base (id : CommitId)
  /-- A projected commit: tree, first parent, second parent (the landed commit), author,
  time and message. -/
  | commit (tree : State) (parent : GitCommit) (landed : CommitId) (author : String)
      (time : Nat) (message : CommitId × Nat)

/-- The platform's constant author. -/
def platformAuthor : String := "platform"

/-- The tree of a Git commit; `treeOf` gives the tree of a commit identifier. -/
def GitCommit.tree (treeOf : CommitId → State) : GitCommit → State
  | .base id => treeOf id
  | .commit t .. => t

/-- The first parent of a projected commit. The base's history lies before `u` and is
not modelled. -/
def GitCommit.firstParent : GitCommit → Option GitCommit
  | .base _ => none
  | .commit _ p .. => some p

/-- The Git projection `P(j)` (Part II, Definition 13.1). Index `j` counts changeset
entries after `u`, so `P(0) = h_u`. -/
def project (treeOf : CommitId → State) (h : CommitId) (log : List ChangesetEntry) :
    Nat → GitCommit
  | 0 => .base h
  | j + 1 =>
    match log[j]? with
    | none => project treeOf h log j
    | some e =>
      .commit (overlay ((project treeOf h log j).tree treeOf) (treeOf e.landed) e.W)
        (project treeOf h log j) e.landed platformAuthor e.time (e.landed, j + 1)

variable {treeOf : CommitId → State} {h : CommitId}

/-- Part II, Lemma 13.2 (determinism of the projection): `P(j)` is a function of the log
prefix `e_1, …, e_j`. Two projectors that read the same prefix compute the same
commit, and a projection rebuilt after a crash reproduces it. -/
theorem projection_deterministic {log log' : List ChangesetEntry} {j : Nat}
    (hpre : log.take j = log'.take j) :
    project treeOf h log j = project treeOf h log' j := by
  have hget : ∀ i, i < j → log[i]? = log'[i]? := by
    intro i hi
    have := congrArg (fun l => l[i]?) hpre
    simpa [List.getElem?_take, hi] using this
  clear hpre
  induction j with
  | zero => rfl
  | succ j ih =>
    have ih' := ih fun i hi => hget i (by omega)
    have hj := hget j (by omega)
    simp only [project, hj, ih']

/-- Appending entries never changes an earlier projection. -/
theorem projection_stable {log more : List ChangesetEntry} {j : Nat} (hj : j ≤ log.length) :
    project treeOf h (log ++ more) j = project treeOf h log j :=
  projection_deterministic (by rw [List.take_append_of_le_length hj])

/-- Part II, Lemma 13.2 / Part I, Assumption 8.2: when entry `j + 1` exists, the first
parent of `P(j + 1)` is `P(j)`. -/
theorem projection_first_parent {log : List ChangesetEntry} {j : Nat} {e : ChangesetEntry}
    (he : log[j]? = some e) :
    (project treeOf h log (j + 1)).firstParent = some (project treeOf h log j) := by
  simp [project, he, GitCommit.firstParent]

/-- The projected tree is the previous tree with the landed commit's entries on `W`. -/
theorem projection_tree {log : List ChangesetEntry} {j : Nat} {e : ChangesetEntry}
    (he : log[j]? = some e) :
    (project treeOf h log (j + 1)).tree treeOf =
      overlay ((project treeOf h log j).tree treeOf) (treeOf e.landed) e.W := by
  simp [project, he, GitCommit.tree]

/-- First-parent chains of Git commits. -/
inductive GitChain : GitCommit → GitCommit → Prop where
  | refl (x : GitCommit) : GitChain x x
  | step {y z x : GitCommit} : y.firstParent = some z → GitChain z x → GitChain y x

/-- Part I, Proposition 8.3(5): the projected commit at `u` is a first-parent ancestor of
the projected commit at every later `v`. -/
theorem projection_chain {log : List ChangesetEntry} {u : Nat} :
    ∀ v, u ≤ v → GitChain (project treeOf h log v) (project treeOf h log u) := by
  intro v huv
  induction v with
  | zero => rw [Nat.le_zero.1 huv]; exact .refl _
  | succ v ih =>
    rcases Nat.lt_or_ge v u with hvu | hvu
    · have : u = v + 1 := by omega
      subst this; exact .refl _
    · cases he : log[v]? with
      | none =>
        have : project treeOf h log (v + 1) = project treeOf h log v := by
          simp [project, he]
        rw [this]; exact ih hvu
      | some e => exact .step (projection_first_parent he) (ih hvu)

end YonedaTx
