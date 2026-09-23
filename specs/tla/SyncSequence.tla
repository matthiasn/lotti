--------------------------- MODULE SyncSequence ---------------------------
(***************************************************************************)
(* The sync sequence log and backfill protocol, for one originating host   *)
(* and a set of peers.                                                     *)
(*                                                                         *)
(* The originator hands out vector-clock counters 1..MaxCounter. Every     *)
(* counter either carries a payload (a write of one entity) or is burned.  *)
(* Peers learn about counters from the payloads they receive, turn holes   *)
(* into `missing` rows, request them, and settle each one from the         *)
(* originator's answer.                                                    *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Reserve, WriteReservedRow  VectorClockService.reserveNextVectorClock  *)
(*                              and recordReservedSequenceCounter; a       *)
(*                              failed insert falls back to SettingsDb     *)
(*                              (`fallback` rows), and ReservationFails    *)
(*                              is both stores refusing                    *)
(*   MigrateFallback            migrateUnrecordedReservations at startup   *)
(*   Commit, Abort              the payload database write                 *)
(*   Enqueue                    OutboxService.enqueueMessage; the enqueue  *)
(*                              writer binds the row after its insert      *)
(*   Release, Broadcast         VcReservation.release and                  *)
(*                              burnUnboundVectorClock, through            *)
(*                              BackfillResponseHandler.settleOwnCounter   *)
(*   ReconcileBurn,             startup reconciliation of `burnPending`    *)
(*   ResolveOrphan              and `reserved` own rows                    *)
(*   Respond                    BackfillResponseHandler for own counters   *)
(*   Deliver                    SyncSequenceReceiver.recordReceivedEntry   *)
(*                              and SyncSequenceBackfillResponder          *)
(*                                                                         *)
(* A reservation may carry its intent: the payload id it is for. The       *)
(* reserved row records it, and so does the process-local `pending` map.   *)
(* The intent is what lets the originator settle a counter it has not      *)
(* bound: if the intended payload's clock covers the counter, the write    *)
(* landed (or a later write of the same payload superseded it) and the     *)
(* counter is bound and resent; if it does not, and no live process can    *)
(* still land it, the counter is burned. `IntentChoices` says whether a    *)
(* caller may reserve without naming the payload.                          *)
(*                                                                         *)
(* A row becomes `received` only once the payload is durably in the        *)
(* outbox, or when an intent is proven covered and the payload is resent.  *)
(* That is what makes a crash between the payload commit and the enqueue   *)
(* recoverable: the row is still `reserved`, so startup finds it.          *)
(*                                                                         *)
(* Faults are opt-in through `Faults` and bounded by `FaultBudget`, so     *)
(* each configuration states which failures it tolerates. Crashes are      *)
(* bounded by `MaxCrashes`. A crash loses every in-flight write and the    *)
(* pending map; the databases, the outbox and the Matrix room survive it.  *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Peers,          \* receiving devices
    Entities,       \* payload ids the originator writes
    MaxCounter,     \* how many counters the originator may reserve
    MaxCrashes,     \* bound on originator crashes
    FaultBudget,    \* bound on injected faults of the kinds in `Faults`
    Faults,         \* subset of FaultKinds this configuration tolerates
    IntentChoices   \* {TRUE}, or {TRUE, FALSE} when a caller may omit it

FaultKinds == {
    "rowWrite",         \* the reserved-row insert throws; the reservation
                        \* is recorded in the settings database instead
    "fallbackWrite",    \* the reserved-row insert and its settings fallback
                        \* both throw, so the reservation itself throws
    "bind",             \* the outbox's recordSentEntry throws after the
                        \* outbox insert; it is swallowed
    "throwAfterCommit", \* a post-commit step throws before the enqueue and
                        \* an outer VC scope releases the counter
    "enqueue",          \* the outbox write throws; it is swallowed
    "broadcast",        \* the burn broadcast throws; the row stays burnPending
    "loss"              \* a peer abandons an inbound event for good
}

ASSUME Faults \subseteq FaultKinds
ASSUME IntentChoices \subseteq BOOLEAN /\ IntentChoices # {}
ASSUME MaxCounter \in Nat /\ MaxCrashes \in Nat /\ FaultBudget \in Nat

Counters == 1..MaxCounter
NoEntity == "noEntity"

\* Own-host rows on the originator. `fallback` is a reservation whose
\* sequence-log insert failed and which lives in the settings database
\* (VectorClockService.unrecordedReservation) until startup migrates it.
OwnStatus == {"none", "fallback", "reserved", "burnPending", "received",
              "burned"}

\* Reserved, in either store.
ReservedRow == {"fallback", "reserved"}

\* Rows on a peer. `deleted` is left out: this model never purges payloads.
PeerStatus == {"none", "missing", "requested", "received", "backfilled",
               "unresolvable", "burned"}

\* SyncSequenceStatusX.isResolved
Resolved == {"received", "backfilled", "unresolvable", "burned"}

\* Where each counter's write is inside the originator process.
InFlight == {"reserving", "reserved", "committed", "releasing",
             "broadcasting"}
PcStates == {"unused", "finished", "dead"} \cup InFlight

VARIABLES
    wm,         \* persisted watermark: counters 1..wm have been handed out
    pc,         \* per counter: progress of the write that reserved it
    ent,        \* per counter: the entity that write targets
    intent,     \* per counter: whether the reservation names its payload
    pending,    \* counters this process reserved and has not settled
    oLog,       \* per counter: the originator's own sequence-log row
    oIntent,    \* per counter: whether that row records the payload id
    store,      \* per entity: the own-host counter of its committed payload
    committed,  \* ghost: counters whose payload write committed
    outbox,     \* per entity: counters merged into its pending outbox row
    net,        \* per peer: room events this peer has not read yet
    reqs,       \* backfill requests not yet answered, as <<peer, counter>>
    pLog,       \* per peer, per counter: the peer's sequence-log row
    pVer,       \* per peer, per entity: the counter of the payload it holds
    faults,     \* faults injected so far
    crashes     \* crashes so far

vars == <<wm, pc, ent, intent, pending, oLog, oIntent, store, committed,
          outbox, net, reqs, pLog, pVer, faults, crashes>>

Max(S) == CHOOSE x \in S : \A y \in S : y <= x

(***************************************************************************)
(* Room events. Every event has the same fields so TLC can compare them.   *)
(*   payload: announces counter `a`, carries the entity file at counter    *)
(*            `v` (read at send time, so v >= a), and the superseded       *)
(*            counters `cov` the outbox merged into it                     *)
(*   hint:    a backfill resend of the payload plus the mapping for `c`    *)
(*   burn:    the originator's unresolvable=true for counter `c`           *)
(***************************************************************************)
PayloadMsg(e, a, v, cov) ==
    [type |-> "payload", e |-> e, a |-> a, v |-> v, cov |-> cov, c |-> 0]
HintMsg(e, v, c) ==
    [type |-> "hint", e |-> e, a |-> v, v |-> v, cov |-> {}, c |-> c]
BurnMsg(c) ==
    [type |-> "burn", e |-> NoEntity, a |-> 0, v |-> 0, cov |-> {}, c |-> c]

\* Everything the originator sends goes to the shared room.
ToRoom(m) == [p \in Peers |-> net[p] \cup {m}]

CanFault(kind) == kind \in Faults /\ faults < FaultBudget

\* The intended payload's clock covers the counter: the write landed, or a
\* later write of the same payload superseded it.
Covered(c) == store[ent[c]] >= c

\* The originator knows which payload `c` was reserved for.
KnownIntent(c) == oIntent[c] \/ (c \in pending /\ intent[c])

\* Rows nothing has settled yet. `received` and `burned` are final.
Unsettled == {"none", "fallback", "reserved", "burnPending"}

\* An unsettled counter whose intended payload is provably on disk.
Bindable(c) == oLog[c] \in Unsettled /\ KnownIntent(c) /\ Covered(c)

----------------------------------------------------------------------------
(* Peer-side row updates, one operator per step of recordReceivedEntry. *)

\* The contiguous resolved prefix: the persisted per-host watermark.
Watermark(row) ==
    CHOOSE k \in 0..MaxCounter :
        /\ \A i \in 1..k : row[i] \in Resolved
        /\ k = MaxCounter \/ row[k + 1] \notin Resolved

\* markCoveredCountersAsReceived runs first.
CoverMark(row, cov) ==
    [i \in Counters |->
        IF i \in cov /\ row[i] \in {"none", "missing", "requested"}
        THEN "received" ELSE row[i]]

\* Gap detection: absent rows below the announced counter become missing.
GapFill(row, a) ==
    LET base == Watermark(row) IN
    [i \in Counters |->
        IF i > base /\ i < a /\ row[i] = "none" THEN "missing" ELSE row[i]]

\* The announced counter itself. `burned` is never reopened.
MarkAnnounced(row, a) ==
    [row EXCEPT ![a] =
        CASE row[a] \in {"burned", "received", "backfilled"} -> row[a]
          [] row[a] = "requested" -> "backfilled"
          [] OTHER -> "received"]

ApplyPayload(row, m) == MarkAnnounced(GapFill(CoverMark(row, m.cov), m.a), m.a)

\* A verified hint settles its counter unless that row is already final.
ApplyHint(row, m) ==
    LET r == ApplyPayload(row, m) IN
    [r EXCEPT ![m.c] =
        IF r[m.c] \in {"burned", "received", "backfilled"}
        THEN r[m.c] ELSE "backfilled"]

\* An authoritative burn never downgrades a row that holds a payload.
ApplyBurn(row, c) ==
    [row EXCEPT ![c] =
        IF row[c] \in {"received", "backfilled", "burned"}
        THEN row[c] ELSE "burned"]

----------------------------------------------------------------------------
Init ==
    /\ wm = 0
    /\ pc = [c \in Counters |-> "unused"]
    /\ ent = [c \in Counters |-> NoEntity]
    /\ intent = [c \in Counters |-> FALSE]
    /\ pending = {}
    /\ oLog = [c \in Counters |-> "none"]
    /\ oIntent = [c \in Counters |-> FALSE]
    /\ store = [e \in Entities |-> 0]
    /\ committed = {}
    /\ outbox = [e \in Entities |-> {}]
    /\ net = [p \in Peers |-> {}]
    /\ reqs = {}
    /\ pLog = [p \in Peers |-> [c \in Counters |-> "none"]]
    /\ pVer = [p \in Peers |-> [e \in Entities |-> 0]]
    /\ faults = 0
    /\ crashes = 0

----------------------------------------------------------------------------
(* Settling an own counter: BackfillResponseHandler.settleOwnCounter. Every *)
(* path that settles one without a live write goes through `Settle`.       *)

\* Send the payload again and bind the counter. One step here; in the code
\* the resend is durably enqueued first and the bind follows, and that order
\* is what makes the single step sound: the only other interleaving is a
\* crash between the two, which leaves the row unsettled — the state before
\* settlement plus a duplicate payload in the outbox — so it is settled again.
\* Binding first would instead let a crash hide the counter behind `received`
\* with nothing sent.
BindAndResend(c) ==
    /\ oLog' = [oLog EXCEPT ![c] = "received"]
    /\ outbox' = [outbox EXCEPT ![ent[c]] = @ \cup {c}]

\* Tell the room the counter carries no payload and terminalize the own
\* row. A bound row is skipped.
BurnOwn(c) ==
    IF oLog[c] = "received"
    THEN UNCHANGED <<oLog, net>>
    ELSE /\ net' = ToRoom(BurnMsg(c))
         /\ oLog' = [oLog EXCEPT ![c] = "burned"]

\* A covered intent binds and resends; anything else not bound burns.
Settle(c) ==
    IF Bindable(c)
    THEN /\ BindAndResend(c)
         /\ UNCHANGED net
    ELSE /\ BurnOwn(c)
         /\ UNCHANGED outbox

----------------------------------------------------------------------------
(* The originator's write path. *)

\* Persist-first reservation. The reserve lock is held until the reserved
\* row is written, so the next reservation cannot start before that.
Reserve(e, i) ==
    /\ wm < MaxCounter
    /\ \A c \in Counters : pc[c] # "reserving"
    /\ wm' = wm + 1
    /\ pc' = [pc EXCEPT ![wm + 1] = "reserving"]
    /\ ent' = [ent EXCEPT ![wm + 1] = e]
    /\ intent' = [intent EXCEPT ![wm + 1] = i]
    /\ pending' = pending \cup {wm + 1}
    /\ UNCHANGED <<oLog, oIntent, store, committed, outbox, net, reqs, pLog,
                   pVer, faults, crashes>>

\* recordReservedSequenceCounter: INSERT OR IGNORE, with the intent.
WriteReservedRow(c) ==
    /\ pc[c] = "reserving"
    /\ pc' = [pc EXCEPT ![c] = "reserved"]
    /\ IF oLog[c] = "none"
       THEN /\ oLog' = [oLog EXCEPT ![c] = "reserved"]
            /\ oIntent' = [oIntent EXCEPT ![c] = intent[c]]
       ELSE UNCHANGED <<oLog, oIntent>>
    /\ UNCHANGED <<wm, ent, intent, pending, store, committed, outbox, net,
                   reqs, pLog, pVer, faults, crashes>>

\* The sequence-log insert fails; the reservation, with its intent, is
\* recorded in the settings database instead.
WriteReservedRowFails(c) ==
    /\ CanFault("rowWrite")
    /\ pc[c] = "reserving"
    /\ pc' = [pc EXCEPT ![c] = "reserved"]
    /\ IF oLog[c] = "none"
       THEN /\ oLog' = [oLog EXCEPT ![c] = "fallback"]
            /\ oIntent' = [oIntent EXCEPT ![c] = intent[c]]
       ELSE UNCHANGED <<oLog, oIntent>>
    /\ faults' = faults + 1
    /\ UNCHANGED <<wm, ent, intent, pending, store, committed, outbox, net,
                   reqs, pLog, pVer, crashes>>

\* Neither store takes the reservation: reserving throws, no write follows,
\* and the counter is left with no row at all — truthfully, no payload.
ReservationFails(c) ==
    /\ CanFault("fallbackWrite")
    /\ pc[c] = "reserving"
    /\ pc' = [pc EXCEPT ![c] = "finished"]
    /\ pending' = pending \ {c}
    /\ faults' = faults + 1
    /\ UNCHANGED <<wm, ent, intent, oLog, oIntent, store, committed, outbox,
                   net, reqs, pLog, pVer, crashes>>

\* The payload write lands only if its clock dominates the stored one.
Commit(c) ==
    /\ pc[c] = "reserved"
    /\ store[ent[c]] < c
    /\ store' = [store EXCEPT ![ent[c]] = c]
    /\ committed' = committed \cup {c}
    /\ pc' = [pc EXCEPT ![c] = "committed"]
    /\ UNCHANGED <<wm, ent, intent, pending, oLog, oIntent, outbox, net, reqs,
                   pLog, pVer, faults, crashes>>

\* The write is rejected or throws before landing; the scope releases.
Abort(c) ==
    /\ pc[c] = "reserved"
    /\ pc' = [pc EXCEPT ![c] = "releasing"]
    /\ UNCHANGED <<wm, ent, intent, pending, oLog, oIntent, store, committed,
                   outbox, net, reqs, pLog, pVer, faults, crashes>>

\* A post-commit step throws and an outer scope reads the write as failed.
ThrowAfterCommit(c) ==
    /\ CanFault("throwAfterCommit")
    /\ pc[c] = "committed"
    /\ pc' = [pc EXCEPT ![c] = "releasing"]
    /\ faults' = faults + 1
    /\ UNCHANGED <<wm, ent, intent, pending, oLog, oIntent, store, committed,
                   outbox, net, reqs, pLog, pVer, crashes>>

\* The outbox inserts (or merges into) the entity's pending row, then binds.
Enqueue(c) ==
    /\ pc[c] = "committed"
    /\ pc' = [pc EXCEPT ![c] = "finished"]
    /\ oLog' = [oLog EXCEPT ![c] = "received"]
    /\ pending' = pending \ {c}
    /\ outbox' = [outbox EXCEPT ![ent[c]] = @ \cup {c}]
    /\ UNCHANGED <<wm, ent, intent, oIntent, store, committed, net, reqs,
                   pLog, pVer, faults, crashes>>

\* The outbox row is written but the bind after it fails.
EnqueueBindFails(c) ==
    /\ CanFault("bind")
    /\ pc[c] = "committed"
    /\ pc' = [pc EXCEPT ![c] = "finished"]
    /\ outbox' = [outbox EXCEPT ![ent[c]] = @ \cup {c}]
    /\ faults' = faults + 1
    /\ UNCHANGED <<wm, ent, intent, pending, oLog, oIntent, store, committed,
                   net, reqs, pLog, pVer, crashes>>

EnqueueFails(c) ==
    /\ CanFault("enqueue")
    /\ pc[c] = "committed"
    /\ pc' = [pc EXCEPT ![c] = "finished"]
    /\ faults' = faults + 1
    /\ UNCHANGED <<wm, ent, intent, pending, oLog, oIntent, store, committed,
                   outbox, net, reqs, pLog, pVer, crashes>>

\* The reservation leaves the pending map and an unsettled row becomes
\* burnPending, recording the reservation's intent. Whether the counter is
\* burned is decided afterwards, by Settle, so a release can never burn a
\* counter whose intended payload is on disk.
Release(c) ==
    /\ pc[c] = "releasing"
    /\ pc' = [pc EXCEPT ![c] = "broadcasting"]
    /\ pending' = pending \ {c}
    /\ IF oLog[c] \in Unsettled
       THEN /\ oLog' = [oLog EXCEPT ![c] = "burnPending"]
            /\ oIntent' = [oIntent EXCEPT ![c] = @ \/ intent[c]]
       ELSE UNCHANGED <<oLog, oIntent>>
    /\ UNCHANGED <<wm, ent, intent, store, committed, outbox, net, reqs,
                   pLog, pVer, faults, crashes>>

\* The burn handler, invoked by the release.
Broadcast(c) ==
    /\ pc[c] = "broadcasting"
    /\ pc' = [pc EXCEPT ![c] = "finished"]
    /\ Settle(c)
    /\ UNCHANGED <<wm, ent, intent, pending, oIntent, store, committed, reqs,
                   pLog, pVer, faults, crashes>>

BroadcastFails(c) ==
    /\ CanFault("broadcast")
    /\ pc[c] = "broadcasting"
    /\ pc' = [pc EXCEPT ![c] = "finished"]
    /\ faults' = faults + 1
    /\ UNCHANGED <<wm, ent, intent, pending, oLog, oIntent, store, committed,
                   outbox, net, reqs, pLog, pVer, crashes>>

\* Startup: a burnPending row whose burn handler never finished.
ReconcileBurn(c) ==
    /\ oLog[c] = "burnPending"
    /\ c \notin pending
    /\ pc[c] \notin InFlight
    /\ Settle(c)
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oIntent, store, committed,
                   reqs, pLog, pVer, faults, crashes>>

\* Startup: a settings-database reservation moves into the sequence log.
MigrateFallback(c) ==
    /\ oLog[c] = "fallback"
    /\ oLog' = [oLog EXCEPT ![c] = "reserved"]
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oIntent, store, committed,
                   outbox, net, reqs, pLog, pVer, faults, crashes>>

\* Startup: a named reservation an earlier process left behind.
ResolveOrphan(c) ==
    /\ oLog[c] \in ReservedRow
    /\ oIntent[c]
    /\ c \notin pending
    /\ Settle(c)
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oIntent, store, committed,
                   reqs, pLog, pVer, faults, crashes>>

\* The process dies: in-flight writes and the pending map are gone.
Crash ==
    /\ crashes < MaxCrashes
    /\ \E c \in Counters : pc[c] \in InFlight
    /\ pc' = [c \in Counters |-> IF pc[c] \in InFlight THEN "dead" ELSE pc[c]]
    /\ pending' = {}
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<wm, ent, intent, oLog, oIntent, store, committed, outbox,
                   net, reqs, pLog, pVer, faults>>

\* Send the entity's pending outbox row. The file is read at send time.
OutboxSend(e) ==
    /\ outbox[e] # {}
    /\ LET a == Max(outbox[e]) IN
       net' = ToRoom(PayloadMsg(e, a, store[e], outbox[e] \ {a}))
    /\ outbox' = [outbox EXCEPT ![e] = {}]
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oLog, oIntent, store,
                   committed, reqs, pLog, pVer, faults, crashes>>

\* A request the originator must leave open: this process may still land
\* the counter, or its row does not say which payload it was for.
Deferred(c) ==
    /\ oLog[c] \in Unsettled
    /\ ~Bindable(c)
    /\ \/ c \in pending
       \/ oLog[c] \in ReservedRow /\ ~oIntent[c]

\* BackfillResponseHandler for an own-host counter.
Respond(p, c) ==
    /\ <<p, c>> \in reqs
    /\ ~Deferred(c)
    /\ reqs' = reqs \ {<<p, c>>}
    /\ CASE oLog[c] = "received" ->
              /\ net' = ToRoom(HintMsg(ent[c], store[ent[c]], c))
              /\ UNCHANGED oLog
         [] Bindable(c) ->
              /\ oLog' = [oLog EXCEPT ![c] = "received"]
              /\ net' = ToRoom(HintMsg(ent[c], store[ent[c]], c))
         [] OTHER ->
              BurnOwn(c)
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oIntent, store, committed,
                   outbox, pLog, pVer, faults, crashes>>

OriginatorStep ==
    \/ \E e \in Entities, i \in IntentChoices : Reserve(e, i)
    \/ \E e \in Entities : OutboxSend(e)
    \/ \E c \in Counters :
          \/ WriteReservedRow(c) \/ WriteReservedRowFails(c)
          \/ ReservationFails(c) \/ MigrateFallback(c)
          \/ Commit(c) \/ Abort(c) \/ ThrowAfterCommit(c)
          \/ Enqueue(c) \/ EnqueueBindFails(c) \/ EnqueueFails(c)
          \/ Release(c) \/ Broadcast(c) \/ BroadcastFails(c)
          \/ ReconcileBurn(c) \/ ResolveOrphan(c)
    \/ \E p \in Peers, c \in Counters : Respond(p, c)
    \/ Crash

----------------------------------------------------------------------------
(* Peers. *)

Deliver(p, m) ==
    /\ m \in net[p]
    /\ net' = [net EXCEPT ![p] = @ \ {m}]
    /\ pLog' = [pLog EXCEPT ![p] =
                  CASE m.type = "payload" -> ApplyPayload(@, m)
                    [] m.type = "hint" -> ApplyHint(@, m)
                    [] m.type = "burn" -> ApplyBurn(@, m.c)]
    /\ pVer' = IF m.type \in {"payload", "hint"} /\ m.v > pVer[p][m.e]
               THEN [pVer EXCEPT ![p][m.e] = m.v] ELSE pVer
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oLog, oIntent, store,
                   committed, outbox, reqs, faults, crashes>>

\* The inbound queue abandons an event for good.
Lose(p, m) ==
    /\ CanFault("loss")
    /\ m \in net[p]
    /\ net' = [net EXCEPT ![p] = @ \ {m}]
    /\ faults' = faults + 1
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oLog, oIntent, store,
                   committed, outbox, reqs, pLog, pVer, crashes>>

\* BackfillRequestService: ask (again) for a missing or requested counter.
Request(p, c) ==
    /\ pLog[p][c] \in {"missing", "requested"}
    /\ <<p, c>> \notin reqs
    /\ reqs' = reqs \cup {<<p, c>>}
    /\ pLog' = [pLog EXCEPT ![p][c] = "requested"]
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oLog, oIntent, store,
                   committed, outbox, net, pVer, faults, crashes>>

\* Retry exhaustion or amnesty. Never forced by fairness: giving up must
\* not be how the protocol makes progress.
GiveUp(p, c) ==
    /\ pLog[p][c] \in {"missing", "requested"}
    /\ pLog' = [pLog EXCEPT ![p][c] = "unresolvable"]
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oLog, oIntent, store,
                   committed, outbox, net, reqs, pVer, faults, crashes>>

\* "Ask peers again for unresolvable".
AskAgain(p, c) ==
    /\ pLog[p][c] = "unresolvable"
    /\ pLog' = [pLog EXCEPT ![p][c] = "missing"]
    /\ UNCHANGED <<wm, pc, ent, intent, pending, oLog, oIntent, store,
                   committed, outbox, net, reqs, pVer, faults, crashes>>

PeerStep ==
    \E p \in Peers :
        \/ \E m \in net[p] : Deliver(p, m) \/ Lose(p, m)
        \/ \E c \in Counters : Request(p, c) \/ GiveUp(p, c) \/ AskAgain(p, c)

Next == OriginatorStep \/ PeerStep

\* Everything the implementation does on its own eventually happens. User
\* writes (Reserve), faults, crashes and giving up are never forced.
Fairness ==
    /\ \A c \in Counters :
          /\ WF_vars(WriteReservedRow(c))
          /\ WF_vars(Commit(c) \/ Abort(c))
          /\ WF_vars(Enqueue(c))
          /\ WF_vars(Release(c))
          /\ WF_vars(Broadcast(c))
          /\ WF_vars(ReconcileBurn(c))
          /\ WF_vars(ResolveOrphan(c))
          /\ WF_vars(MigrateFallback(c))
    /\ \A e \in Entities : WF_vars(OutboxSend(e))
    /\ \A p \in Peers :
          /\ WF_vars(\E m \in net[p] : Deliver(p, m))
          /\ \A c \in Counters : WF_vars(Request(p, c)) /\ WF_vars(Respond(p, c))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ wm \in 0..MaxCounter
    /\ pc \in [Counters -> PcStates]
    /\ ent \in [Counters -> Entities \cup {NoEntity}]
    /\ intent \in [Counters -> BOOLEAN]
    /\ pending \subseteq Counters
    /\ oLog \in [Counters -> OwnStatus]
    /\ oIntent \in [Counters -> BOOLEAN]
    /\ store \in [Entities -> 0..MaxCounter]
    /\ committed \subseteq Counters
    /\ outbox \in [Entities -> SUBSET Counters]
    /\ reqs \subseteq Peers \X Counters
    /\ pLog \in [Peers -> [Counters -> PeerStatus]]
    /\ pVer \in [Peers -> [Entities -> 0..MaxCounter]]

\* A burn is a promise that the counter carries no payload. Breaking it
\* tells every peer to stop looking for data that exists.
NoFalseBurn ==
    \A c \in committed :
        /\ oLog[c] # "burned"
        /\ \A p \in Peers : pLog[p][c] # "burned"

\* A peer that marks a counter received really holds that data, or a newer
\* version of the same entity.
ReceivedIsReal ==
    \A p \in Peers, c \in Counters :
        pLog[p][c] \in {"received", "backfilled"} => pVer[p][ent[c]] >= c

\* The originator never answers from a row whose payload is not on disk.
BoundRowsHavePayload ==
    \A c \in Counters : oLog[c] = "received" => Covered(c)

\* `burned` has no outgoing edge, on any device.
BurnedIsTerminal ==
    [][/\ \A c \in Counters : oLog[c] = "burned" => oLog'[c] = "burned"
       /\ \A p \in Peers, c \in Counters :
             pLog[p][c] = "burned" => pLog'[p][c] = "burned"]_vars

HoldsWrite(p, c) == ent[c] # NoEntity /\ pVer[p][ent[c]] >= c

\* Every committed write eventually reaches every peer, directly or as a
\* newer version of the same entity.
EventuallyDelivered ==
    \A c \in Counters, p \in Peers :
        (c \in committed) ~> HoldsWrite(p, c)

\* No request stays open forever: every gap is eventually settled by the
\* protocol, not only by giving up.
NoStuckRequest ==
    \A p \in Peers, c \in Counters :
        (pLog[p][c] = "requested") ~> (pLog[p][c] # "requested")
=============================================================================
