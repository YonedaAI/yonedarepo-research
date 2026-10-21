import YonedaTx.Merge

/-!
# The transaction log and snapshots

Part I, Definitions 4.8–4.11 (log entry, log, snapshot) restricted to one ref, and
Lemma 6.3 (frame).

Versions are 1-based as in the paper: the entry at list index `i` has version `i + 1`,
and `snap init log v` is the tree state of the ref at version `v`, with
`snap init log 0 = init`. An entry records the transaction it lands and its base
version. The entry with version `v + 1` is built on `snap init log base` and lands on
the head `snap init log v` by the three-way merge `landOn`.
-/

namespace YonedaTx

/-- A log entry: the landed transaction and its base version (Part I, Definition 4.8). -/
structure Entry where
  txn : Txn
  base : Nat

/-- A log on one ref, in version order: index `i` holds version `i + 1`. -/
abbrev Log := List Entry

/-- Snapshot at version `n`: the fold of entries `1..n` from `init`. Each entry lands
its change, computed on the snapshot at its base, onto the previous snapshot. The base
is capped at `n`, as the authority caps it at landing (Definition 4.16). -/
def snap (init : State) (log : Log) : Nat → State
  | 0 => init
  | n + 1 =>
    match log[n]? with
    | none => snap init log n
    | some e =>
      landOn (snap init log (min e.base n)) (snap init log n)
        (e.txn.f (snap init log (min e.base n)))
termination_by n => n
decreasing_by all_goals omega

variable {init : State} {log : Log}

@[simp] theorem snap_zero (init : State) (log : Log) : snap init log 0 = init := by
  rw [snap]

theorem snap_succ_none {n : Nat} (h : log[n]? = none) :
    snap init log (n + 1) = snap init log n := by
  rw [snap]; simp [h]

theorem snap_succ_some {n : Nat} {e : Entry} (h : log[n]? = some e) :
    snap init log (n + 1) =
      landOn (snap init log (min e.base n)) (snap init log n)
        (e.txn.f (snap init log (min e.base n))) := by
  rw [snap]; simp [h]

/-- The landing step with an uncapped base. -/
theorem snap_succ {n : Nat} {e : Entry} (h : log[n]? = some e) (hb : e.base ≤ n) :
    snap init log (n + 1) =
      landOn (snap init log e.base) (snap init log n) (e.txn.f (snap init log e.base)) := by
  rw [snap_succ_some h, Nat.min_eq_left hb]

/-- Snapshots up to `k` depend only on the entries with versions up to `k`. -/
theorem snap_congr {log log' : Log} {k : Nat} (h : ∀ i, i < k → log[i]? = log'[i]?) :
    ∀ j, j ≤ k → snap init log j = snap init log' j := by
  induction k with
  | zero => intro j hj; rw [Nat.le_zero.1 hj]; simp
  | succ k ih =>
    have ih' := ih (fun i hi => h i (by omega))
    intro j hj
    rcases Nat.lt_or_ge j (k + 1) with hj' | hj'
    · exact ih' j (by omega)
    · have hjk : j = k + 1 := by omega
      subst hjk
      have hk := h k (by omega)
      cases hl : log[k]? with
      | none =>
        rw [hl] at hk
        rw [snap_succ_none hl, snap_succ_none hk.symm, ih' k (Nat.le_refl k)]
      | some e =>
        rw [hl] at hk
        rw [snap_succ_some hl, snap_succ_some hk.symm, ih' k (Nat.le_refl k),
          ih' _ (Nat.min_le_right _ _)]

/-- Appending entries does not change earlier snapshots (Theorem 5.6, snapshot
immutability, for tree states). -/
theorem snap_append (pre rest : Log) {k : Nat} (hk : k ≤ pre.length) :
    snap init (pre ++ rest) k = snap init pre k :=
  snap_congr (k := pre.length)
    (fun _ hi => List.getElem?_append_left hi) k hk

/-- Every snapshot is a function of its version alone: two equal prefixes give the
same snapshot. -/
theorem snap_of_take_eq {log log' : Log} {k : Nat} (h : log.take k = log'.take k) :
    snap init log k = snap init log' k := by
  apply snap_congr (k := k) _ k (Nat.le_refl k)
  intro i hi
  have := congrArg (fun l => l[i]?) h
  simpa [List.getElem?_take, hi] using this

/-! ## Later entries -/

/-- The write sets of the entries with versions in `(b, n]` (the paper's `Later(P)`). -/
def laterWrites (log : Log) (b n : Nat) : List Access := ((log.take n).drop b).map (·.txn.W)

theorem mem_laterWrites {b n i : Nat} {e : Entry} (hb : b ≤ i) (hn : i < n)
    (h : log[i]? = some e) : e.txn.W ∈ laterWrites log b n := by
  apply List.mem_map.2 ⟨e, ?_, rfl⟩
  apply List.mem_of_getElem? (i := i - b)
  rw [List.getElem?_drop, List.getElem?_take, Nat.add_sub_cancel' hb]
  simp [hn, h]

theorem laterWrites_self (log : Log) (n : Nat) : laterWrites log n n = [] := by
  simp [laterWrites]

/-- Appending entries does not change the later entries of an earlier head. -/
theorem laterWrites_append_le (log ms : Log) {b i : Nat} (hi : i ≤ log.length) :
    laterWrites (log ++ ms) b i = laterWrites log b i := by
  simp [laterWrites, List.take_append_of_le_length hi]

/-- The later entries of the `j`-th appended entry, for a base in `log`: those of `log`
after the base, then the first `j` appended entries. -/
theorem laterWrites_append_batch (log ms : Log) {b : Nat} (j : Nat) (hb : b ≤ log.length) :
    laterWrites (log ++ ms) b (log.length + j) =
      laterWrites log b log.length ++ (ms.take j).map (·.txn.W) := by
  unfold laterWrites
  rw [List.take_append, List.take_of_length_le (by omega), Nat.add_sub_cancel_left,
    List.drop_append_of_le_length hb, List.take_of_length_le (Nat.le_refl _), List.map_append]

/-! ## Frame lemma -/

/-- One landing changes the snapshot only within the landed write set. -/
theorem snap_step_changesWithin {n : Nat} {e : Entry} (h : log[n]? = some e) :
    ChangesWithin e.txn.W (snap init log n) (snap init log (n + 1)) := by
  rw [snap_succ_some h]
  exact landOn_changesWithin (e.txn.changesWithin _)

/-- Frame lemma, pointwise: a location that no entry in `(b, v]` covers keeps its
content from version `b` to version `v`. -/
theorem frame_point {b v : Nat} {p : Path} (hbv : b ≤ v)
    (h : ∀ i e, b ≤ i → i < v → log[i]? = some e → covered e.txn.W p = false) :
    snap init log v p = snap init log b p := by
  induction v with
  | zero => rw [Nat.le_zero.1 hbv]
  | succ v ih =>
    rcases Nat.lt_or_ge v b with hvb | hvb
    · have : b = v + 1 := by omega
      rw [this]
    · have ih' := ih hvb (fun i e hi hiv he => h i e hi (by omega) he)
      cases hl : log[v]? with
      | none => rw [snap_succ_none hl, ih']
      | some e => rw [snap_step_changesWithin hl p (h v e hvb (by omega) hl), ih']

/-- Lemma 6.3 (Frame). If `X` meets no write set of the entries with versions in `(b, v]`,
then `snap b ≡_X snap v`. -/
theorem frame_lemma {X : Access} {b v : Nat} (hbv : b ≤ v)
    (h : ∀ i e, b ≤ i → i < v → log[i]? = some e → meetsSet X e.txn.W = false) :
    Agree X (snap init log b) (snap init log v) := by
  intro p hp
  refine (frame_point hbv fun i e hi hiv he => ?_).symm
  cases hc : covered e.txn.W p
  · rfl
  · have := h i e hi hiv he
    rw [meetsSet_of_region_covered hp hc] at this
    exact absurd this (by simp)

/-- The frame lemma in the form validation supplies: no write set in `laterWrites`
meets `X`. -/
theorem frame_of_laterWrites {X : Access} {b v : Nat} (hbv : b ≤ v)
    (h : ∀ W ∈ laterWrites log b v, meetsSet X W = false) :
    Agree X (snap init log b) (snap init log v) :=
  frame_lemma hbv fun _ _ hi hv he => h _ (mem_laterWrites hi hv he)

end YonedaTx
