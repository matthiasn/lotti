---------------------------- MODULE EnvelopeChain ----------------------------
(***************************************************************************)
(* A DESIGN MODEL, written before the code: each device's signed,          *)
(* hash-linked chain of provenance envelopes for one store (per-store      *)
(* chains share nothing, so one store stands for all). Phase 1 built the   *)
(* envelope (lib/features/provenance); the key store, the chain in the     *)
(* write path and verification on ingest are still to come, and must      *)
(* conform to this model. The action-to-code map below fills in as they    *)
(* land.                                                                   *)
(*                                                                         *)
(* What is modelled:                                                       *)
(*                                                                         *)
(*   Write       a device signs its next envelope: seq one past its chain  *)
(*               head, prev the head's hash, under its current key         *)
(*   Reserve,    the same with seq taken from a separate durable counter   *)
(*   Commit,     (only when ~AtomicSeq): a crash between reserving the     *)
(*   Crash       seq and committing the envelope loses the reservation     *)
(*   Restore     the device's database comes back from an older backup;    *)
(*               its key, in the platform keystore, does not               *)
(*   Prune       the room forgets an envelope: the 30-day retention, or a  *)
(*               lost delivery                                             *)
(*   Accept      a receiver applies an envelope from the room or from a    *)
(*               peer's backfill, only when it extends the chain it holds  *)
(*               (invariant I3), and never past a revocation it knows      *)
(*   DetectFork  a receiver sees a second envelope for a seq it holds      *)
(*               (invariant I4): a security event, never resolved          *)
(*   Revoke,     the identity key revokes a device's key at the last seq   *)
(*   Learn       the revoker holds; the revocation reaches each device     *)
(*               (invariant I2)                                            *)
(*                                                                         *)
(* Signatures are abstracted: every envelope in the model is validly       *)
(* signed by the key it names (I1), and keys are certified (I2's           *)
(* certification half). Causal refs (I6) are left to a later spec.         *)
(*                                                                         *)
(* The four design switches are the proposed design; setting one to FALSE  *)
(* produces its counterexample (README).                                   *)
(***************************************************************************)
EXTENDS Integers, Sequences, FiniteSets

CONSTANTS
    N,                      \* devices 1..N
    MaxWrites,              \* envelopes signed, across all devices
    MaxRestores,            \* database restores, across all devices
    MaxRevocations,         \* revocations issued
    AtomicSeq,              \* seq comes from the chain, in the write's transaction
    RotateKeyOnRestore,     \* a restored device signs under a fresh key
    ServeEnvelopeLog,       \* backfill serves any envelope a peer holds
    RetroactiveRevocation   \* learning a revocation drops what lies beyond it

ASSUME /\ N \in Nat \ {0}
       /\ {MaxWrites, MaxRestores, MaxRevocations} \subseteq Nat
       /\ \A b \in {AtomicSeq, RotateKeyOnRestore, ServeEnvelopeLog,
                    RetroactiveRevocation} : b \in BOOLEAN

D == 1..N
None == 0                   \* the prev of a genesis envelope; wids start at 1
NoRes == -1                 \* no seq reserved

\* An envelope: its identity (standing for its hash), the device and key that
\* signed it, its seq, and the wid of the envelope it follows.
Chain(e) == <<e.dev, e.key>>
Last(s) == s[Len(s)]

VARIABLES
    log,        \* per device: its chain under its current key, oldest first
    held,       \* per device: its own envelopes still in its database
    nextSeq,    \* per device: the durable seq counter (used when ~AtomicSeq)
    res,        \* per device: a seq reserved but not yet committed
    key,        \* per device: its current key's epoch
    signed,     \* every envelope ever signed
    room,       \* envelopes the room still holds
    acc,        \* per device: other devices' envelopes it has accepted
    revs,       \* revocations issued: [chain, last]
    known,      \* per device: revocations it has learned
    forkSeen,   \* per device: whether it has seen a fork
    nwid,       \* the next envelope id
    restores    \* restores so far

vars == <<log, held, nextSeq, res, key, signed, room, acc, revs, known,
          forkSeen, nwid, restores>>

Init ==
    /\ log = [d \in D |-> <<>>]
    /\ held = [d \in D |-> {}]
    /\ nextSeq = [d \in D |-> 0]
    /\ res = [d \in D |-> NoRes]
    /\ key = [d \in D |-> 1]
    /\ signed = {}
    /\ room = {}
    /\ acc = [d \in D |-> {}]
    /\ revs = {}
    /\ known = [d \in D |-> {}]
    /\ forkSeen = [d \in D |-> FALSE]
    /\ nwid = 1
    /\ restores = 0

\* The envelope device d signs next, at seq s.
NewEnv(d, s) ==
    [wid |-> nwid, dev |-> d, key |-> key[d], seq |-> s,
     prev |-> IF log[d] = <<>> THEN None ELSE Last(log[d]).wid]

\* Sign, store with the row, and send. The chain and the store move together.
Store(d, e) ==
    /\ log' = [log EXCEPT ![d] = Append(@, e)]
    /\ held' = [held EXCEPT ![d] = @ \cup {e}]
    /\ signed' = signed \cup {e}
    /\ room' = room \cup {e}
    /\ nwid' = nwid + 1

\* The design: seq is the chain's length, read in the write's transaction.
Write(d) ==
    /\ AtomicSeq
    /\ nwid <= MaxWrites
    /\ Store(d, NewEnv(d, Len(log[d])))
    /\ nextSeq' = [nextSeq EXCEPT ![d] = Len(log[d]) + 1]
    /\ UNCHANGED <<res, key, acc, revs, known, forkSeen, restores>>

\* The alternative: a durable counter, advanced before the envelope commits.
Reserve(d) ==
    /\ ~AtomicSeq
    /\ nwid <= MaxWrites
    /\ res[d] = NoRes
    /\ res' = [res EXCEPT ![d] = nextSeq[d]]
    /\ nextSeq' = [nextSeq EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<log, held, key, signed, room, acc, revs, known, forkSeen,
                   nwid, restores>>

Commit(d) ==
    /\ res[d] # NoRes
    /\ Store(d, NewEnv(d, res[d]))
    /\ res' = [res EXCEPT ![d] = NoRes]
    /\ UNCHANGED <<nextSeq, key, acc, revs, known, forkSeen, restores>>

\* The process dies between reserving and committing.
Crash(d) ==
    /\ res[d] # NoRes
    /\ res' = [res EXCEPT ![d] = NoRes]
    /\ UNCHANGED <<log, held, nextSeq, key, signed, room, acc, revs, known,
                   forkSeen, nwid, restores>>

\* The database comes back from a backup that held the first k envelopes of
\* the chain. The key lives in the keystore and survives. The design signs
\* on under a fresh key: a new chain, certified by the identity key.
Restore(d) ==
    /\ restores < MaxRestores
    /\ log[d] # <<>>
    /\ \E k \in 0..(Len(log[d]) - 1) :
         LET lost == {e \in held[d] : e.key = key[d] /\ e.seq >= k}
         IN /\ held' = [held EXCEPT ![d] = @ \ lost]
            /\ IF RotateKeyOnRestore
               THEN /\ key' = [key EXCEPT ![d] = @ + 1]
                    /\ log' = [log EXCEPT ![d] = <<>>]
                    /\ nextSeq' = [nextSeq EXCEPT ![d] = 0]
               ELSE /\ log' = [log EXCEPT ![d] = SubSeq(@, 1, k)]
                    /\ nextSeq' = [nextSeq EXCEPT ![d] = k]
                    /\ UNCHANGED key
    /\ res' = [res EXCEPT ![d] = NoRes]
    /\ restores' = restores + 1
    /\ UNCHANGED <<signed, room, acc, revs, known, forkSeen, nwid>>

Prune ==
    /\ \E e \in room : room' = room \ {e}
    /\ UNCHANGED <<log, held, nextSeq, res, key, signed, acc, revs, known,
                   forkSeen, nwid, restores>>

\* What device p can hand out: its own envelopes and those it accepted.
Held(p) == held[p] \cup acc[p]

\* Backfill: the design serves any envelope a peer holds. The alternative
\* is what journal backfill does today, answering with the writer's current
\* row: only a chain's latest envelope.
Backfill(r) ==
    IF ServeEnvelopeLog
    THEN UNION {Held(p) : p \in D \ {r}}
    ELSE {Last(log[p]) : p \in {q \in D \ {r} : log[q] # <<>>}}

Available(r) == room \cup Backfill(r)

\* e lies past a revocation in R.
Beyond(R, e) == \E v \in R : v.chain = Chain(e) /\ e.seq > v.last

\* e extends the chain r holds (I3), and r holds nothing at its seq.
Extends(r, e) ==
    /\ ~\E a \in acc[r] : Chain(a) = Chain(e) /\ a.seq = e.seq
    /\ IF e.seq = 0
       THEN e.prev = None
       ELSE \E p \in acc[r] : /\ Chain(p) = Chain(e)
                              /\ p.wid = e.prev
                              /\ p.seq = e.seq - 1

Accept(r) ==
    /\ \E e \in Available(r) :
         /\ e.dev # r
         /\ e \notin acc[r]
         /\ Extends(r, e)
         /\ ~Beyond(known[r], e)
         /\ acc' = [acc EXCEPT ![r] = @ \cup {e}]
    /\ UNCHANGED <<log, held, nextSeq, res, key, signed, room, revs, known,
                   forkSeen, nwid, restores>>

DetectFork(r) ==
    /\ ~forkSeen[r]
    /\ \E e \in Available(r), a \in acc[r] :
         Chain(a) = Chain(e) /\ a.seq = e.seq /\ a # e
    /\ forkSeen' = [forkSeen EXCEPT ![r] = TRUE]
    /\ UNCHANGED <<log, held, nextSeq, res, key, signed, room, acc, revs,
                   known, nwid, restores>>

\* The identity key, on device r, revokes another device's key. The last
\* valid seq is the head of that chain as r holds it.
Revoke(r) ==
    /\ Cardinality(revs) < MaxRevocations
    /\ \E c \in {Chain(e) : e \in signed} :
         /\ c[1] # r
         /\ c \notin {v.chain : v \in revs}
         /\ LET mine == {e \in acc[r] : Chain(e) = c}
                last == IF mine = {} THEN -1
                        ELSE CHOOSE s \in {e.seq : e \in mine} :
                               \A t \in {e.seq : e \in mine} : t <= s
                v == [chain |-> c, last |-> last]
            IN /\ revs' = revs \cup {v}
               /\ known' = [known EXCEPT ![r] = @ \cup {v}]
    /\ UNCHANGED <<log, held, nextSeq, res, key, signed, room, acc, forkSeen,
                   nwid, restores>>

\* A revocation reaches device r. The design also drops what r had already
\* accepted beyond it.
Learn(r) ==
    /\ \E v \in revs \ known[r] :
         /\ known' = [known EXCEPT ![r] = @ \cup {v}]
         /\ acc' = IF RetroactiveRevocation
                   THEN [acc EXCEPT ![r] = {e \in @ : ~Beyond({v}, e)}]
                   ELSE acc
    /\ UNCHANGED <<log, held, nextSeq, res, key, signed, room, revs, forkSeen,
                   nwid, restores>>

Next ==
    \/ Prune
    \/ \E d \in D :
         \/ Write(d) \/ Reserve(d) \/ Commit(d) \/ Crash(d) \/ Restore(d)
         \/ Accept(d) \/ DetectFork(d) \/ Revoke(d) \/ Learn(d)

Fairness ==
    /\ \A d \in D : WF_vars(Accept(d)) /\ WF_vars(Learn(d))
    /\ \A d \in D : WF_vars(DetectFork(d))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
TypeOK ==
    /\ nwid \in 1..(MaxWrites + 1)
    /\ restores \in 0..MaxRestores
    /\ \A d \in D : /\ held[d] \subseteq signed
                    /\ acc[d] \subseteq signed
                    /\ known[d] \subseteq revs
    /\ room \subseteq signed

\* A device's chain has no gap: its i-th envelope is at seq i - 1.
ChainContinuous ==
    \A d \in D : \A i \in 1..Len(log[d]) : log[d][i].seq = i - 1

\* No two envelopes share a key and a seq (I4, at the source).
NoFork ==
    \A e, f \in signed : Chain(e) = Chain(f) /\ e.seq = f.seq => e = f

\* However a fork arises, no device applies both sides of it.
ForkNeverApplied ==
    \A r \in D : \A a, b \in acc[r] :
        Chain(a) = Chain(b) /\ a.seq = b.seq => a = b

\* What a device has accepted is always a gap-free prefix of each chain.
AcceptedIsPrefix ==
    \A r \in D : \A e \in acc[r] :
        e.seq = 0 \/ \E p \in acc[r] : Chain(p) = Chain(e) /\ p.wid = e.prev

\* A device never holds an envelope past a revocation it knows (I2).
NoAcceptBeyondRevocation ==
    \A r \in D : \A e \in acc[r] : ~Beyond(known[r], e)

-----------------------------------------------------------------------------
\* e is past a revocation, or at or after a fork on its chain.
Excused(e) ==
    \/ Beyond(revs, e)
    \/ \E f, g \in signed : /\ Chain(f) = Chain(e) /\ Chain(g) = Chain(e)
                            /\ f.seq = g.seq /\ f # g /\ f.seq <= e.seq

\* Nobody holds e any more, and the room has forgotten it: an envelope
\* written after the last backup and restored away before anyone saw it.
Lost(e) == e \notin room /\ \A p \in D : e \notin Held(p)

\* An envelope before e on its chain is lost, so e can never be shown to
\* extend it. The open design question in the README: today's sync would
\* apply such an entry; a strict chain quarantines it for good.
Orphaned(e) ==
    \E f \in signed : Chain(f) = Chain(e) /\ f.seq < e.seq /\ Lost(f)

Signed(w) == \E e \in signed : e.wid = w

\* Quantified rather than chosen: the liveness checker evaluates this in states
\* where envelope w does not exist yet.
Settled(w) ==
    \A e \in signed :
        e.wid = w =>
            \/ Excused(e)
            \/ Lost(e)
            \/ Orphaned(e)
            \/ \A r \in D \ {e.dev} : e \in acc[r]

\* Every envelope reaches every other device, unless it is excused by a
\* revocation or a fork, was lost with a restored database, or follows one
\* that was.
EventuallyApplied ==
    \A w \in 1..MaxWrites : [](Signed(w) => <>Settled(w))
=============================================================================
