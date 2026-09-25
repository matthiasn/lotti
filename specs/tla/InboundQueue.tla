---------------------------- MODULE InboundQueue ----------------------------
(***************************************************************************)
(* The inbound Matrix event queue of one room: how timeline events reach   *)
(* `inbound_event_queue`, how the worker drains it, and how the per-room   *)
(* `queue_markers` row (applied marker and resume floor) decides what the  *)
(* next catch-up walk fetches.                                             *)
(*                                                                         *)
(* SyncSequence.tla models the layer above this one: vector-clock counters *)
(* and peer backfill. This model stops at the queue, and asks whether an   *)
(* event the homeserver holds can fall out of the queue's own recovery:    *)
(* neither captured (a row in any status) nor fetched by the catch-up that *)
(* the durable marker would run after a crash.                             *)
(*                                                                         *)
(* Events are the room timeline 1..N; an event's number is both its        *)
(* position and its origin timestamp, so equal-millisecond collisions are  *)
(* left out. Event 0 is "no anchor"; a marker timestamp of 0 is "no        *)
(* marker"; a floor of None is `resume_floor_ts IS NULL`.                  *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Arrive            a peer sends; the homeserver timeline grows         *)
(*   LiveDeliver       QueuePipelineCoordinator._handleLiveEvent, run by   *)
(*                     `asyncMap` in stream order: ciphertext lowers the   *)
(*                     floor (InboundQueue.lowerResumeFloor), plaintext    *)
(*                     goes through InboundQueue.enqueueLive, which first  *)
(*                     persists a retained floor                           *)
(*   LiveGap,          a `timeline.limited` sync: the SDK drops the middle *)
(*   GapTrigger        of the timeline, delivers the newest slice, and     *)
(*                     BridgeCoordinator._handle schedules a bridge pass   *)
(*   ManualBridge      "Catch up now" and forceRescan: bridgeNow           *)
(*   KeyArrives        a late Megolm key; with a floor recorded, to-device *)
(*                     traffic triggers a bridge (_bridgeIfResumeFloor)    *)
(*   WalkStart         BridgeCoordinator._bridge -> the per-room walk lane *)
(*                     (_serializeResumeFloorWalk) -> _runBootstrap, which *)
(*                     re-reads the marker and picks the forward walk from *)
(*                     the anchor (BridgeMarker.anchorIsSafe) or the       *)
(*                     backward walk from the tip                          *)
(*   GapRecoveryStart  QueueGapRecovery._runGapRecovery: an unbounded      *)
(*                     backward walk, outside the bridge                   *)
(*   WalkStepFwd,      QueueBootstrapSink.onPage for one event of a page:  *)
(*   WalkStepBwd       re-decrypt, lowerResumeFloorFromWalk for ciphertext *)
(*                     (no revision bump), appendBootstrapPage for         *)
(*                     plaintext                                           *)
(*   WalkCheckpoint    InboundQueue.checkpointResumeWalk after a forward   *)
(*                     page (CheckpointForward)                            *)
(*   WalkComplete      serverExhausted / boundaryReached, then             *)
(*                     InboundQueue.completeResumeWalk: a compare-and-set  *)
(*                     on the floor revision observed at walk start        *)
(*   WalkFail          an incomplete walk (error, timeout, cap, back-      *)
(*                     pressure): BridgeCoordinator's bounded retry        *)
(*   Peek, ApplyOk,    InboundWorker._runBatch: peekBatchReady leases a    *)
(*   Commit,           row, apply writes the journal, and the phase-2      *)
(*   ApplyRetry,       transaction runs commitApplied / scheduleRetry /    *)
(*   ApplyAbandon      markSkipped; commit and skip advance the marker     *)
(*                     (QueueMarkerAdvancer.advanceIfNewer) in the same    *)
(*                     transaction as the status flip                      *)
(*   WorkerError       a throw inside InboundWorker._loop (peek or the     *)
(*                     phase-2 transaction)                                *)
(*   ResurrectSelect,  InboundQueueResurrection._resurrectWhere: a SELECT  *)
(*   ResurrectUpdate   of abandoned rows, then an UPDATE by queue id       *)
(*   ResurrectNow      a second resurrection pass (attachment path, journal *)
(*                     update or "Retry all"), atomic                      *)
(*   Stop, Start       QueueLifecycle.stopImpl / startImpl                 *)
(*   Crash             the process dies: the database survives, leases     *)
(*                     stay until they expire, in-memory state is lost     *)
(*                                                                         *)
(* The fixes are switches, so a configuration with a switch FALSE is the   *)
(* old code. Every checked-in configuration sets them TRUE. SliceRace is   *)
(* the one residual: TRUE lets the worker apply a limited sync's slice     *)
(* before BridgeCoordinator sees the sync, which the checked-in            *)
(* configurations exclude (see the README).                                *)
(***************************************************************************)
EXTENDS Integers, FiniteSets

CONSTANTS
    N,              \* timeline events 1..N
    InitTip,        \* events already on the homeserver at the first start
    EncInit,        \* events that arrive encrypted without a usable key
    MaxDowns,       \* bound on stops and crashes together
    FaultBudget,    \* bound on injected faults of the kinds in `Faults`
    Faults,         \* subset of FaultKinds this configuration tolerates
    MaxRetries,     \* bound on retriable apply outcomes
    MaxResurrections, \* bound on resurrection passes
    GapRecovery,    \* TRUE: one gap-recovery walk may run
    \* The fixes, TRUE in every checked-in configuration:
    ClaimOnStart,   \* startImpl claims the range above the marker
    ClaimOnGap,     \* a limited sync claims the range above the marker
    ClaimOnWalk,    \* every walk claims the range above the marker
    CheckpointForward, \* a forward walk raises its claim as it goes
    FailedEnqueueLowersFloor, \* a live enqueue that throws lowers the floor
    WorkerSurvivesErrors, \* the worker loop outlives a throw
    GuardedResurrect, \* resurrection flips only rows still abandoned
    ResurrectRechecksCap, \* ... and still under the hard cap
    RetainFailedClaim, \* a claim whose marker read throws stays pending
    HardCap,        \* resurrections per row (`hardCap`)
    \* The residual:
    SliceRace       \* TRUE: the slice can apply before the trigger claims

FaultKinds == {
    "enqueue",      \* an inbound_event_queue insert throws
    "floorWrite",   \* a resume-floor write throws; the value is retained
                    \* in memory (QueueMarkerAdvancer._pendingResumeFloors)
    "walk",         \* a catch-up walk ends incomplete
    "worker",       \* the worker's peek or phase-2 transaction throws
    "claimRead"     \* reading the marker for a claim throws
}

ASSUME Faults \subseteq FaultKinds
ASSUME N \in Nat /\ InitTip \in 0..N /\ EncInit \subseteq 1..N
ASSUME MaxDowns \in Nat /\ FaultBudget \in Nat
ASSUME MaxRetries \in Nat /\ MaxResurrections \in Nat /\ HardCap \in Nat

Events == 1..N
None == -1
Active == {"enqueued", "retrying", "leased"}
Settled == {"applied", "abandoned"}
RowStates == {"none"} \cup Active \cup Settled

Min2(a, b) == IF a < b THEN a ELSE b
MinOf(S) == CHOOSE x \in S : \A y \in S : x <= y
\* Lowering a floor-like value, where None is "no floor".
Lower(f, t) == IF f = None THEN t ELSE Min2(f, t)

VARIABLES
    tip,            \* homeserver timeline is 1..tip
    enc,            \* events still undecryptable on this device
    running,        \* the coordinator is started
    workerAlive,    \* InboundWorker._loop is running
    liveNext,       \* next event the live stream hands to _handleLiveEvent
    gapPending,     \* a limited sync the bridge has not handled yet
    row,            \* inbound_event_queue status per event ("none": no row)
    wk,             \* the event the worker holds (0: none)
    wkPhase,        \* "none", "leased", or "done" (journal written)
    mTs,            \* queue_markers.last_applied_ts (0: none)
    mAnchor,        \* queue_markers.last_applied_event_id (0: none)
    floor,          \* queue_markers.resume_floor_ts (None: null)
    pend,           \* a floor retained in memory after a failed write
    pendClaim,      \* a claim retained in memory after a failed marker read
    resCount,       \* inbound_event_queue.resurrection_count per event
    dirty,          \* the floor revision moved since the walk started
    walk,           \* "idle", "fwd" or "bwd"
    wCur,           \* the walk's last emitted event (fwd) or next-above (bwd)
    wBound,         \* the backward walk's lower bound
    wUnres,         \* oldest ciphertext this walk saw (None: none)
    bridgePending,  \* a bridge pass is requested (trigger or rerun)
    recovered,      \* the gap-recovery walk has run
    rsSel,          \* rows a resurrection pass selected, not yet updated
    retries, resurrections, downs, faults

vars == <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk,
          wkPhase, mTs, mAnchor, floor, pend, pendClaim, resCount, dirty,
          walk, wCur, wBound,
          wUnres, bridgePending, recovered, rsSel, retries, resurrections,
          downs, faults>>

walkVars == <<walk, wCur, wBound, wUnres>>
counters == <<retries, resurrections, downs, faults>>

FaultOK(k) == k \in Faults /\ faults < FaultBudget

-----------------------------------------------------------------------------
(* The catch-up the durable marker selects. `BridgeMarker.anchorIsSafe` *)
(* and `_runBootstrapWithMarker`.                                        *)

AnchorSafe(f) == mAnchor # 0 /\ (f = None \/ f > mTs)

\* Lower bound of the backward walk: `resumeFloorTs ?? lastAppliedTs`, and
\* with the claims the smaller of the two, so a claim one above the marker
\* never narrows the walk.
BackwardBound(f) ==
    IF f = None THEN mTs
    ELSE IF ClaimOnWalk /\ mTs # 0 THEN Min2(f, mTs)
    ELSE f

\* The next catch-up, run from the durable state alone (after a crash, the
\* retained floor is gone), fetches e.
Recoverable(e) ==
    IF AnchorSafe(floor) THEN e > mAnchor ELSE e >= BackwardBound(floor)

Captured(e) == row[e] # "none"

-----------------------------------------------------------------------------
(* Floor writes. `_retainAndPersistResumeFloor` folds the value into the *)
(* retained minimum and persists it; on a throw it stays retained.       *)

\* Persisting the retained floor (ensureResumeFloorPersisted), after
\* resolving a claim whose marker read failed against the marker as it is
\* now.
Flushed ==
    LET f1 == IF pend = None THEN floor ELSE Lower(floor, pend)
    IN IF pendClaim THEN Lower(f1, mTs + 1) ELSE f1

LowerFloor(t) ==
    \/ /\ floor' = Lower(Flushed, t)
       /\ pend' = None /\ pendClaim' = FALSE
       /\ UNCHANGED faults
    \/ /\ FaultOK("floorWrite")
       /\ pend' = Lower(pend, t)
       /\ faults' = faults + 1
       /\ UNCHANGED <<floor, pendClaim>>

\* Claiming the range above the marker: a floor one above it.
Claim(on) ==
    IF on
      THEN \/ LowerFloor(mTs + 1)
           \/ \* reading the marker throws before the floor is written
              /\ FaultOK("claimRead")
              /\ faults' = faults + 1
              /\ pendClaim' = (pendClaim \/ RetainFailedClaim)
              /\ UNCHANGED <<floor, pend>>
      ELSE UNCHANGED <<floor, pend, pendClaim, faults>>

-----------------------------------------------------------------------------
(* QueueMarkerAdvancer.advanceIfNewer for event e leaving the active set. *)

AdvanceMarker(e) ==
    LET others == {x \in Events \ {e} : row[x] \in Active}
        oa == IF others = {} THEN None ELSE MinOf(others)
        cand == IF oa = None \/ e < oa THEN e ELSE oa - 1
        tie == cand = e /\ e = mTs
        adv == mTs = 0 \/ cand > mTs \/ tie
    IN IF ~adv THEN UNCHANGED <<mTs, mAnchor, resCount>>
       ELSE /\ mTs' = IF tie THEN mTs ELSE cand
            \* An equal timestamp takes the larger event id, which is
            \* arbitrary here; a null stored id always yields.
            /\ mAnchor' \in
                 IF tie THEN (IF mAnchor = 0 THEN {e} ELSE {mAnchor, e})
                 ELSE IF cand = e THEN {e} ELSE {mAnchor}

-----------------------------------------------------------------------------

Init ==
    /\ tip = InitTip
    /\ enc = EncInit
    /\ running = FALSE
    /\ workerAlive = FALSE
    /\ liveNext = InitTip + 1
    /\ gapPending = FALSE
    /\ row = [e \in Events |-> "none"]
    /\ wk = 0
    /\ wkPhase = "none"
    /\ mTs = 0
    /\ mAnchor = 0
    /\ floor = None
    /\ pend = None
    /\ pendClaim = FALSE
    /\ resCount = [e \in Events |-> 0]
    /\ dirty = FALSE
    /\ walk = "idle"
    /\ wCur = 0
    /\ wBound = 0
    /\ wUnres = None
    /\ bridgePending = FALSE
    /\ recovered = FALSE
    /\ rsSel = {}
    /\ retries = 0
    /\ resurrections = 0
    /\ downs = 0
    /\ faults = 0

Arrive ==
    /\ tip < N
    /\ tip' = tip + 1
    /\ UNCHANGED <<enc, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, floor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, counters, resCount>>

\* A key arrives. BridgeCoordinator reruns catch-up on to-device traffic
\* while a floor exists; reading the marker persists a retained floor.
KeyArrives(e) ==
    /\ e \in enc
    /\ enc' = enc \ {e}
    /\ IF running /\ Flushed # None
         THEN bridgePending' = TRUE /\ floor' = Flushed /\ pend' = None /\ pendClaim' = FALSE
         ELSE UNCHANGED <<bridgePending, floor, pend, pendClaim, resCount>>
    /\ UNCHANGED <<tip, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, dirty, walkVars, recovered, rsSel, counters, resCount>>

LiveDeliver ==
    /\ running
    /\ liveNext <= tip
    /\ LET e == liveNext IN
       /\ liveNext' = e + 1
       /\ IF e \in enc
            THEN \* ciphertext: lowerResumeFloor bumps the revision
                 /\ LowerFloor(e)
                 /\ dirty' = TRUE
                 /\ UNCHANGED <<row, bridgePending, resCount>>
            ELSE \/ \* enqueueLive: the retained floor first, then the insert
                    /\ floor' = Flushed
                    /\ pend' = None /\ pendClaim' = FALSE
                    /\ row' = IF row[e] = "none"
                                THEN [row EXCEPT ![e] = "enqueued"] ELSE row
                    /\ UNCHANGED <<dirty, faults, bridgePending, resCount>>
                 \/ \* the insert throws; _safeEnqueue catches it
                    /\ FaultOK("enqueue")
                    /\ UNCHANGED row
                    /\ faults' = faults + 1
                    /\ IF FailedEnqueueLowersFloor
                         THEN \* the floor, and a pass to fetch the event
                              /\ dirty' = TRUE
                              /\ bridgePending' = TRUE
                              /\ \/ /\ floor' = Lower(Flushed, e)
                                    /\ pend' = None /\ pendClaim' = FALSE
                                 \/ /\ pend' = Lower(pend, e)
                                    /\ UNCHANGED <<floor, pendClaim>>
                         ELSE UNCHANGED <<floor, pend, pendClaim, dirty, bridgePending, resCount>>
    /\ UNCHANGED <<tip, enc, running, workerAlive, gapPending, wk, wkPhase, mTs, mAnchor, walkVars, recovered, rsSel, retries, resurrections, downs, resCount>>

\* The bridge sees a limited sync: claim the gap, then request a pass.
GapClaimed ==
    /\ Claim(ClaimOnGap)
    /\ dirty' = IF ClaimOnGap THEN TRUE ELSE dirty
    /\ bridgePending' = TRUE

\* A limited sync: events liveNext..k-1 never reach the live stream.
LiveGap ==
    /\ running
    /\ liveNext <= tip
    /\ \E k \in (liveNext + 1)..(tip + 1) :
         /\ liveNext' = k
         /\ IF SliceRace
              THEN /\ gapPending' = TRUE
                   /\ UNCHANGED <<floor, pend, pendClaim, dirty, bridgePending, faults, resCount>>
              ELSE /\ GapClaimed
                   /\ UNCHANGED gapPending
    /\ UNCHANGED <<tip, enc, running, workerAlive, row, wk, wkPhase, mTs, mAnchor, walkVars, recovered, rsSel, retries, resurrections, downs, resCount>>

\* "Catch up now", MatrixService.forceRescan: a pass with no gap known.
ManualBridge ==
    /\ running
    /\ ~bridgePending
    /\ bridgePending' = TRUE
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, floor, pend, pendClaim, dirty, walkVars, recovered, rsSel, counters, resCount>>

GapTrigger ==
    /\ running
    /\ gapPending
    /\ gapPending' = FALSE
    /\ GapClaimed
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, row, wk, wkPhase, mTs, mAnchor, walkVars, recovered, rsSel, retries, resurrections, downs, resCount>>

\* A walk starts in the lane. The marker read persists a retained floor.
\* The walk's own claim is walk-local: it does not move the revision.
BeginWalk(forward, unbounded) ==
    LET f1 == Flushed
        claimed == IF ClaimOnWalk THEN Lower(f1, mTs + 1) ELSE f1
    IN /\ floor' = claimed
       /\ pend' = None /\ pendClaim' = FALSE
       /\ dirty' = FALSE
       /\ walk' = IF forward THEN "fwd" ELSE "bwd"
       /\ wCur' = IF forward THEN mAnchor ELSE tip + 1
       /\ wBound' = IF forward \/ unbounded THEN 0 ELSE BackwardBound(claimed)
       /\ wUnres' = None

WalkStart ==
    /\ running
    /\ walk = "idle"
    /\ bridgePending
    /\ bridgePending' = FALSE
    /\ BeginWalk(AnchorSafe(Flushed), FALSE)
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, recovered, rsSel, counters, resCount>>

GapRecoveryStart ==
    /\ GapRecovery
    /\ running
    /\ walk = "idle"
    /\ ~recovered
    /\ recovered' = TRUE
    /\ BeginWalk(FALSE, TRUE)
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, bridgePending, rsSel, counters, resCount>>

\* The walk ends incomplete; the bridge schedules its bounded retry.
AbortWalk ==
    /\ walk' = "idle"
    /\ bridgePending' = TRUE
    /\ UNCHANGED <<wCur, wBound, wUnres, resCount>>

\* The sink handles event c of the walk.
Emit(c) ==
    IF c \in enc
      THEN \* still ciphertext after one fresh decrypt attempt
           \/ /\ floor' = Lower(Flushed, c)
              /\ pend' = None /\ pendClaim' = FALSE
              /\ wUnres' = Lower(wUnres, c)
              /\ UNCHANGED <<row, faults, walk, bridgePending, resCount>>
           \/ /\ FaultOK("floorWrite")
              /\ pend' = Lower(pend, c)
              /\ faults' = faults + 1
              /\ UNCHANGED <<row, floor, wUnres, resCount, pendClaim>>
              /\ walk' = "idle"
              /\ bridgePending' = TRUE
      ELSE /\ floor' = Flushed
           /\ pend' = None /\ pendClaim' = FALSE
           /\ row' = IF row[c] = "none"
                       THEN [row EXCEPT ![c] = "enqueued"] ELSE row
           /\ UNCHANGED <<faults, wUnres, walk, bridgePending, resCount>>

WalkStepFwd ==
    /\ running
    /\ walk = "fwd"
    /\ wCur < tip
    /\ wCur' = wCur + 1
    /\ Emit(wCur + 1)
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, wk, wkPhase, mTs, mAnchor, dirty, wBound, recovered, rsSel, retries, resurrections, downs, resCount>>

WalkStepBwd ==
    /\ running
    /\ walk = "bwd"
    /\ wCur - 1 >= wBound
    /\ wCur - 1 >= 1
    /\ wCur' = wCur - 1
    /\ Emit(wCur - 1)
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, wk, wkPhase, mTs, mAnchor, dirty, wBound, recovered, rsSel, retries, resurrections, downs, resCount>>

\* After a forward page: every event after the anchor up to the cursor is
\* queued, or is ciphertext the walk holds in wUnres, so the floor moves to
\* one above the cursor. No compare-and-set: an observation made while the
\* walk runs is of an event the walk has passed (and so captured or holds)
\* or has yet to reach (and so sits above the cursor). TLC agrees; the
\* completion's compare-and-set, which clears the floor, is load-bearing.
WalkCheckpoint ==
    /\ CheckpointForward
    /\ running
    /\ walk = "fwd"
    /\ floor' = Lower(wUnres, wCur + 1)
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, counters, resCount>>

WalkComplete ==
    /\ running
    /\ \/ walk = "fwd" /\ wCur >= tip
       \/ walk = "bwd" /\ (wCur - 1 < wBound \/ wCur - 1 < 1)
    /\ walk' = "idle"
    /\ floor' = IF dirty THEN floor ELSE wUnres
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, pend, pendClaim, dirty, wCur, wBound, wUnres, bridgePending, recovered, rsSel, counters, resCount>>

WalkFail ==
    /\ running
    /\ walk # "idle"
    /\ FaultOK("walk")
    /\ faults' = faults + 1
    /\ AbortWalk
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk, wkPhase, mTs, mAnchor, floor, pend, pendClaim, dirty, recovered, rsSel, retries, resurrections, downs, resCount>>

-----------------------------------------------------------------------------
(* The worker. A leased row that no worker holds is an expired lease.    *)

WorkerUp == running /\ workerAlive

Peek(e) ==
    /\ WorkerUp
    /\ wk = 0
    /\ row[e] \in Active
    /\ row' = [row EXCEPT ![e] = "leased"]
    /\ wk' = e
    /\ wkPhase' = "leased"
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, mTs, mAnchor, floor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, counters, resCount>>

ApplyOk ==
    /\ WorkerUp
    /\ wk # 0
    /\ wkPhase = "leased"
    /\ wkPhase' = "done"
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row, wk, mTs, mAnchor, floor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, counters, resCount>>

Commit ==
    /\ WorkerUp
    /\ wk # 0
    /\ wkPhase = "done"
    /\ row' = [row EXCEPT ![wk] = "applied"]
    /\ AdvanceMarker(wk)
    /\ wk' = 0
    /\ wkPhase' = "none"
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, floor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, counters, resCount>>

ApplyRetry ==
    /\ WorkerUp
    /\ wk # 0
    /\ wkPhase = "leased"
    /\ retries < MaxRetries
    /\ retries' = retries + 1
    /\ row' = [row EXCEPT ![wk] = "retrying"]
    /\ wk' = 0
    /\ wkPhase' = "none"
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, mTs, mAnchor, floor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, resurrections, downs, faults, resCount>>

\* permanentSkip, maxAttempts or the pending-attachment deadline.
ApplyAbandon ==
    /\ WorkerUp
    /\ wk # 0
    /\ wkPhase = "leased"
    /\ row' = [row EXCEPT ![wk] = "abandoned"]
    /\ AdvanceMarker(wk)
    /\ wk' = 0
    /\ wkPhase' = "none"
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, floor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, counters, resCount>>

\* The batch's transaction rolls back; its row keeps its lease.
WorkerError ==
    /\ WorkerUp
    /\ FaultOK("worker")
    /\ faults' = faults + 1
    /\ wk' = 0
    /\ wkPhase' = "none"
    /\ workerAlive' = WorkerSurvivesErrors
    /\ UNCHANGED <<tip, enc, running, liveNext, gapPending, row, mTs, mAnchor, floor, pend, pendClaim, dirty, walkVars, bridgePending, recovered, rsSel, retries, resurrections, downs, resCount>>

-----------------------------------------------------------------------------

Eligible(e) == row[e] = "abandoned" /\ resCount[e] < HardCap

ResurrectSelect ==
    /\ running
    /\ rsSel = {}
    /\ resurrections < MaxResurrections
    /\ LET sel == {e \in Events : Eligible(e)} IN
       /\ sel # {}
       /\ rsSel' = sel
    /\ resurrections' = resurrections + 1
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, row,
                   wk, wkPhase, mTs, mAnchor, floor, pend, pendClaim, dirty,
                   walkVars, bridgePending, recovered, retries, downs, faults,
                   resCount>>

\* The UPDATE by queue id; the guard is what it re-checks of the SELECT.
StillEligible(e) ==
    \/ ~GuardedResurrect
    \/ /\ row[e] = "abandoned"
       /\ (~ResurrectRechecksCap \/ resCount[e] < HardCap)

ResurrectUpdate ==
    /\ rsSel # {}
    /\ LET flip == {e \in rsSel : StillEligible(e)} IN
       /\ row' = [e \in Events |->
                    IF e \in flip THEN "enqueued" ELSE row[e]]
       /\ resCount' = [e \in Events |->
                         IF e \in flip THEN resCount[e] + 1 ELSE resCount[e]]
    /\ rsSel' = {}
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, wk,
                   wkPhase, mTs, mAnchor, floor, pend, pendClaim, dirty,
                   walkVars, bridgePending, recovered, counters>>

ResurrectNow(e) ==
    /\ running
    /\ resurrections < MaxResurrections
    /\ Eligible(e)
    /\ row' = [row EXCEPT ![e] = "enqueued"]
    /\ resCount' = [resCount EXCEPT ![e] = @ + 1]
    /\ resurrections' = resurrections + 1
    /\ UNCHANGED <<tip, enc, running, workerAlive, liveNext, gapPending, wk,
                   wkPhase, mTs, mAnchor, floor, pend, pendClaim, dirty,
                   walkVars, bridgePending, recovered, rsSel, retries, downs,
                   faults>>

-----------------------------------------------------------------------------

\* stopImpl awaits in-flight enqueues, the bridge and the worker's batch.
Stop ==
    /\ running
    /\ wk = 0
    /\ walk = "idle"
    /\ downs < MaxDowns
    /\ downs' = downs + 1
    /\ running' = FALSE
    /\ bridgePending' = FALSE
    /\ gapPending' = FALSE
    /\ rsSel' = {}
    /\ UNCHANGED <<tip, enc, workerAlive, liveNext, row, wk, wkPhase, mTs, mAnchor, floor, pend, pendClaim, dirty, walkVars, recovered, retries, resurrections, faults, resCount>>

Crash ==
    /\ running
    /\ downs < MaxDowns
    /\ downs' = downs + 1
    /\ running' = FALSE
    /\ wk' = 0
    /\ wkPhase' = "none"
    /\ walk' = "idle"
    /\ pend' = None /\ pendClaim' = FALSE
    /\ bridgePending' = FALSE
    /\ gapPending' = FALSE
    /\ rsSel' = {}
    /\ UNCHANGED <<tip, enc, workerAlive, liveNext, row, mTs, mAnchor, floor, dirty, wCur, wBound, wUnres, recovered, retries, resurrections, faults, resCount>>

\* startImpl: events already on the homeserver never reach the live
\* stream; the startup bridge (bridgeNow) catches them up.
Start ==
    /\ ~running
    /\ running' = TRUE
    /\ workerAlive' = TRUE
    /\ liveNext' = tip + 1
    /\ bridgePending' = TRUE
    /\ Claim(ClaimOnStart)
    /\ UNCHANGED <<tip, enc, gapPending, row, wk, wkPhase, mTs, mAnchor, dirty, walkVars, recovered, rsSel, retries, resurrections, downs, resCount>>

-----------------------------------------------------------------------------

Next ==
    \/ Arrive
    \/ \E e \in Events : KeyArrives(e)
    \/ LiveDeliver
    \/ LiveGap
    \/ GapTrigger
    \/ ManualBridge
    \/ WalkStart
    \/ GapRecoveryStart
    \/ WalkStepFwd
    \/ WalkStepBwd
    \/ WalkCheckpoint
    \/ WalkComplete
    \/ WalkFail
    \/ \E e \in Events : Peek(e)
    \/ ApplyOk
    \/ Commit
    \/ ApplyRetry
    \/ ApplyAbandon
    \/ WorkerError
    \/ ResurrectSelect
    \/ ResurrectUpdate
    \/ \E e \in Events : ResurrectNow(e)
    \/ Stop
    \/ Crash
    \/ Start

\* The worker drains, the walks run, the live stream delivers, and a
\* stopped or crashed app starts again. Arrivals, gaps, keys, faults,
\* outcomes and resurrections are the environment's choice.
Fairness ==
    /\ WF_vars(LiveDeliver)
    /\ WF_vars(GapTrigger)
    /\ WF_vars(WalkStart)
    /\ WF_vars(WalkStepFwd)
    /\ WF_vars(WalkStepBwd)
    /\ WF_vars(WalkComplete)
    /\ WF_vars(\E e \in Events : Peek(e))
    /\ WF_vars(ApplyOk)
    /\ WF_vars(Commit)
    /\ WF_vars(ResurrectUpdate)
    /\ WF_vars(Start)

Spec == Init /\ [][Next]_vars
LiveSpec == Spec /\ Fairness

-----------------------------------------------------------------------------

TypeOK ==
    /\ tip \in 0..N
    /\ enc \subseteq Events
    /\ running \in BOOLEAN /\ workerAlive \in BOOLEAN
    /\ liveNext \in 1..(N + 1)
    /\ gapPending \in BOOLEAN
    /\ row \in [Events -> RowStates]
    /\ wk \in 0..N
    /\ wkPhase \in {"none", "leased", "done"}
    /\ mTs \in 0..N /\ mAnchor \in 0..N
    /\ floor \in {None} \cup 0..(N + 1)
    /\ pend \in {None} \cup 0..(N + 1)
    /\ walk \in {"idle", "fwd", "bwd"}
    /\ rsSel \subseteq Events
    /\ pendClaim \in BOOLEAN
    /\ resCount \in [Events -> 0..MaxResurrections]

\* No silent loss: every event the homeserver holds is captured in the
\* queue (in any status, abandoned included) or fetched by the catch-up
\* the durable marker selects. A crash at any step loses nothing.
NoSilentLoss == \A e \in 1..tip : Captured(e) \/ Recoverable(e)

\* The worker holds at most the row it leased.
HeldIsLeased == wk # 0 => row[wk] \in {"leased", "enqueued"}

MarkerMonotone ==
    [][/\ mTs' >= mTs
       /\ mAnchor' # mAnchor => mAnchor' > mAnchor]_vars

\* An applied row stays applied: a duplicate is ignored by the event_id
\* UNIQUE constraint and nothing re-arms a committed row.
AppliedIsFinal ==
    [][\A e \in Events : row[e] = "applied" => row'[e] = "applied"]_vars

\* No row is resurrected past its hard cap.
CapHolds == \A e \in Events : resCount[e] <= HardCap

\* Every durably queued event is eventually applied or dead-lettered.
QueuedEventuallySettled ==
    \A e \in Events : (row[e] \in Active) ~> (row[e] \in Settled)

\* Every event the homeserver holds is eventually captured (plaintext only;
\* ciphertext without a key stays behind its floor).
EventuallyCaptured ==
    \A e \in Events : (e <= tip /\ e \notin enc) ~> Captured(e)
=============================================================================
