------------------------- MODULE AgentWakeCoordination -------------------------
(***************************************************************************)
(* Cross-device coordination of one task agent's wakes. The same agent is  *)
(* replicated on every device, and each device wakes it on its own local   *)
(* edits. When edits on two devices sync into the same task state, both    *)
(* devices would run the agent over the same inputs. The protocol lets one *)
(* of them run and the others stand down:                                  *)
(*                                                                         *)
(*   - a device that dispatches a wake broadcasts claim(h), h being the    *)
(*     digest of the task state the wake reads, and repeats it every       *)
(*     Heartbeat while the run is live;                                    *)
(*   - on success it broadcasts done(h), on failure or abort release(h);   *)
(*   - a device holding a live peer claim for its own current digest does  *)
(*     not dispatch; the claim lapses Timeout after it was last received,  *)
(*     and every message from that peer re-arms it;                        *)
(*   - a device that has received a peer's done(h) for its own current     *)
(*     digest drops its pending wake: the peer already processed exactly   *)
(*     this state. The digests of a peer's completed runs are kept apart   *)
(*     from its live claim, so its next claim does not erase them;         *)
(*   - a digest mismatch is new work and runs regardless.                  *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Edit          a local journal edit: localUpdateStream -> a wake job   *)
(*   SyncEdits     journal replication merging a peer's state; a synced    *)
(*                 audio entry may also queue a content wake (WakeOnSync)  *)
(*   Dispatch      WakeDrainEngine._drain: AgentWakeCoordinator.evaluate   *)
(*                 returns proceed, and claim() broadcasts the claim       *)
(*   Cancel        evaluate returns cancel: the job is dropped and its     *)
(*                 intent settled as covered by the peer's run             *)
(*   Beat          AgentWakeCoordinator's heartbeat timer                  *)
(*   Complete      a successful run: complete() broadcasts done(h)         *)
(*   Fail          a failed or aborted run: settle() broadcasts release;   *)
(*                 the wake stays owed                                     *)
(*   Crash         process death; WakeIntentStore restores the owed wake,  *)
(*                 the coordinator's in-memory peer view is lost           *)
(*   Deliver       SyncEventProcessor -> AgentWakeCoordinator.onMessage;   *)
(*                 the outbox sends one sender's rows in order, and the    *)
(*                 receiver drops a row older than the last it applied,    *)
(*                 so each (sender, receiver) channel behaves as FIFO      *)
(*   Lose          a message that never arrives                            *)
(*   Tick          wall-clock time; it cannot pass a message's delivery    *)
(*                 bound, a live run's heartbeat or its run cap            *)
(*                                                                         *)
(* Digests are modelled as the set of edits a device's state holds, so     *)
(* equal digests mean equal state and there are no collisions. Time is     *)
(* relative: messages, claims and runs carry ages or remaining time, which *)
(* keeps the state space finite without an absolute clock.                 *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, Sequences

CONSTANTS
    Devices,
    MaxEdits,        \* bound on edits
    Timeout,         \* coordination timer (2 minutes)
    Heartbeat,       \* claim repeat interval while running
    MaxDelay,        \* message delivery bound
    RunCap,          \* a run completes, fails or crashes within this
    MaxFailures,     \* bound on failed runs
    MaxCrashes,      \* bound on crashes
    MaxLosses,       \* bound on lost messages
    WakeOnSync,      \* a synced edit may queue a wake on the receiver
    \* Switches: TRUE is the implemented protocol, FALSE the mutation.
    CompareHash,     \* defer and cancel only on a matching digest
    SendHeartbeat,   \* repeat the claim while running
    ReArmOnMessage,  \* every received message restarts the timer
    DoneCancels,     \* done(h) cancels a matching pending wake
    ClaimsLapse,     \* a claim no message re-arms lapses after Timeout
    KeepDoneHistory  \* a peer's done digests outlive its next claim

ASSUME Timeout > Heartbeat + MaxDelay

Edits == 1..MaxEdits
Kinds == {"claim", "done", "release"}
NoRun == [live |-> FALSE]
\* A device's view of one peer: its live claim (the digest and the time
\* left on the timer) and the digests of the runs it completed.
Fresh == [claimed |-> FALSE, hash |-> {}, left |-> 0, done |-> {}]
\* Ages only matter up to the point where a claim is certainly delivered.
Settled == MaxDelay + 1

VARIABLES
    nextEdit,
    seen,       \* per device: the edits its task state holds (its digest)
    pending,    \* per device: a wake job is owed
    run,        \* per device: the live run [hash, age, beat], or NoRun
    peer,       \* per device, per peer: [claimed, hash, left, done]
    chan,       \* per (sender, receiver): FIFO of in-flight [kind, hash, age]
    ok,         \* ghost, per device: [hash, age] of its successful runs,
                \* age counted from the run's claim
    dup,        \* ghost: a run started over a peer's known run
    okHashes,   \* ghost: every digest some successful run processed
    cancels,    \* ghost: every cancelled wake's digest
    failures,
    crashes,
    losses

vars == <<nextEdit, seen, pending, run, peer, chan, ok, dup, okHashes,
          cancels, failures, crashes, losses>>

Pairs == {<<s, r>> \in Devices \X Devices : s # r}

Init ==
    /\ nextEdit = 1
    /\ seen = [d \in Devices |-> {}]
    /\ pending = [d \in Devices |-> FALSE]
    /\ run = [d \in Devices |-> NoRun]
    /\ peer = [d \in Devices |-> [p \in Devices |-> Fresh]]
    /\ chan = [c \in Pairs |-> <<>>]
    /\ ok = [d \in Devices |-> {}]
    /\ dup = FALSE
    /\ okHashes = {}
    /\ cancels = {}
    /\ failures = 0
    /\ crashes = 0
    /\ losses = 0

\* Append one message from d to every peer.
Broadcast(d, kind, h) ==
    chan' = [c \in Pairs |->
               IF c[1] = d
               THEN Append(chan[c], [kind |-> kind, hash |-> h, age |-> 0])
               ELSE chan[c]]

Matches(d, h) == CompareHash => h = seen[d]

\* A live peer claim for this device's own state holds its wake back.
Blocked(d) ==
    \E p \in Devices \ {d} :
        /\ peer[d][p].claimed
        /\ Matches(d, peer[d][p].hash)
        /\ peer[d][p].left > 0

\* A peer already ran a wake over exactly this state.
Covered(d) ==
    /\ DoneCancels
    /\ \E p \in Devices \ {d} : \E h \in peer[d][p].done : Matches(d, h)

\* A peer is running, or successfully ran, a wake over d's current state,
\* and its claim has certainly reached d.
KnownRun(d) ==
    \E p \in Devices \ {d} :
        \/ /\ run[p].live
           /\ run[p].hash = seen[d]
           /\ run[p].age >= Settled
        \/ [hash |-> seen[d], age |-> Settled] \in ok[p]

Inc(n) == IF n < Settled THEN n + 1 ELSE n

----------------------------------------------------------------------------
(* State. *)

Edit(d) ==
    /\ nextEdit <= MaxEdits
    /\ seen' = [seen EXCEPT ![d] = @ \cup {nextEdit}]
    /\ pending' = [pending EXCEPT ![d] = TRUE]
    /\ nextEdit' = nextEdit + 1
    /\ UNCHANGED <<run, peer, chan, ok, dup, okHashes, cancels, failures,
                   crashes, losses>>

\* Journal replication: d receives s's state. Sync-originated changes do
\* not wake agents, except a synced audio entry's content wake.
SyncEdits(s, d) ==
    /\ s # d
    /\ ~(seen[s] \subseteq seen[d])
    /\ seen' = [seen EXCEPT ![d] = @ \cup seen[s]]
    /\ \E w \in IF WakeOnSync THEN BOOLEAN ELSE {FALSE} :
          pending' = [pending EXCEPT ![d] = @ \/ w]
    /\ UNCHANGED <<nextEdit, run, peer, chan, ok, dup, okHashes, cancels,
                   failures, crashes, losses>>

----------------------------------------------------------------------------
(* Wakes. *)

Dispatch(d) ==
    /\ pending[d]
    /\ ~run[d].live
    /\ ~Covered(d)
    /\ ~Blocked(d)
    /\ dup' = (dup \/ KnownRun(d))
    /\ run' = [run EXCEPT ![d] = [live |-> TRUE, hash |-> seen[d],
                                  age |-> 0, beat |-> 0]]
    /\ pending' = [pending EXCEPT ![d] = FALSE]
    /\ Broadcast(d, "claim", seen[d])
    /\ UNCHANGED <<nextEdit, seen, peer, ok, okHashes, cancels, failures,
                   crashes, losses>>

Cancel(d) ==
    /\ pending[d]
    /\ ~run[d].live
    /\ Covered(d)
    /\ pending' = [pending EXCEPT ![d] = FALSE]
    /\ cancels' = cancels \cup {seen[d]}
    /\ UNCHANGED <<nextEdit, seen, run, peer, chan, ok, dup, okHashes,
                   failures, crashes, losses>>

Beat(d) ==
    /\ SendHeartbeat
    /\ run[d].live
    /\ run[d].beat >= Heartbeat
    /\ run' = [run EXCEPT ![d].beat = 0]
    /\ Broadcast(d, "claim", run[d].hash)
    /\ UNCHANGED <<nextEdit, seen, pending, peer, ok, dup, okHashes, cancels,
                   failures, crashes, losses>>

Complete(d) ==
    /\ run[d].live
    /\ run' = [run EXCEPT ![d] = NoRun]
    /\ ok' = [ok EXCEPT ![d] =
                @ \cup {[hash |-> run[d].hash,
                         age |-> IF run[d].age >= Settled THEN Settled
                                 ELSE run[d].age]}]
    /\ okHashes' = okHashes \cup {run[d].hash}
    /\ Broadcast(d, "done", run[d].hash)
    /\ UNCHANGED <<nextEdit, seen, pending, peer, dup, cancels, failures,
                   crashes, losses>>

\* A failed or aborted run: its triggers stay owed (WakeRuntime NoLostWake).
Fail(d) ==
    /\ run[d].live
    /\ failures < MaxFailures
    /\ failures' = failures + 1
    /\ run' = [run EXCEPT ![d] = NoRun]
    /\ pending' = [pending EXCEPT ![d] = TRUE]
    /\ Broadcast(d, "release", run[d].hash)
    /\ UNCHANGED <<nextEdit, seen, peer, ok, dup, okHashes, cancels, crashes,
                   losses>>

\* Process death and restart. The durable outbox keeps what was sent; the
\* wake intent brings a running or owed wake back; the peer view is lost.
Crash(d) ==
    /\ crashes < MaxCrashes
    /\ crashes' = crashes + 1
    /\ pending' = [pending EXCEPT ![d] = @ \/ run[d].live]
    /\ run' = [run EXCEPT ![d] = NoRun]
    /\ peer' = [peer EXCEPT ![d] = [p \in Devices |-> Fresh]]
    /\ UNCHANGED <<nextEdit, seen, chan, ok, dup, okHashes, cancels, failures,
                   losses>>

----------------------------------------------------------------------------
(* Messages. *)

Deliver(s, d) ==
    /\ s # d
    /\ chan[<<s, d>>] # <<>>
    /\ LET m == Head(chan[<<s, d>>])
           old == peer[d][s]
           \* Without re-arming, a repeated claim for the same state keeps
           \* the time its first copy left.
           left == IF ~ReArmOnMessage /\ old.claimed /\ old.hash = m.hash
                   THEN old.left ELSE Timeout
           done == IF KeepDoneHistory THEN old.done ELSE {}
       IN peer' = [peer EXCEPT ![d][s] =
                     CASE m.kind = "claim" ->
                            [claimed |-> TRUE, hash |-> m.hash, left |-> left,
                             done |-> done]
                       [] m.kind = "done" ->
                            [Fresh EXCEPT !.done = done \cup {m.hash}]
                       [] m.kind = "release" ->
                            [Fresh EXCEPT !.done = old.done]]
    /\ chan' = [chan EXCEPT ![<<s, d>>] = Tail(@)]
    /\ UNCHANGED <<nextEdit, seen, pending, run, ok, dup, okHashes, cancels,
                   failures, crashes, losses>>

Lose(s, d) ==
    /\ s # d
    /\ chan[<<s, d>>] # <<>>
    /\ losses < MaxLosses
    /\ losses' = losses + 1
    /\ chan' = [chan EXCEPT ![<<s, d>>] = Tail(@)]
    /\ UNCHANGED <<nextEdit, seen, pending, run, peer, ok, dup, okHashes,
                   cancels, failures, crashes>>

\* One unit of time passes. It cannot pass a message's delivery bound, a
\* live run's cap, or a heartbeat that is due.
Tick ==
    /\ \A c \in Pairs :
          \A i \in 1..Len(chan[c]) : chan[c][i].age < MaxDelay
    /\ \A d \in Devices :
          run[d].live =>
              /\ run[d].age < RunCap
              /\ SendHeartbeat => run[d].beat < Heartbeat
    /\ chan' = [c \in Pairs |->
                  [i \in 1..Len(chan[c]) |->
                     [chan[c][i] EXCEPT !.age = @ + 1]]]
    /\ run' = [d \in Devices |->
                 IF run[d].live
                 THEN [run[d] EXCEPT !.age = @ + 1, !.beat = @ + 1]
                 ELSE run[d]]
    /\ peer' = [d \in Devices |-> [p \in Devices |->
                  IF ClaimsLapse /\ peer[d][p].left > 0
                  THEN [peer[d][p] EXCEPT !.left = @ - 1]
                  ELSE peer[d][p]]]
    /\ ok' = [d \in Devices |-> {[r EXCEPT !.age = Inc(@)] : r \in ok[d]}]
    /\ <<chan', run', peer', ok'>> # <<chan, run, peer, ok>>
    /\ UNCHANGED <<nextEdit, seen, pending, dup, okHashes, cancels, failures,
                   crashes, losses>>

Next ==
    \/ \E d \in Devices :
          \/ Edit(d) \/ Dispatch(d) \/ Cancel(d) \/ Beat(d)
          \/ Complete(d) \/ Fail(d) \/ Crash(d)
    \/ \E s, d \in Devices : SyncEdits(s, d) \/ Deliver(s, d) \/ Lose(s, d)
    \/ Tick

Fairness ==
    /\ WF_vars(Tick)
    /\ \A d \in Devices :
          /\ WF_vars(Dispatch(d))
          /\ WF_vars(Cancel(d))
          /\ WF_vars(Beat(d))
          /\ WF_vars(Complete(d))
    /\ \A s, d \in Devices :
          /\ WF_vars(Deliver(s, d))
          /\ WF_vars(SyncEdits(s, d))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ nextEdit \in 1..(MaxEdits + 1)
    /\ \A d \in Devices :
          /\ seen[d] \subseteq Edits
          /\ pending[d] \in BOOLEAN
          /\ run[d].live => run[d].age \in 0..RunCap
    /\ \A d, p \in Devices :
          /\ peer[d][p].claimed \in BOOLEAN
          /\ peer[d][p].left \in 0..Timeout
          /\ peer[d][p].done \subseteq SUBSET Edits
    /\ \A c \in Pairs : \A i \in 1..Len(chan[c]) :
          /\ chan[c][i].kind \in Kinds
          /\ chan[c][i].age \in 0..MaxDelay
    /\ dup \in BOOLEAN

\* The protocol's promise. No run starts over a state a peer is running, or
\* already ran successfully, once that peer's claim has certainly arrived.
\* Duplicates remain only where claims cross within one delivery delay, or
\* where a message is lost or a crash erases the receiver's view (the
\* configurations that allow those do not check this).
Exclusive == ~dup

\* A wake is dropped only when some device completed a run over exactly the
\* state the dropping device holds: nothing it would read goes unprocessed.
CancelCovered == cancels \subseteq okHashes

\* Every owed wake is eventually run or cancelled: a deferral never
\* becomes a deadlock, even when the claiming peer crashes or its done is
\* lost.
OwedWakeSettles == \A d \in Devices : pending[d] ~> ~pending[d]

\* Every edit is eventually processed by a successful run whose state
\* includes it, on some device.
NoLostEdit ==
    \A e \in Edits : (e < nextEdit) ~> (\E h \in okHashes : e \in h)
=============================================================================
