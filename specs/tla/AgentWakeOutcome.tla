-------------------------- MODULE AgentWakeOutcome --------------------------
(***************************************************************************)
(* One agent's wake outcomes on two devices, and the face the person page  *)
(* shows for them. A wake starts on a device, runs for a while, and ends   *)
(* in success — a briefing written, stamped with the wake's start — or in  *)
(* failure. Either way the device records the outcome on the agent's one   *)
(* state row, which syncs as a register; other writers of that row (the    *)
(* report-stale watermark, the throttle) move its `updatedAt` without     *)
(* touching the outcome. The card reads the row and the latest briefing   *)
(* and says *failed* when the last wake failed and nothing newer           *)
(* succeeded. The question is whether every device, once the writes have  *)
(* met, says what actually happened last.                                  *)
(*                                                                         *)
(* Time is a logical clock `t` that every start, end and touch advances,   *)
(* so no two stamps coincide. A device's clock reads `t + Skew[r]`; the   *)
(* stamps it writes carry its clock, the truth is kept in `t`.             *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Start(r)      a wake begins on r: RelationshipAgentWorkflow.execute   *)
(*                 reads `now` (the briefing's `createdAt`,                *)
(*                 relationshipBriefingCreatedAt)                          *)
(*   End(r, ok)    the wake ends: _stampWakeOutcome through                *)
(*                 AgentSyncService.updateAgentState, a transform of the   *)
(*                 row r holds (relationshipWakeOutcome); on success the   *)
(*                 briefing lands (the report head: the latest createdAt)  *)
(*   Touch(r)      another writer of the row — Phase A's report-stale      *)
(*                 watermark, the throttle — stamps `updatedAt` only       *)
(*   Sync(r)       every version r is missing lands:                       *)
(*                 resolveAgentEntityVersions keeps the later `updatedAt`  *)
(*                 (then the canonical clock, here the write order) for    *)
(*                 the row, and joins the watermarks by latest instant     *)
(*                 (mergeAgentStateCounters); the latest briefing stands   *)
(*   Face(r)       relationshipAgentCardStateOf's *failed*                 *)
(*                                                                         *)
(* The design switches, TRUE in the checked-in configurations:             *)
(*   StampAtEnd         the outcome is stamped when the wake ends (R-05);  *)
(*                      FALSE: with the wake's start, the code at          *)
(*                      1399ee934, so a short failure that began after a   *)
(*                      long success began outranks it                     *)
(*   OutcomeWatermarks  the outcome is two watermarks, `lastWakeAt` for    *)
(*                      the last completed wake and `lastWakeFailedAt` for *)
(*                      the last failed one, each joined by latest instant *)
(*                      on every receive, and a stamp is bumped past the   *)
(*                      stamps the writer holds (decisionStampAfter); the  *)
(*                      face is `lastWakeFailedAt` newer than `lastWakeAt` *)
(*                      and than the briefing. FALSE: the code at          *)
(*                      1399ee934 — `lastWakeAt` stamped either way,       *)
(*                      `consecutiveFailureCount` reset or bumped, both    *)
(*                      last-writer-wins with the row, so a later          *)
(*                      unrelated write carries an older outcome over a    *)
(*                      newer one; the face is a count above zero and      *)
(*                      `lastWakeAt` newer than the briefing              *)
(*                                                                         *)
(* Not modelled: the lease (ScheduledWakeLease.tla) — any wake may run on *)
(* any device, as a chat or Brief me does; the vector clocks (a            *)
(* concurrent pair here is any two versions, resolved by stamp and write   *)
(* order, as a concurrent pair is in the code); the failure count's value  *)
(* (last-writer-wins by design, it feeds the backoff and the Stats tab,    *)
(* never a face); loss and backfill (AgentReplication.tla).                *)
(***************************************************************************)
EXTENDS Integers, FiniteSets

CONSTANTS
    MaxWakes, MaxTouches,
    SkewA, SkewB,       \* each device's clock minus the true clock
    StampAtEnd, OutcomeWatermarks

ASSUME StampAtEnd \in BOOLEAN /\ OutcomeWatermarks \in BOOLEAN

R == 1..2
Skew == <<SkewA, SkewB>>
\* The clock starts high enough that every stamp stays positive under skew.
T0 == 10
Max(a, b) == IF a > b THEN a ELSE b
Max3(a, b, c) == Max(a, Max(b, c))

\* A state version: the completed and failed watermarks, the failure count,
\* `updatedAt`, and the order it was written in.
Row0 == [done |-> 0, failed |-> 0, fails |-> 0, up |-> 0, n |-> 0]

VARIABLES
    t,          \* the true clock
    running,    \* per device: the start of the wake in flight, or 0
    st,         \* per device: the state row it holds
    sts,        \* every state version written
    rep,        \* per device: the briefing it holds (its createdAt), 0: none
    reps,       \* every briefing's createdAt
    w,          \* writes so far: the order the resolver's tiebreak reads
    wakes, touches,
    lastOk,     \* ghost: the outcome of the wake that ended last
    ended,      \* ghost: wakes ended
    blind       \* ghost: the last wake ended on a device that had not
                \*        received every earlier outcome

vars == <<t, running, st, sts, rep, reps, w, wakes, touches, lastOk, ended,
          blind>>

Init ==
    /\ t = T0
    /\ running = [r \in R |-> 0]
    /\ st = [r \in R |-> Row0]
    /\ sts = {Row0}
    /\ rep = [r \in R |-> 0]
    /\ reps = {}
    /\ w = 0
    /\ wakes = 0 /\ touches = 0
    /\ lastOk = TRUE
    /\ ended = 0
    /\ blind = FALSE

Clock(r) == t + Skew[r]

-----------------------------------------------------------------------------
(* The wake *)

Start(r) ==
    /\ running[r] = 0
    /\ wakes < MaxWakes
    /\ running' = [running EXCEPT ![r] = Clock(r)]
    /\ wakes' = wakes + 1
    /\ t' = t + 1
    /\ UNCHANGED <<st, sts, rep, reps, w, touches, lastOk, ended, blind>>

\* The newest outcome stamp among every version written: what a device
\* that had received everything would hold.
NewestOutcome == CHOOSE m \in {Max(v.done, v.failed) : v \in sts} :
    \A v \in sts : Max(v.done, v.failed) <= m

End(r, ok) ==
    /\ running[r] > 0
    /\ LET held == st[r]
           raw == IF StampAtEnd THEN Clock(r) ELSE running[r]
           stamp == IF OutcomeWatermarks
                    THEN Max3(raw, held.done + 1, held.failed + 1)
                    ELSE raw
           row == IF OutcomeWatermarks
                  THEN [done |-> IF ok THEN stamp ELSE held.done,
                        failed |-> IF ok THEN held.failed ELSE stamp,
                        fails |-> IF ok THEN 0 ELSE held.fails + 1,
                        up |-> stamp, n |-> w + 1]
                  ELSE [done |-> stamp, failed |-> 0,
                        fails |-> IF ok THEN 0 ELSE held.fails + 1,
                        up |-> stamp, n |-> w + 1]
       IN /\ st' = [st EXCEPT ![r] = row]
          /\ sts' = sts \cup {row}
          /\ rep' = IF ok THEN [rep EXCEPT ![r] = running[r]] ELSE rep
          /\ reps' = IF ok THEN reps \cup {running[r]} ELSE reps
          /\ blind' = (Max(held.done, held.failed) < NewestOutcome)
    /\ running' = [running EXCEPT ![r] = 0]
    /\ w' = w + 1
    /\ t' = t + 1
    /\ lastOk' = ok
    /\ ended' = ended + 1
    /\ UNCHANGED <<wakes, touches>>

\* Another writer of the row: `updatedAt` moves, the outcome rides along.
Touch(r) ==
    /\ touches < MaxTouches
    /\ LET row == [st[r] EXCEPT !.up = Clock(r), !.n = w + 1]
       IN /\ st' = [st EXCEPT ![r] = row]
          /\ sts' = sts \cup {row}
    /\ touches' = touches + 1
    /\ w' = w + 1
    /\ t' = t + 1
    /\ UNCHANGED <<running, rep, reps, wakes, lastOk, ended, blind>>

-----------------------------------------------------------------------------
(* Sync: the resolver's rules are joins, so everything lands at once *)

Later(a, b) == a.up > b.up \/ (a.up = b.up /\ a.n > b.n)

\* The row device r holds once every version has reached it: the
\* last-writer-wins winner, with the watermarks joined by latest instant.
Resolved(r) ==
    LET all == sts \cup {st[r]}
        lww == CHOOSE v \in all : \A x \in all : ~Later(x, v)
    IN IF OutcomeWatermarks
       THEN [lww EXCEPT !.done = CHOOSE m \in {v.done : v \in all} :
                                     \A v \in all : v.done <= m,
                        !.failed = CHOOSE m \in {v.failed : v \in all} :
                                     \A v \in all : v.failed <= m]
       ELSE lww

LatestReport(r) ==
    IF reps = {} THEN rep[r]
    ELSE CHOOSE m \in reps \cup {rep[r]} : \A x \in reps : x <= m

Sync(r) ==
    /\ st[r] # Resolved(r) \/ rep[r] # LatestReport(r)
    /\ st' = [st EXCEPT ![r] = Resolved(r)]
    /\ rep' = [rep EXCEPT ![r] = LatestReport(r)]
    /\ UNCHANGED <<t, running, sts, reps, w, wakes, touches, lastOk, ended,
                   blind>>

Next ==
    \/ \E r \in R : Start(r) \/ End(r, TRUE) \/ End(r, FALSE) \/ Touch(r)
                    \/ Sync(r)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ wakes <= MaxWakes /\ touches <= MaxTouches
    /\ \A r \in R : running[r] >= 0

\* The failed face on device r (relationshipAgentCardStateOf).
Face(r) ==
    IF OutcomeWatermarks
    THEN /\ st[r].failed > st[r].done
         /\ (rep[r] = 0 \/ st[r].failed > rep[r])
    ELSE /\ st[r].fails > 0
         /\ (rep[r] = 0 \/ st[r].done > rep[r])

Quiescent ==
    /\ \A r \in R : running[r] = 0
    /\ \A r \in R : st[r] = Resolved(r) /\ rep[r] = LatestReport(r)

\* Once every write has met, every device says what happened last.
FailedFaceAgreed ==
    Quiescent /\ ended > 0 => \A r \in R : Face(r) = ~lastOk

\* The same, provided the device that ran the last wake had received every
\* earlier outcome when it wrote its own: what a stamp bumped past the
\* stamps it supersedes guarantees even when the clocks disagree.
FailedFaceAgreedWhenInformed ==
    Quiescent /\ ended > 0 /\ ~blind => \A r \in R : Face(r) = ~lastOk

\* Once every write has met, every device holds the same row and briefing.
Converged ==
    Quiescent => \A r, s \in R : st[r] = st[s] /\ rep[r] = rep[s]
=============================================================================
