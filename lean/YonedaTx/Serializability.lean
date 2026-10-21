import YonedaTx.Validation

/-!
# Serializability relative to declared reads

Part I, Theorem 6.4 (serializability), Proposition 6.5 (merged writes) and Theorem 6.7
(independence is order-insensitive landing without merge).
-/

namespace YonedaTx

variable {init : State} {log : Log}

/-! ## Reads are current at the serialization point -/

/-- Theorem 6.4, part 1 (also Theorem 7.2, property 4): a landing that is not a Conflict
read, at its base, the values current just before its own entry. -/
theorem reads_current {n : Nat} {R W : Access} {b : Nat} (hb : b ≤ n)
    (h : validateAt log n R W b ≠ .conflict) :
    Agree R (snap init log b) (snap init log n) :=
  frame_of_laterWrites hb (no_stale_read h)

/-- A clean (FastForward or Rebase) landing: base and head agree on `R ∪ W`. -/
theorem clean_agree {n : Nat} {R W : Access} {b : Nat} (hb : b ≤ n)
    (h : (validateAt log n R W b).clean = true) :
    Agree (R ++ W) (snap init log b) (snap init log n) :=
  frame_of_laterWrites hb (clean_disjoint h)

/-- If base and head agree on `R ∪ W`, landing the change built on the base installs
exactly what running the transaction on the head would. -/
theorem landOn_eq_apply (c : Txn) {B H : State} (h : Agree (c.R ++ c.W) B H) :
    landOn B H (c.f B) = c.f H := by
  funext p
  rw [landOn_rebase (c.changesWithin B) (fun p hp => (h p (by simp [region_of_covered hp])).symm)]
  split
  · next hp => exact c.reads B H h p hp
  · next hp => exact (c.frame H p (by simpa using hp)).symm

/-! ## Serial execution -/

/-- Serial execution of the first `n` transactions of the log, in log order, each on the
state the previous one left. -/
def serial (init : State) (log : Log) (n : Nat) : State :=
  (log.take n).foldl (fun s e => e.txn.f s) init

theorem serial_succ {n : Nat} {e : Entry} (h : log[n]? = some e) :
    serial init log (n + 1) = e.txn.f (serial init log n) := by
  simp [serial, List.take_add_one, h]

/-- Theorem 6.4, part 2: a FastForward landing has base equal to the head version and
installs the change itself. -/
theorem fastForward_landing {n : Nat} {e : Entry} (he : log[n]? = some e) (hb : e.base ≤ n)
    (hff : validateAt log n e.txn.R e.txn.W e.base = .fastForward) :
    e.base = n ∧ snap init log (n + 1) = e.txn.f (snap init log n) := by
  have hn : n < log.length := by
    rcases Nat.lt_or_ge n log.length with h | h
    · exact h
    · rw [List.getElem?_eq_none h] at he; cases he
  have hempty : laterWrites log e.base n = [] := by
    revert hff
    unfold validateAt validate
    cases laterWrites log e.base n with
    | nil => intro _; rfl
    | cons W rest =>
      simp only [List.isEmpty_cons, Bool.false_eq_true, ite_false]
      split
      · intro h; cases h
      · split <;> intro h <;> cases h
  have hbn : e.base = n := by
    have := congrArg List.length hempty
    simp [laterWrites] at this
    omega
  refine ⟨hbn, ?_⟩
  rw [snap_succ he hb, hbn, landOn_self]

/-- Theorem 6.4, part 3: a Rebase landing installs the change on its write set and the
head elsewhere. -/
theorem rebase_landing {n : Nat} {e : Entry} (he : log[n]? = some e) (hb : e.base ≤ n)
    (hr : validateAt log n e.txn.R e.txn.W e.base = .rebase) (p : Path) :
    snap init log (n + 1) p =
      if covered e.txn.W p = true then e.txn.f (snap init log e.base) p
      else snap init log n p := by
  have hc : (validateAt log n e.txn.R e.txn.W e.base).clean = true := by rw [hr]; rfl
  have hag := (clean_agree (init := init) hb hc).right
  rw [snap_succ he hb]
  exact landOn_rebase (e.txn.changesWithin _)
    (fun p hp => (hag p (region_of_covered hp)).symm) p

/-- A landing whose reads and writes meet no write set landed after its base is the
serial step. -/
theorem disjoint_landing {n : Nat} {e : Entry} (he : log[n]? = some e) (hb : e.base ≤ n)
    (hd : ∀ W ∈ laterWrites log e.base n, meetsSet (e.txn.R ++ e.txn.W) W = false) :
    snap init log (n + 1) = e.txn.f (snap init log n) := by
  rw [snap_succ he hb]
  exact landOn_eq_apply e.txn (frame_of_laterWrites hb hd)

/-- Each clean landing step is the serial step. -/
theorem clean_landing {n : Nat} {e : Entry} (he : log[n]? = some e) (hb : e.base ≤ n)
    (hc : (validateAt log n e.txn.R e.txn.W e.base).clean = true) :
    snap init log (n + 1) = e.txn.f (snap init log n) :=
  disjoint_landing he hb (clean_disjoint hc)

/-- A clean landing has no conflict path: the head agrees with the base wherever the
change writes. Only the write check is used, so any declared read set `R` will do. -/
theorem no_conflict_path_of_clean {n b : Nat} {R : Access} {c : Txn} (hb : b ≤ n)
    (hc : (validateAt log n R c.W b).clean = true) (p : Path) :
    ¬ ConflictAt (snap init log b) (snap init log n) (c.f (snap init log b)) p := by
  rintro ⟨hHB, hCB, -⟩
  cases hcov : covered c.W p
  · exact hCB (c.frame _ p hcov)
  · exact hHB ((clean_agree hb hc).right p (region_of_covered hcov)).symm

/-- The primitive hypothesis of serializability: every entry's reads and writes meet no
write set landed after its base. -/
def LaterDisjoint (log : Log) : Prop :=
  ∀ i e, log[i]? = some e → e.base ≤ i ∧
    ∀ W ∈ laterWrites log e.base i, meetsSet (e.txn.R ++ e.txn.W) W = false

theorem Validated.laterDisjoint (hv : Validated log) : LaterDisjoint log := fun i e he =>
  ⟨(hv i e he).1, clean_disjoint (hv i e he).2⟩

/-- Serializability from `LaterDisjoint`: every snapshot is the serial execution, and each
transaction's reads at its base equal its reads in the serial order. -/
theorem serializability_of_laterDisjoint (hv : LaterDisjoint log) :
    (∀ n, snap init log n = serial init log n) ∧
    (∀ i e, log[i]? = some e →
      Agree e.txn.R (snap init log e.base) (serial init log i)) := by
  have hstates : ∀ n, snap init log n = serial init log n := by
    intro n
    induction n with
    | zero => simp [serial]
    | succ n ih =>
      cases he : log[n]? with
      | none =>
        rw [snap_succ_none he, ih]
        simp [serial, List.take_add_one, he]
      | some e =>
        obtain ⟨hb, hd⟩ := hv n e he
        rw [disjoint_landing he hb hd, serial_succ he, ih]
  refine ⟨hstates, fun i e he => ?_⟩
  obtain ⟨hb, hd⟩ := hv i e he
  rw [← hstates i]
  exact (frame_of_laterWrites hb hd).left

/-- Theorem 6.4 (serializability relative to declared reads). If every landing was
validated FastForward or Rebase, then (1) every snapshot equals the serial execution
of the log in log order, and (2) each transaction read, at its base, the same values
of its declared read set as it reads in that serial order. -/
theorem serializability (hv : Validated log) :
    (∀ n, snap init log n = serial init log n) ∧
    (∀ i e, log[i]? = some e →
      Agree e.txn.R (snap init log e.base) (serial init log i)) :=
  serializability_of_laterDisjoint hv.laterDisjoint

/-- Proposition 8.3, part 3 (changeset landing): a changeset validated FastForward or
Rebase is appended with effective change `Φ`: the new branch state is the previous one
with `Φ` applied on `W`. -/
theorem changeset_landing {n : Nat} {R W : Access} {Φ : State} {b : Nat}
    (he : log[n]? = some ⟨Txn.changeset R W Φ, b⟩) (hb : b ≤ n)
    (hc : (validateAt log n R W b).clean = true) :
    snap init log (n + 1) = overlay (snap init log n) Φ W :=
  clean_landing (e := ⟨Txn.changeset R W Φ, b⟩) he hb hc

/-! ## Proposition 6.5: merged writes -/

/-- Proposition 6.5 (merged writes), file level, for any landing. Outside `W` the landed
state is the head. On `W` minus the locations written by later entries it is the
change. Elsewhere it is the file-level three-way merge of base, head and change, which
is a value whenever the location is not a conflict path. -/
theorem merged_writes {n : Nat} {e : Entry} (he : log[n]? = some e) (hb : e.base ≤ n)
    (p : Path) :
    let B := snap init log e.base
    let H := snap init log n
    let C := e.txn.f B
    (covered e.txn.W p = false → snap init log (n + 1) p = H p) ∧
    (covered e.txn.W p = true → (∀ W' ∈ laterWrites log e.base n, covered W' p = false) →
      snap init log (n + 1) p = C p) ∧
    (¬ ConflictAt B H C p → merge3 B H C p = .ok (snap init log (n + 1) p)) := by
  intro B H C
  refine ⟨fun hp => snap_step_changesWithin he p hp, fun hp hl => ?_, fun hp => ?_⟩
  · have hBH : H p = B p :=
      frame_point hb fun _ _ hi hin he' => hl _ (mem_laterWrites hi hin he')
    rw [snap_succ he hb]
    show (merge3Cell (B p) (H p) (C p)).getD (C p) = C p
    rw [hBH, merge3Cell_base_left]; rfl
  · rw [snap_succ he hb]
    have hp' : merge3 B H C p ≠ .conflict := fun h => hp ((merge3_conflict_iff _ _ _ _).1 h)
    show merge3 B H C p = .ok ((merge3 B H C p).getD (C p))
    cases hm : merge3 B H C p with
    | ok v => rfl
    | conflict => exact absurd hm hp'

/-! ## Theorem 6.7: independence -/

/-- Theorem 6.7 (independence is order-insensitive landing without merge). Let `c_i` and
`c_j` share base `b`, with no other entry between `b` and their landings. If they satisfy
Eq. 1 then (1) the second to land is validated Rebase in either order, and (2) both
landing orders give the same state, namely both serial orders. -/
theorem independence {pre : Log} {b : Nat} {ci cj : Txn} (hpre : pre.length = b)
    (hind : Independent ci.R ci.W cj.R cj.W) :
    validateAt (pre ++ [⟨ci, b⟩, ⟨cj, b⟩]) (b + 1) cj.R cj.W b = .rebase ∧
    validateAt (pre ++ [⟨cj, b⟩, ⟨ci, b⟩]) (b + 1) ci.R ci.W b = .rebase ∧
    snap init (pre ++ [⟨ci, b⟩, ⟨cj, b⟩]) (b + 2) =
      snap init (pre ++ [⟨cj, b⟩, ⟨ci, b⟩]) (b + 2) ∧
    snap init (pre ++ [⟨ci, b⟩, ⟨cj, b⟩]) (b + 2) = cj.f (ci.f (snap init pre b)) ∧
    snap init (pre ++ [⟨cj, b⟩, ⟨ci, b⟩]) (b + 2) = ci.f (cj.f (snap init pre b)) := by
  have hv := (independence_iff_rebase _ _ _ _).1 hind
  -- The later entries of the second landing are exactly the first landing.
  have hlater : ∀ c c' : Txn,
      laterWrites (pre ++ [⟨c, b⟩, ⟨c', b⟩]) b (b + 1) = [c.W] := by
    intro c c'
    subst hpre
    simp [laterWrites, List.take_append]
  -- Landing two changes built on `snap b`, in order.
  have htwo : ∀ c c' : Txn, Agree (c'.R ++ c'.W) (snap init pre b) (c.f (snap init pre b)) →
      snap init (pre ++ [⟨c, b⟩, ⟨c', b⟩]) (b + 2) = c'.f (c.f (snap init pre b)) := by
    intro c c' hag
    have g₁ : (pre ++ [⟨c, b⟩, ⟨c', b⟩])[b]? = some ⟨c, b⟩ := by
      rw [List.getElem?_append_right (by omega)]; simp [hpre]
    have g₂ : (pre ++ [⟨c, b⟩, ⟨c', b⟩])[b + 1]? = some ⟨c', b⟩ := by
      rw [List.getElem?_append_right (by omega)]; simp [hpre]
    have s₀ : snap init (pre ++ [⟨c, b⟩, ⟨c', b⟩]) b = snap init pre b :=
      snap_append _ _ (by omega)
    have s₁ : snap init (pre ++ [⟨c, b⟩, ⟨c', b⟩]) (b + 1) = c.f (snap init pre b) := by
      rw [snap_succ g₁ (Nat.le_refl b)]; simp only [s₀, landOn_self]
    rw [snap_succ g₂ (Nat.le_succ b)]
    simp only [s₀, s₁]
    exact landOn_eq_apply c' hag
  have agij : Agree (cj.R ++ cj.W) (snap init pre b) (ci.f (snap init pre b)) :=
    agree_of_changesWithin (ci.changesWithin _) (by rw [meetsSet_symm]; exact hind.1)
  have agji : Agree (ci.R ++ ci.W) (snap init pre b) (cj.f (snap init pre b)) :=
    agree_of_changesWithin (cj.changesWithin _) (by rw [meetsSet_symm]; exact hind.2)
  refine ⟨by rw [validateAt, hlater]; exact hv.1, by rw [validateAt, hlater]; exact hv.2,
    ?_, htwo ci cj agij, htwo cj ci agji⟩
  rw [htwo ci cj agij, htwo cj ci agji]
  -- The two serial orders commute: their write sets are disjoint and neither reads
  -- what the other writes.
  funext p
  cases hi : covered ci.W p <;> cases hj : covered cj.W p
  · rw [cj.frame _ p hj, ci.frame _ p hi, ci.frame _ p hi, cj.frame _ p hj]
  · rw [cj.reads _ _ agij.symm p hj, ci.frame _ p hi]
  · rw [cj.frame _ p hj, ci.reads _ _ agji.symm p hi]
  · -- both cover `p`: then `W_i ⋈ W_j`, contradicting Eq. 1
    have h₁ := hind.1
    rw [meetsSet_symm, meetsSet_append_left, Bool.or_eq_false_iff, meetsSet_symm cj.W,
      meetsSet_of_covered hi hj] at h₁
    exact absurd h₁.2 (by simp)

end YonedaTx
