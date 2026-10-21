import YonedaTx.Serializability

/-!
# The land combiner: batches

Part I, Definition 7.1 (land combiner), Theorem 7.2 property 4, Theorem 7.3 (batch
write skew) and Proposition 7.4 (serializable batches).

A batch lands several members in one entry. Each member was built on its own base
snapshot and is merged against the current head; the octopus merge combines those
merged changes into one state.
-/

namespace YonedaTx

/-- A batch member: a transaction and the snapshot it was built on. -/
structure Member where
  txn : Txn
  base : State

/-- The octopus merge: start from the head `H` and, at each location, take the first
merged change that differs from the head there. When members' merged changes touch
disjoint locations (the adapter's deferral rule), the order does not matter. -/
def octopus (H : State) : List State → State
  | [] => H
  | M :: Ms => fun p => if M p ≠ H p then M p else octopus H Ms p

/-- A member's change merged against the head (three-way, file level). -/
def mergedChange (H : State) (m : Member) : State := landOn m.base H (m.txn.f m.base)

/-- The state a batch entry installs (Definition 7.1, Land batch with a merge). -/
def landBatch (H : State) (ms : List Member) : State := octopus H (ms.map (mergedChange H))

/-- Landing the members one at a time, in ticket order. -/
def seqLand (H : State) (ms : List Member) : State :=
  ms.foldl (fun s m => landOn m.base s (m.txn.f m.base)) H

/-- Serial execution of transactions in the given order. -/
def serialTxns (H : State) (cs : List Txn) : State := cs.foldl (fun s c => c.f s) H

/-- Serial execution of the members in ticket order, each member's change resolved
against the state so far by the file-level three-way merge. -/
def serialMerge (H : State) (ms : List Member) : State :=
  ms.foldl (fun s m => merge3State m.base s (m.txn.f m.base)) H

/-- The batch member a log entry contributes: its transaction and its base snapshot. -/
def toMember (init : State) (log : Log) (e : Entry) : Member := ⟨e.txn, snap init log e.base⟩

/-- The rule of Proposition 7.4, for a later member `cj` and an earlier member `ci`:
`(R_j ∪ W_j) ⋈̸ W_i`. -/
def BatchRule (ci cj : Txn) : Prop := meetsSet (cj.R ++ cj.W) ci.W = false

/-- Theorem 7.2, property 4: a member accepted by the combiner (validated against the log,
not a Conflict) read the values current at the head it lands on. -/
theorem combiner_member_reads {init : State} {log : Log} {n b : Nat} {c : Txn} (hb : b ≤ n)
    (h : validateAt log n c.R c.W b ≠ .conflict) :
    Agree c.R (snap init log b) (snap init log n) :=
  reads_current hb h

/-! ## Batches with file-level merges -/

theorem octopus_const {H : State} {Ms : List State} {p : Path}
    (h : ∀ M ∈ Ms, M p = H p) : octopus H Ms p = H p := by
  induction Ms with
  | nil => rfl
  | cons M Ms ih =>
    simp only [octopus, h M List.mem_cons_self, ne_eq, not_true_eq_false, ite_false]
    exact ih fun M' hM' => h M' (List.mem_cons_of_mem _ hM')

/-- The octopus merge at `p` depends only on the values at `p`. -/
theorem octopus_congr {α : Type} {G H : State} {cs : List α} {g h : α → State} {p : Path}
    (hGH : G p = H p) (hgh : ∀ c ∈ cs, g c p = h c p) :
    octopus G (cs.map g) p = octopus H (cs.map h) p := by
  induction cs with
  | nil => exact hGH
  | cons c cs ih =>
    simp only [List.map_cons, octopus]
    rw [hgh c List.mem_cons_self, hGH,
      ih fun c' hc' => hgh c' (List.mem_cons_of_mem _ hc')]

/-- Pairwise disjoint write sets, in ticket order. -/
def WritesDisjoint (ms : List Member) : Prop :=
  ms.Pairwise fun mi mj => meetsSet mi.txn.W mj.txn.W = false

/-- With pairwise disjoint write sets, the batch entry (one octopus merge against the
head) installs the same state as landing the members one at a time in ticket order. -/
theorem landBatch_eq_seqLand (ms : List Member) (hW : WritesDisjoint ms) (H : State) :
    landBatch H ms = seqLand H ms := by
  induction ms generalizing H with
  | nil => rfl
  | cons m ms ih =>
    obtain ⟨hm, hms⟩ := List.pairwise_cons.1 hW
    show _ = seqLand (mergedChange H m) ms
    rw [← ih hms]
    funext p
    simp only [landBatch, List.map_cons, octopus]
    cases hcov : covered m.txn.W p
    · -- `m` leaves `p` alone, so the later members see the same head value at `p`
      have e : mergedChange H m p = H p := landOn_of_unchanged (m.txn.frame _ p hcov)
      rw [e]
      simp only [ne_eq, not_true_eq_false, ite_false]
      exact octopus_congr e.symm fun m' _ => landOn_congr_head e.symm
    · -- `m` covers `p`, so no later member does and their merged changes keep the head
      have hnot : ∀ m' ∈ ms, covered m'.txn.W p = false := fun m' hm' =>
        not_covered_of_disjoint (by rw [meetsSet_symm]; exact hm m' hm') hcov
      have r₁ : octopus H (ms.map (mergedChange H)) p = H p :=
        octopus_const fun M hM => by
          obtain ⟨m', hm', rfl⟩ := List.mem_map.1 hM
          exact landOn_of_unchanged (m'.txn.frame _ p (hnot m' hm'))
      have r₂ : octopus (mergedChange H m) (ms.map (mergedChange (mergedChange H m))) p =
          mergedChange H m p :=
        octopus_const fun M hM => by
          obtain ⟨m', hm', rfl⟩ := List.mem_map.1 hM
          exact landOn_of_unchanged (m'.txn.frame _ p (hnot m' hm'))
      rw [r₁, r₂]
      by_cases hne : mergedChange H m p = H p <;> simp [hne]

/-- With pairwise disjoint write sets and no conflict path against the head, every
sequential landing is conflict-free and installs the three-way merge. -/
theorem seqLand_eq_serialMerge (ms : List Member) (hW : WritesDisjoint ms) (H : State)
    (hnc : ∀ m ∈ ms, ∀ p, ¬ ConflictAt m.base H (m.txn.f m.base) p) :
    seqLand H ms = serialMerge H ms := by
  induction ms generalizing H with
  | nil => rfl
  | cons m ms ih =>
    obtain ⟨hm, hms⟩ := List.pairwise_cons.1 hW
    show seqLand (landOn m.base H (m.txn.f m.base)) ms =
      serialMerge (merge3State m.base H (m.txn.f m.base)) ms
    rw [← landOn_eq_merge3State (hnc m List.mem_cons_self)]
    apply ih hms
    intro m' hm' p hc
    cases hcov : covered m'.txn.W p
    · exact hc.2.1 (m'.txn.frame _ p hcov)
    · -- the new head equals `H` wherever `m'` writes
      have e : landOn m.base H (m.txn.f m.base) p = H p :=
        landOn_of_unchanged (m.txn.frame _ p (not_covered_of_disjoint (hm m' hm') hcov))
      obtain ⟨h₁, h₂, h₃⟩ := hc
      rw [e] at h₁ h₃
      exact hnc m' (List.mem_cons_of_mem _ hm') p ⟨h₁, h₂, h₃⟩

/-- A batch with pairwise disjoint write sets and no conflict path against the head
installs serial execution in ticket order with file-level merges resolved by `merge3`. -/
theorem batch_merge_sound (ms : List Member) (hW : WritesDisjoint ms) (H : State)
    (hnc : ∀ m ∈ ms, ∀ p, ¬ ConflictAt m.base H (m.txn.f m.base) p) :
    landBatch H ms = serialMerge H ms :=
  (landBatch_eq_seqLand ms hW H).trans (seqLand_eq_serialMerge ms hW H hnc)

/-! ## Merged members as serial steps -/

/-- Member `m` is patch-compatible with state `H` when running its transaction on `H`
gives, on its write set, its diff against its own base applied to `H`. -/
def PatchCompatible (m : Member) (H : State) : Prop :=
  ∀ p, covered m.txn.W p = true → m.txn.f H p = applyDiff m.base (m.txn.f m.base) H p

/-- Exact condition: a conflict-free merge of member `m` into `H` equals running its
transaction on `H` iff `m` is patch-compatible with `H`. -/
theorem merge_serial_iff (m : Member) (H : State)
    (hnc : ∀ p, ¬ ConflictAt m.base H (m.txn.f m.base) p) :
    merge3State m.base H (m.txn.f m.base) = m.txn.f H ↔ PatchCompatible m H := by
  rw [merge3State_eq_applyDiff hnc]
  constructor
  · intro h p _; rw [← h]
  · intro h; funext p
    cases hp : covered m.txn.W p
    · simp [applyDiff, m.txn.frame _ p hp]
    · exact (h p hp).symm

/-- FastForward and Rebase members are patch-compatible: their base and the head agree
on everything they read or write. -/
theorem patchCompatible_of_agree {m : Member} {H : State}
    (h : Agree (m.txn.R ++ m.txn.W) m.base H) : PatchCompatible m H := by
  intro p hp
  have hBH : m.base p = H p := h p (by simp [region_of_covered hp])
  rw [← m.txn.reads _ _ h p hp]
  unfold applyDiff
  split
  · next he => rw [he, hBH]
  · rfl

/-- For a changeset (a blind write of `Φ` on `W`), patch-compatibility says exactly that
every written path whose new content equals the base content was not moved by the
head either: the changeset never writes a stale base value back over a newer one. -/
theorem changeset_patchCompatible_iff {R W : Access} {Φ B H : State} :
    PatchCompatible ⟨Txn.changeset R W Φ, B⟩ H ↔
      ∀ p, covered W p = true → Φ p = B p → H p = B p := by
  simp only [PatchCompatible, Txn.changeset, applyDiff, overlay]
  constructor
  · intro h p hp hΦ
    have := h p hp
    simp only [hp, ite_true, hΦ] at this
    exact this.symm
  · intro h p hp
    simp only [hp, ite_true]
    split
    · next hΦ => rw [h p hp hΦ, hΦ]
    · rfl

/-- For a patch acting on `D ⊑ W`, patch-compatibility says that no location it sets to
its base content was moved by the head. -/
theorem patch_patchCompatible_iff {R W D : Access} {Φ B H : State} {hD : Coarsens W D} :
    PatchCompatible ⟨Txn.patch R W D Φ hD, B⟩ H ↔
      ∀ p, covered D p = true → Φ p = B p → H p = B p := by
  simp only [PatchCompatible, Txn.patch, applyDiff, overlay]
  constructor
  · intro h p hp hΦ
    have := h p (covered_coarsen hD hp)
    simp only [hp, ite_true, hΦ] at this
    exact this.symm
  · intro h p _
    by_cases hp : covered D p = true
    · simp only [hp, ite_true]
      split
      · next hΦ => rw [h p hp hΦ, hΦ]
      · rfl
    · simp [hp]

/-- Under the pairwise rule, conflict-free merges of patch-compatible members are the
serial steps: `serialMerge` is serial execution of the transactions in ticket order. -/
theorem serialMerge_eq_serialTxns (ms : List Member)
    (hrule : (ms.map (·.txn)).Pairwise BatchRule) (H : State)
    (hnc : ∀ m ∈ ms, ∀ p, ¬ ConflictAt m.base H (m.txn.f m.base) p)
    (hpc : ∀ m ∈ ms, PatchCompatible m H) :
    serialMerge H ms = serialTxns H (ms.map (·.txn)) := by
  induction ms generalizing H with
  | nil => rfl
  | cons m ms ih =>
    simp only [List.map_cons, List.pairwise_cons, List.mem_map] at hrule
    obtain ⟨hc, hcs⟩ := hrule
    show serialMerge (merge3State m.base H (m.txn.f m.base)) ms = serialTxns (m.txn.f H) _
    rw [(merge_serial_iff m H (hnc m List.mem_cons_self)).2 (hpc m List.mem_cons_self)]
    -- later members read and write nothing `m` wrote, so they see `H` and `m.f H` alike
    have hag : ∀ m' ∈ ms, Agree (m'.txn.R ++ m'.txn.W) H (m.txn.f H) := fun m' hm' =>
      agree_of_changesWithin (m.txn.changesWithin H) (hc m'.txn ⟨m', hm', rfl⟩)
    have hsame : ∀ m' ∈ ms, ∀ p, covered m'.txn.W p = true → m.txn.f H p = H p :=
      fun m' hm' p hp => ((hag m' hm') p (by simp [region_of_covered hp])).symm
    apply ih hcs
    · intro m' hm' p hcf
      cases hcov : covered m'.txn.W p
      · exact hcf.2.1 (m'.txn.frame _ p hcov)
      · obtain ⟨h₁, h₂, h₃⟩ := hcf
        rw [hsame m' hm' p hcov] at h₁ h₃
        exact hnc m' (List.mem_cons_of_mem _ hm') p ⟨h₁, h₂, h₃⟩
    · intro m' hm' p hp
      rw [← m'.txn.reads _ _ (hag m' hm') p hp, hpc m' (List.mem_cons_of_mem _ hm') p hp]
      simp only [applyDiff, hsame m' hm' p hp]

/-! ## Proposition 7.4 -/


/-- Under the rule, the octopus merge of every member run on the head equals serial
execution in ticket order. -/
theorem octopus_eq_serial (cs : List Txn) (hrule : cs.Pairwise BatchRule) (H : State) :
    octopus H (cs.map fun c => c.f H) = serialTxns H cs := by
  induction cs generalizing H with
  | nil => rfl
  | cons c cs ih =>
    obtain ⟨hc, hcs⟩ := List.pairwise_cons.1 hrule
    show _ = serialTxns (c.f H) cs
    rw [← ih hcs (c.f H)]
    funext p
    -- each later member reads and writes nothing `c` wrote
    have hag : ∀ c' ∈ cs, Agree (c'.R ++ c'.W) H (c.f H) := fun c' hc' =>
      agree_of_changesWithin (c.changesWithin H) (hc c' hc')
    simp only [List.map_cons, octopus]
    cases hcov : covered c.W p
    · -- `c` leaves `p` alone; the other members see the same value at `p`
      rw [c.frame H p hcov]
      simp only [ne_eq, not_true_eq_false, ite_false]
      refine (octopus_congr (c.frame H p hcov) fun c' hc' => ?_).symm
      cases hcov' : covered c'.W p
      · rw [c'.frame _ p hcov', c'.frame _ p hcov', c.frame H p hcov]
      · exact (c'.reads _ _ (hag c' hc') p hcov').symm
    · -- `c` covers `p`, so no later member does
      have hnot : ∀ c' ∈ cs, covered c'.W p = false := by
        intro c' hc'
        cases hcov' : covered c'.W p
        · rfl
        · have h₁ : meetsSet (c'.R ++ c'.W) c.W = false := hc c' hc'
          rw [meetsSet_append_left, Bool.or_eq_false_iff,
            meetsSet_of_covered hcov' hcov] at h₁
          exact absurd h₁.2 (by simp)
      have r₁ : octopus H (cs.map fun c' => c'.f H) p = H p :=
        octopus_const fun M hM => by
          obtain ⟨c', hc', rfl⟩ := List.mem_map.1 hM
          exact c'.frame H p (hnot c' hc')
      have r₂ : octopus (c.f H) (cs.map fun c' => c'.f (c.f H)) p = c.f H p :=
        octopus_const fun M hM => by
          obtain ⟨c', hc', rfl⟩ := List.mem_map.1 hM
          exact c'.frame _ p (hnot c' hc')
      rw [r₁, r₂]
      by_cases hne : c.f H p = H p
      · simp [hne]
      · simp [hne]

/-- Sequential landing in ticket order equals serial execution, when each member's
reads and writes agree between its base and the head, and the rule holds. -/
theorem seqLand_eq_serial (ms : List Member) (hrule : (ms.map (·.txn)).Pairwise BatchRule)
    (H : State) (hval : ∀ m ∈ ms, Agree (m.txn.R ++ m.txn.W) m.base H) :
    seqLand H ms = serialTxns H (ms.map (·.txn)) := by
  induction ms generalizing H with
  | nil => rfl
  | cons m ms ih =>
    simp only [List.map_cons, List.pairwise_cons, List.mem_map] at hrule
    obtain ⟨hc, hcs⟩ := hrule
    show seqLand (landOn m.base H (m.txn.f m.base)) ms = serialTxns (m.txn.f H) _
    rw [landOn_eq_apply m.txn (hval m List.mem_cons_self)]
    apply ih hcs
    intro m' hm'
    exact (hval m' (List.mem_cons_of_mem _ hm')).trans
      (agree_of_changesWithin (m.txn.changesWithin H) (hc m'.txn ⟨m', hm', rfl⟩))

/-- Proposition 7.4 (serializable batches). Suppose every member's reads and writes
agree between its base and the head (which a FastForward or Rebase validation against
the log gives, see `batch_serializable_log`) and the members, in ticket order, satisfy
`(R_j ∪ W_j) ⋈̸ W_i` for all `i < j`. Then the batch entry installs the same state as
landing the members one at a time in ticket order, and that state is serial execution
in ticket order. -/
theorem batch_serializable (ms : List Member) (hrule : (ms.map (·.txn)).Pairwise BatchRule)
    (H : State) (hval : ∀ m ∈ ms, Agree (m.txn.R ++ m.txn.W) m.base H) :
    landBatch H ms = seqLand H ms ∧ landBatch H ms = serialTxns H (ms.map (·.txn)) := by
  have hb : landBatch H ms = serialTxns H (ms.map (·.txn)) := by
    unfold landBatch
    have : ms.map (mergedChange H) = (ms.map (·.txn)).map (fun c => c.f H) := by
      rw [List.map_map]
      exact List.map_congr_left fun m hm => landOn_eq_apply m.txn (hval m hm)
    rw [this]
    exact octopus_eq_serial _ hrule H
  exact ⟨hb.trans (seqLand_eq_serial ms hrule H hval).symm, hb⟩

/-- Proposition 7.4, part 1, validation half: under the rule, landing a member after the
earlier members would not be a Conflict, and a clean outcome stays clean. -/
theorem batch_sequential_validates {later earlier : List Access} {R W : Access}
    (hrule : ∀ Wi ∈ earlier, meetsSet (R ++ W) Wi = false)
    (hc : validate later R W ≠ .conflict) :
    validate (later ++ earlier) R W ≠ .conflict ∧
    ((validate later R W).clean = true → (validate (later ++ earlier) R W).clean = true) := by
  have hR : ∀ Wv ∈ later ++ earlier, meetsSet R Wv = false := by
    intro Wv hm
    rcases List.mem_append.1 hm with hm | hm
    · exact no_stale_read hc Wv hm
    · have := hrule Wv hm; simp at this; exact this.1
  refine ⟨fun h => ?_, fun hcl => ?_⟩
  · obtain ⟨Wv, hm, hv⟩ := validate_eq_conflict_iff.1 h
    rw [hR Wv hm] at hv; cases hv
  · have hW : ∀ Wv ∈ later ++ earlier, meetsSet W Wv = false := by
      intro Wv hm
      rcases List.mem_append.1 hm with hm | hm
      · exact no_write_overlap hcl Wv hm
      · have := hrule Wv hm; simp at this; exact this.2
    cases hl : later ++ earlier with
    | nil => rfl
    | cons W₀ rest =>
      have : validate (later ++ earlier) R W = .rebase :=
        validate_eq_rebase_iff.2 ⟨by simp [hl], fun Wv hm => ⟨hR Wv hm, hW Wv hm⟩⟩
      rw [← hl, this]; rfl

/-- Proposition 7.4 in log terms: members are log entries (a transaction and a base
version), each validated FastForward or Rebase against the log at head `n`. -/
theorem batch_serializable_log {init : State} {log : Log} {n : Nat} (ms : List Entry)
    (hrule : ms.Pairwise fun ei ej => BatchRule ei.txn ej.txn)
    (hval : ∀ e ∈ ms, e.base ≤ n ∧ (validateAt log n e.txn.R e.txn.W e.base).clean = true) :
    landBatch (snap init log n) (ms.map (toMember init log)) =
      serialTxns (snap init log n) (ms.map (·.txn)) := by
  have h := (batch_serializable (ms.map (toMember init log)) (by
      rw [List.map_map]; exact List.pairwise_map.2 hrule) (snap init log n) (by
      intro m hm
      obtain ⟨e, he, rfl⟩ := List.mem_map.1 hm
      exact clean_agree (hval e he).1 (hval e he).2)).2
  rw [h, List.map_map]
  rfl

/-! ## Theorem 7.3: batch write skew -/

namespace WriteSkew

def pX : Path := ["x"]
def pY : Path := ["y"]
def pZ : Path := ["z"]

/-- The head before the batch: `x = 0`, `y = 0`. -/
def s0 : State := fun p => if p = pX then some 0 else if p = pY then some 0 else none

/-- `c_0` writes only `z`; it lands as a fast-forward at version 1. -/
def c0 : Txn := Txn.write1 [] pZ (fun _ => some 1) (fun _ _ _ => rfl)

/-- `c_a` reads `x` and writes `y := x + 1`. -/
def ca : Txn := Txn.write1 [pX] pY (fun s => some ((s pX).getD 0 + 1))
  (fun s t h => by rw [h pX (by decide)])

/-- `c_b` reads `y` and writes `x := y + 1`. -/
def cb : Txn := Txn.write1 [pY] pX (fun s => some ((s pY).getD 0 + 1))
  (fun s t h => by rw [h pY (by decide)])

/-- The log after `c_0`. -/
def log : Log := [⟨c0, 0⟩]

theorem snap0 : snap s0 log 0 = s0 := snap_zero _ _

theorem snap1 : snap s0 log 1 = c0.f s0 := by
  rw [snap_succ (e := ⟨c0, 0⟩) rfl (Nat.le_refl 0), snap_zero, landOn_self]

end WriteSkew

open WriteSkew in
/-- Theorem 7.3 (batch write skew). In a concrete history, the combiner validates `c_a`
and `c_b` only against the log: both are Rebase, their write sets are disjoint (so the
adapter's deferral rule accepts both), and both land in one batch entry. Yet
`R_a ⋈ W_b` and `R_b ⋈ W_a` (a G2-item cycle of anti-dependencies), the batch state is
neither serial order, and in each serial order the second member would read a value
of its declared set different from the one it read; landing them one at a time, the
second would be refused as a Conflict. -/
theorem batch_write_skew :
    let H := snap s0 log 1
    let B := snap s0 log 0
    let batch := landBatch H [⟨ca, B⟩, ⟨cb, B⟩]
    validateAt log 1 ca.R ca.W 0 = .rebase ∧
    validateAt log 1 cb.R cb.W 0 = .rebase ∧
    meetsSet ca.W cb.W = false ∧
    meetsSet ca.R cb.W = true ∧ meetsSet cb.R ca.W = true ∧
    batch ≠ serialTxns H [ca, cb] ∧
    batch ≠ serialTxns H [cb, ca] ∧
    ca.f H pY ≠ B pY ∧ cb.f H pX ≠ B pX ∧
    validate (laterWrites log 0 1 ++ [ca.W]) cb.R cb.W = .conflict ∧
    validate (laterWrites log 0 1 ++ [cb.W]) ca.R ca.W = .conflict := by
  intro H B batch
  have hH : H = c0.f s0 := snap1
  have hB : B = s0 := snap0
  refine ⟨by decide, by decide, by decide, by decide, by decide, ?_, ?_, ?_, ?_, by decide,
    by decide⟩
  · intro h
    have := congrFun h pX
    simp only [batch, hH, hB] at this
    revert this; decide
  · intro h
    have := congrFun h pY
    simp only [batch, hH, hB] at this
    revert this; decide
  · rw [hH, hB]; decide
  · rw [hH, hB]; decide

end YonedaTx
