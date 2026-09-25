------------------------- MODULE HabitDaySettlement -------------------------
(***************************************************************************)
(* One habit on one day, across devices: who decides whether it was done. *)
(* A person records the day by hand, the auto-completion engine fills an   *)
(* empty day from a synced signal, sync delivers every row in any order,   *)
(* and each replica settles the day to one completion. That settled row is *)
(* what the habits page, streaks and every goal habit leaf read.           *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Write     a manual completion: the habits page, the completion sheet, *)
(*             or a goal day cell (GoalHabitCompletionService), all        *)
(*             through PersistenceLogic.createHabitCompletionEntry with    *)
(*             HabitCompletionSource.manual (the entity default)           *)
(*   Import    a signal the habit's rule reads (a measurement, a health    *)
(*             sample, a workout) landing on one device; it syncs like any *)
(*             other journal row                                           *)
(*   AutoFill  HabitAutoCompletionService._evaluateDay: on a device where  *)
(*             the signal is present and the day holds no completion at    *)
(*             all (private ones included), write an automatic success     *)
(*   Deliver   sync applying one row on a peer, in any order              *)
(*   Settled   latestHabitCompletionsByDay and its comparator, and the     *)
(*             ROW_NUMBER() ranking in getHabitCompletionRecordsInRange —  *)
(*             the two must agree. Order "recency" is the code before this *)
(*             spec: updatedAt, then createdAt and dateTo (equal to it for *)
(*             a fresh write), then id. "manualFirst" ranks any manual row *)
(*             above any automatic one, and recency within each            *)
(*                                                                         *)
(* Not modelled: clock skew (every write is stamped with one global        *)
(* clock), deletion, and the private flag's visibility.                    *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,          \* devices 1..N
    Order,      \* "recency" (before this spec) or "manualFirst"
    MaxTime,
    MaxManual   \* bound on manual writes across all devices

Devices == 1..N
Kinds == {"success", "skip", "fail"}
NoRow == [id |-> 0, at |-> 0, kind |-> "none", src |-> "none"]

VARIABLES
    now,
    journal,    \* per device: the completion rows it holds for the day
    signal,     \* per device: the signal the habit's rule reads is here
    imported,   \* the signal has landed somewhere
    net,        \* in-flight sync messages: [to, what ("row"/"signal"), row]
    nextId,
    manual      \* manual writes so far

vars == <<now, journal, signal, imported, net, nextId, manual>>

Row(id, at, kind, src) == [id |-> id, at |-> at, kind |-> kind, src |-> src]

Newer(a, b) == a.at > b.at \/ (a.at = b.at /\ a.id > b.id)

Rank(r) == IF Order = "manualFirst" /\ r.src = "manual" THEN 1 ELSE 0

\* A strict total order on distinct rows: ids are unique.
Beats(a, b) == Rank(a) > Rank(b) \/ (Rank(a) = Rank(b) /\ Newer(a, b))

\* The row every other row loses to. Only defined for a non-empty set.
Settled(rows) == CHOOSE r \in rows : \A o \in rows \ {r} : Beats(r, o)

SendRow(r, from) ==
    {[to |-> e, what |-> "row", row |-> r] : e \in Devices \ {from}}

Init ==
    /\ now = 0
    /\ journal = [d \in Devices |-> {}]
    /\ signal = [d \in Devices |-> FALSE]
    /\ imported = FALSE
    /\ net = {}
    /\ nextId = 1
    /\ manual = 0

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<journal, signal, imported, net, nextId, manual>>

Write(d, kind) ==
    /\ manual < MaxManual
    /\ LET r == Row(nextId, now, kind, "manual") IN
         /\ journal' = [journal EXCEPT ![d] = @ \cup {r}]
         /\ net' = net \cup SendRow(r, d)
    /\ nextId' = nextId + 1
    /\ manual' = manual + 1
    /\ UNCHANGED <<now, signal, imported>>

Import(d) ==
    /\ ~imported
    /\ imported' = TRUE
    /\ signal' = [signal EXCEPT ![d] = TRUE]
    /\ net' = net \cup
         {[to |-> e, what |-> "signal", row |-> NoRow] : e \in Devices \ {d}}
    /\ UNCHANGED <<now, journal, nextId, manual>>

AutoFill(d) ==
    /\ signal[d]
    /\ journal[d] = {}
    /\ LET r == Row(nextId, now, "success", "auto") IN
         /\ journal' = [journal EXCEPT ![d] = {r}]
         /\ net' = net \cup SendRow(r, d)
    /\ nextId' = nextId + 1
    /\ UNCHANGED <<now, signal, imported, manual>>

Deliver(m) ==
    /\ net' = net \ {m}
    /\ IF m.what = "row"
       THEN /\ journal' = [journal EXCEPT ![m.to] = @ \cup {m.row}]
            /\ UNCHANGED signal
       ELSE /\ signal' = [signal EXCEPT ![m.to] = TRUE]
            /\ UNCHANGED journal
    /\ UNCHANGED <<now, imported, nextId, manual>>

Next ==
    \/ Tick
    \/ \E d \in Devices :
         \/ \E k \in Kinds : Write(d, k)
         \/ Import(d)
         \/ AutoFill(d)
    \/ \E m \in net : Deliver(m)

\* Sync keeps delivering, and the engine runs on every device that has the
\* signal (it is woken by the signal's own update notification).
Fairness ==
    /\ WF_vars(\E m \in net : Deliver(m))
    /\ \A d \in Devices : WF_vars(AutoFill(d))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------

AllRows == UNION {journal[d] : d \in Devices}

TypeOK ==
    /\ now \in 0..MaxTime
    /\ \A d \in Devices : \A r \in journal[d] :
         /\ r.kind \in Kinds
         /\ r.src \in {"manual", "auto"}
    /\ signal \in [Devices -> BOOLEAN]
    /\ manual \in 0..MaxManual

\* Every replica that holds the same rows settles the day to the same one, so
\* once sync is quiet the habits page, streaks and goals agree everywhere.
Converged ==
    net = {} =>
        \A d, e \in Devices :
            /\ journal[d] = journal[e]
            /\ journal[d] # {} => Settled(journal[d]) = Settled(journal[e])

\* "Manual beats auto, skip beats data": once a person has recorded the day
\* on any device, no automatic success replaces what they recorded — on this
\* replica or on any other, whatever order the rows arrive in.
ManualBeatsAuto ==
    \A d \in Devices :
        (\E r \in journal[d] : r.src = "manual") =>
            Settled(journal[d]).src = "manual"

\* And among a person's own entries, the last one stands.
LatestManualWins ==
    \A d \in Devices :
        LET mine == {r \in journal[d] : r.src = "manual"} IN
            mine # {} => Settled(journal[d]) = Settled(mine)

\* Once the signal exists, every device ends up with the day recorded.
EventuallyRecorded == imported ~> \A d \in Devices : journal[d] # {}

=============================================================================
