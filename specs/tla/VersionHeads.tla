---------------------------- MODULE VersionHeads ----------------------------
(***************************************************************************)
(* A versioned document on two devices that edit it offline: its version   *)
(* rows, each with a status, and the head row that names the current       *)
(* version. Every row is its own synced entity, resolved on its own. The   *)
(* intended invariant is that, once the devices have exchanged everything, *)
(* exactly one version is active and the head names it.                    *)
(*                                                                         *)
(* `Kind` picks the document:                                               *)
(*                                                                         *)
(*   "soul"  soul documents and agent templates (SoulVersionOps,           *)
(*           AgentTemplateCrud): a new version archives every version that *)
(*           is not archived; a rollback archives them and reactivates its  *)
(*           target; the head is plain last-writer-wins on updatedAt       *)
(*   "goal"  goal specs (GoalSpecRevisionService._mintRevision): a         *)
(*           revision supersedes the head's version and mints the next     *)
(*           ordinal; the head resolver prefers the higher ordinal         *)
(*                                                                         *)
(* Version rows carry only createdAt, so a concurrent status write is      *)
(* decided by the canonical clock tiebreak (agent_lww_timestamp.dart).     *)
(* Deliver is the receive path of AgentReplication.tla, per row.           *)
(*                                                                         *)
(* `SupersedeAll` is the fix of ADR 0068 for goal specs: a revision        *)
(* supersedes every version still active, as the soul path always has.     *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS Kind, EditsPerDevice, Rollback, SupersedeAll
ASSUME Kind \in {"soul", "goal"}
ASSUME Rollback \in BOOLEAN /\ SupersedeAll \in BOOLEAN

Devices == {1, 2}
\* Version ids: 0 is the initial version, 10*d + k the k-th minted on d.
Ids == {0} \cup {10 * d + k : d \in Devices, k \in 1..EditsPerDevice}
Zero == [d \in Devices |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
Leq(a, b) == \A d \in Devices : a[d] <= b[d]
CanonGt(a, b) == a[1] > b[1] \/ (a[1] = b[1] /\ a[2] > b[2])

Head == 100  \* the head row's key
Keys == {Head} \cup Ids
None == [vc |-> Zero, ts |-> 0, ex |-> FALSE, val |-> [n |-> 0, st |-> "none"]]

\* A version row's val is [n |-> ordinal, st |-> status]; the head's is
\* [id |-> version id, n |-> its ordinal].
Initial(k) ==
    CASE k = Head -> [vc |-> Zero, ts |-> 0, ex |-> TRUE, val |-> [id |-> 0, n |-> 1]]
      [] k = 0      -> [vc |-> Zero, ts |-> 0, ex |-> TRUE, val |-> [n |-> 1, st |-> "active"]]
      [] OTHER      -> None

VARIABLES
    store,      \* per device: every row, by key
    msgs,       \* every row write ever made
    delivered,  \* per device: the writes it has made or received
    counter,    \* per device: the last clock counter it issued
    clock,      \* the wall clock, one tick per edit
    edits,      \* per device: edits made
    clean       \* ghost: the last edit was made with everything received
vars == <<store, msgs, delivered, counter, clock, edits, clean>>

Init ==
    /\ store = [d \in Devices |-> [k \in Keys |-> Initial(k)]]
    /\ msgs = {}
    /\ delivered = [d \in Devices |-> {}]
    /\ counter = [d \in Devices |-> 0]
    /\ clock = 1
    /\ edits = [d \in Devices |-> 0]
    /\ clean = FALSE

\* The receive path for one row (resolveAgentEntityVersions).
Winner(k, l, i) ==
    IF k = Head /\ Kind = "goal" /\ l.val.n # i.val.n
    THEN IF l.val.n > i.val.n THEN l ELSE i
    ELSE IF i.ts > l.ts THEN i
    ELSE IF l.ts > i.ts THEN l
    ELSE IF CanonGt(i.vc, l.vc) THEN i ELSE l

Merge(k, l, i) ==
    IF ~l.ex THEN i
    ELSE IF Leq(i.vc, l.vc) THEN l
    ELSE IF Leq(l.vc, i.vc) THEN i
    ELSE Winner(k, l, i)

Present(d) == {v \in Ids : store[d][v].ex}
Status(d, v) == store[d][v].val.st
HeadOf(d) == store[d][Head].val

\* One edit writes several rows; each is stamped with its own next counter
\* (the same host), and each goes out as its own sync message.
Stamp(d, k, val, ts, c) ==
    [vc |-> [store[d][k].vc EXCEPT ![d] = c], ts |-> ts, ex |-> TRUE, val |-> val]

\* Writes a set of rows as one transaction. `rows` maps keys to new vals;
\* `tss` maps them to their updatedAt.
Commit(d, rows, tss) ==
    LET ks == DOMAIN rows
        \* A deterministic counter per key, above everything issued so far.
        order == CHOOSE f \in [ks -> 1..Cardinality(ks)] :
                    \A a, b \in ks : a # b => f[a] # f[b]
        w == [k \in ks |-> Stamp(d, k, rows[k], tss[k], counter[d] + order[k])]
    IN /\ store' = [store EXCEPT ![d] =
                       [k \in Keys |-> IF k \in ks THEN w[k] ELSE @[k]]]
       /\ msgs' = msgs \cup {[key |-> k, rec |-> w[k]] : k \in ks}
       /\ delivered' = [delivered EXCEPT ![d] = @ \cup
                           {[key |-> k, rec |-> w[k]] : k \in ks}]
       /\ counter' = [counter EXCEPT ![d] = @ + Cardinality(ks)]

\* A new version: soul archives every non-archived version; goal supersedes
\* the head's version (or, fixed, every active one).
Edit(d) ==
    /\ edits[d] < EditsPerDevice
    \* A revision refuses while the head's version has not synced in.
    /\ Kind = "goal" => HeadOf(d).id \in Present(d)
    /\ LET nid == 10 * d + edits[d] + 1
           cur == HeadOf(d)
           old == IF Kind = "soul"
                  THEN {v \in Present(d) : Status(d, v) # "archived"}
                  ELSE IF SupersedeAll
                       THEN {v \in Present(d) : Status(d, v) = "active"}
                       ELSE {cur.id} \cap Present(d)
           gone == IF Kind = "soul" THEN "archived" ELSE "superseded"
           n == IF Kind = "soul"
                THEN 1 + Max(0, CHOOSE m \in {store[d][v].val.n : v \in Present(d)} :
                                  \A v \in Present(d) : store[d][v].val.n <= m)
                ELSE cur.n + 1
           rows == [k \in old \cup {nid, Head} |->
                       IF k = nid THEN [n |-> n, st |-> "active"]
                       ELSE IF k = Head THEN [id |-> nid, n |-> n]
                       ELSE [store[d][k].val EXCEPT !.st = gone]]
           \* Version rows are LWW on createdAt, which a status write keeps.
           tss == [k \in DOMAIN rows |->
                       IF k \in {nid, Head} THEN clock ELSE store[d][k].ts]
       IN Commit(d, rows, tss)
    /\ edits' = [edits EXCEPT ![d] = @ + 1]
    /\ clock' = clock + 1
    /\ clean' = (delivered[d] = msgs)

\* Soul rollback: archive every non-archived version, reactivate the target.
RollbackTo(d, v) ==
    /\ Rollback /\ Kind = "soul"
    /\ edits[d] < EditsPerDevice
    /\ v \in Present(d) /\ v # HeadOf(d).id
    /\ LET old == {u \in Present(d) : Status(d, u) # "archived"} \ {v}
           rows == [k \in old \cup {v, Head} |->
                       IF k = v THEN [store[d][v].val EXCEPT !.st = "active"]
                       ELSE IF k = Head THEN [id |-> v, n |-> store[d][v].val.n]
                       ELSE [store[d][k].val EXCEPT !.st = "archived"]]
           tss == [k \in DOMAIN rows |->
                       IF k = Head THEN clock ELSE store[d][k].ts]
       IN Commit(d, rows, tss)
    /\ edits' = [edits EXCEPT ![d] = @ + 1]
    /\ clock' = clock + 1
    /\ clean' = (delivered[d] = msgs)

Deliver(d) ==
    /\ \E m \in msgs \ delivered[d] :
        /\ store' = [store EXCEPT ![d][m.key] = Merge(m.key, @, m.rec)]
        /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
    /\ UNCHANGED <<msgs, counter, clock, edits, clean>>

Next ==
    \E d \in Devices :
        \/ Edit(d) \/ Deliver(d)
        \/ \E v \in Ids : RollbackTo(d, v)

Spec == Init /\ [][Next]_vars

TypeOK == clock \in Nat /\ \A d \in Devices : delivered[d] \subseteq msgs

Quiescent == \A d \in Devices : delivered[d] = msgs

Converged == Quiescent => store[1] = store[2]

\* The head names a version this device has.
HeadResolves == Quiescent => \A d \in Devices : HeadOf(d).id \in Present(d)

\* The version the head names is marked active, and it is the only one.
OneActiveState(d) ==
    {v \in Present(d) : Status(d, v) = "active"} = {HeadOf(d).id}

\* Concurrent edits can break that (README: residuals), so the checked
\* claim is that it is restored: once an edit has been made by a device
\* that had received everything, and everything has been exchanged again.
SettlesAfterCleanEdit ==
    (Quiescent /\ clean) => \A d \in Devices : OneActiveState(d)

\* The unconditional form, which concurrent edits violate.
OneActive == Quiescent => \A d \in Devices : OneActiveState(d)
=============================================================================
