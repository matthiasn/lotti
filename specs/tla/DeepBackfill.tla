---------------------------- MODULE DeepBackfill ----------------------------
(***************************************************************************)
(* Deep backfill: a manual sync maintenance round that repairs history    *)
(* the (hostId, counter) sequence log cannot see.                          *)
(*                                                                         *)
(* Counter backfill (SyncSequence.tla) only finds a hole between counters *)
(* a device has recorded, and the responder only answers a counter it has *)
(* a sequence-log row for. An installation whose log was populated from   *)
(* current clocks, or never saw a host at all, can be missing whole       *)
(* entries that no counter request will ever name. Deep backfill replaces *)
(* counters with the records themselves:                                   *)
(*                                                                         *)
(*   1. A device's user starts a round (StartRound). The device pages its *)
(*      records by id and advertises every one it holds -- tombstones     *)
(*      included -- as (id, clock), in batches. Each batch also names the *)
(*      id range it covers and the open conflicts in it (EmitBatch).       *)
(*   2. Every other device diffs a batch in one step (Diff): one batched  *)
(*      read of its own rows for the batch's range, compared in memory.   *)
(*      It requests, from the advertiser, every record it lacks or holds  *)
(*      an older or concurrent version of; and it pushes, to the          *)
(*      advertiser, every record it holds a newer or concurrent version   *)
(*      of, or holds while the advertiser does not.                        *)
(*   3. The advertiser answers a request with its current row (Answer),   *)
(*      and every receive -- answer, push, or incremental sync -- goes    *)
(*      through the one write decision (Receive, DecideOn). A request is  *)
(*      outstanding until the recipient holds a version covering the one *)
(*      it asked for, whoever sent it: an answer does not say which      *)
(*      request it answers (its originatingHostId names the version's     *)
(*      origin, not the responder).                                        *)
(*                                                                         *)
(* Records are abstract: `Ids` stands for any synced record with a vector *)
(* clock (journal entries, entry links, agent entities and links,          *)
(* notifications, consumption events). The receive decision is the        *)
(* journal's (JournalReplication.tla, ADR 0083/0092): newer applies,       *)
(* equal or older is refused, a concurrent version is kept as an open     *)
(* conflict, and two concurrent deletions merge. `Merge = TRUE` replaces  *)
(* the conflict with the merge the agent records use (AgentReplication).   *)
(*                                                                         *)
(* The network is the Matrix room plus the outbox: a set of messages,     *)
(* delivered in any order, each at most once, with `LossBudget` losses.   *)
(* A crash loses a device's round progress and, unless the outstanding    *)
(* requests are persisted (`DurableOutstanding`), its outstanding set.    *)
(* Messages already enqueued survive a crash: they are in the outbox.     *)
(*                                                                         *)
(* The design switches are the protocol's rules; TRUE is the design, and  *)
(* each one set to FALSE has a counterexample (README):                    *)
(*   AdvertiseTombstones  the inventory includes soft-deleted rows         *)
(*   PushNewer            the recipient sends back what it holds newer     *)
(*   RangeBounds          ...including what the advertiser has no row for *)
(*   DedupeOutstanding    no request for a record already requested        *)
(*   DurableOutstanding   the outstanding requests survive a crash         *)
(*   SkipHeldConflict     no request for a version held as a conflict      *)
(*   AdvertiseConflicts   no push of a version the advertiser holds as one *)
(*   ClearOnlyCovered     a receive settles only the requests it covers    *)
(*   ConflictsTravel      open conflict versions are requested and pushed *)
(*                        like rows, not only named to suppress pushes     *)
(*                                                                         *)
(* The round is started by the user (manual only, for now): the liveness  *)
(* properties assume every device in `Runners` runs maintenance again     *)
(* after the last write, loss and crash.                                   *)
(*                                                                         *)
(* Written before the code. The planned mapping from each action to Dart  *)
(* is in docs/implementation_plans/2026-09-27_deep_backfill.md; this      *)
(* header takes it over as the implementation lands.                       *)
(***************************************************************************)
EXTENDS Integers, FiniteSets

CONSTANTS
    N,            \* devices 1..N
    NI,           \* records 1..NI
    BatchSize,    \* records per inventory batch
    MaxWrites,    \* local writes (edits, deletions, resolutions), in total
    Runners,      \* devices whose user runs maintenance
    LossBudget,   \* messages the network may lose
    MaxCrashes,   \* device crashes
    Incremental,  \* a local write is also sent by ordinary sync
    Merge,        \* concurrent versions merge (agents) instead of conflicting
    \* Design switches: TRUE is the design.
    AdvertiseTombstones,
    PushNewer,
    RangeBounds,
    DedupeOutstanding,
    DurableOutstanding,
    SkipHeldConflict,
    AdvertiseConflicts,
    ClearOnlyCovered,
    ConflictsTravel

R == 1..N
Ids == 1..NI

ASSUME N \in Nat /\ N >= 2 /\ NI \in Nat /\ NI >= 1
ASSUME BatchSize \in Nat /\ BatchSize >= 1
ASSUME MaxWrites \in Nat /\ LossBudget \in Nat /\ MaxCrashes \in Nat
ASSUME Runners \subseteq R /\ Runners # {}
ASSUME \A b \in {Incremental, Merge, AdvertiseTombstones, PushNewer,
                 RangeBounds, DedupeOutstanding, DurableOutstanding,
                 SkipHeldConflict, AdvertiseConflicts, ClearOnlyCovered,
                 ConflictsTravel} :
        b \in BOOLEAN

\* Batches page the records by id: batch k covers Range(k). The ranges
\* partition the whole keyspace and every one is emitted, empty or not. The
\* code must do the same: the first batch's range is unbounded below, the
\* last's unbounded above, each starts where the previous ended, and a table
\* with no rows still emits one batch covering everything -- or a record
\* only the recipient holds, outside every page, never travels.
NB == (NI + BatchSize - 1) \div BatchSize
Range(k) == {i \in Ids : (i - 1) \div BatchSize + 1 = k}

Zero == [r \in R |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
\* VectorClock.merge.
Join(a, b) == [r \in R |-> Max(a[r], b[r])]

(***************************************************************************)
(* A version of record `item`: its write id `vid`, the device that wrote  *)
(* it, its clock, whether it is a tombstone, and the ghost `hist`: the    *)
(* write ids it causally follows, itself included. The code sees only the *)
(* clock; the properties judge it against `hist`. `NoV` is "no row".      *)
(***************************************************************************)
NoV == [vid |-> 0, item |-> 0, host |-> 0, vc |-> Zero, del |-> FALSE,
        hist |-> {}]
Has(v) == v.vid # 0

Leq(a, b) == \A r \in R : a.vc[r] <= b.vc[r]
\* VectorClock.compare(a, b), as detectConflict reads it.
Status(a, b) ==
    IF a.vc = b.vc THEN "equal"
    ELSE IF Leq(a, b) THEN "b_gt_a"
    ELSE IF Leq(b, a) THEN "a_gt_b"
    ELSE "concurrent"
\* `b` is `a` or a newer version.
Covers(a, b) == Status(a, b) \in {"b_gt_a", "equal"}

\* Messages. Every message has the same fields so TLC can compare them.
\*   inv: batch `k` of `from`'s inventory for `to`; `vs` its rows in
\*        Range(k), `held` its open conflicts there
\*   req: `from` asks `to` for the records `ids`; `vs` the advertised
\*        versions it asks about (a ghost: the wire carries only the ids)
\*   pay: one version `vs` from `from` to `to` -- an answer, a push or
\*        ordinary sync, the same journalEntity / agentEntity message on the
\*        wire. `ans` and `held` (the version asked about) are ghosts: an
\*        answer carries nothing that ties it to its request.
Msg(t, f, to, k, vs, held, ids, ans) ==
    [type |-> t, from |-> f, to |-> to, k |-> k, vs |-> vs, held |-> held,
     ids |-> ids, ans |-> ans]
Inv(f, to, k, vs, held) == Msg("inv", f, to, k, vs, held, {}, FALSE)
Req(f, to, asked) ==
    Msg("req", f, to, 0, asked, {}, {a.item : a \in asked}, FALSE)
Ans(f, to, v, a) == Msg("pay", f, to, 0, {v}, {a}, {v.item}, TRUE)
Push(f, to, v) == Msg("pay", f, to, 0, {v}, {}, {v.item}, FALSE)

VARIABLES
    row,       \* per device, per record: the stored row (NoV: none)
    conf,      \* per device, per record: the open conflict versions
    seen,      \* ghost, per device: versions written, received or stored
               \* there (a merge stores a row that is neither side)
    written,   \* ghost: every version written anywhere
    hc,        \* per device: the last counter it issued
    nid,       \* the next write id
    rnd,       \* per device: 0 idle, else the next batch to emit
    net,       \* messages enqueued or in the room, not yet consumed
    out,       \* per device: outstanding requests, as <<advertiser, id,
               \* the advertised version asked for>>
    losses,    \* messages lost so far
    crashes    \* crashes so far

vars == <<row, conf, seen, written, hc, nid, rnd, net, out, losses, crashes>>

\* Each record starts on its creator, and on any other devices it already
\* reached: an installation with arbitrary gaps.
Creator(i) == ((i - 1) % N) + 1
CreatedBy(r) == {i \in Ids : Creator(i) = r}
V1(i) ==
    LET c == Creator(i)
        n == Cardinality({j \in CreatedBy(c) : j <= i})
    IN [vid |-> i, item |-> i, host |-> c, vc |-> [Zero EXCEPT ![c] = n],
        del |-> FALSE, hist |-> {i}]

Init ==
    /\ \E H \in [Ids -> SUBSET R] :
        /\ \A i \in Ids : Creator(i) \in H[i]
        /\ row = [r \in R |-> [i \in Ids |-> IF r \in H[i] THEN V1(i) ELSE NoV]]
        /\ seen = [r \in R |-> {V1(i) : i \in {j \in Ids : r \in H[j]}}]
    /\ conf = [r \in R |-> [i \in Ids |-> {}]]
    /\ written = {V1(i) : i \in Ids}
    /\ hc = [r \in R |-> Cardinality(CreatedBy(r))]
    /\ nid = NI + 1
    /\ rnd = [r \in R |-> 0]
    /\ net = {}
    /\ out = [r \in R |-> {}]
    /\ losses = 0
    /\ crashes = 0

(***************************************************************************)
(* The write decision, JournalDb.updateJournalEntity with detectConflict,  *)
(* as the code has it after ADR 0083 and 0092: tombstones are read,        *)
(* conflicts are kept per version, a stale copy does not replace a newer  *)
(* conflict, and an applied version settles only the conflicts it covers. *)
(***************************************************************************)
StoredOn(C, w) ==
    IF \E c \in C : Covers(w, c) THEN C
    ELSE {c \in C : ~Covers(c, w)} \cup {w}
SettledOn(C, w) == {c \in C : ~Covers(c, w)}

\* VectorClock.compareCanonically(a, b) > 0.
CanonGt(a, b) ==
    \E k \in R : /\ a[k] > b[k]
                /\ \A j \in R : j < k => a[j] = b[j]

\* Two concurrent versions merged without the user: the canonically greater
\* one's fields under the join of both clocks, the same on every device.
Merged(P, w) ==
    LET win == IF CanonGt(w.vc, P.vc) THEN w ELSE P
    IN [win EXCEPT !.vc = Join(P.vc, w.vc), !.hist = P.hist \cup w.hist]

DecideOn(P, C, w) ==
    IF ~Has(P) THEN [row |-> w, conf |-> C, applied |-> TRUE]
    ELSE LET s == Status(P, w)
             t == Merged(P, w)
         IN IF s = "concurrent" /\ (Merge \/ (P.del /\ w.del))
            THEN [row |-> t, conf |-> SettledOn(C, t), applied |-> t # P]
            ELSE IF s = "b_gt_a"
            THEN [row |-> w, conf |-> SettledOn(C, w), applied |-> TRUE]
            ELSE IF s = "concurrent"
            THEN [row |-> P, conf |-> StoredOn(C, w), applied |-> FALSE]
            ELSE [row |-> P, conf |-> C, applied |-> FALSE]

\* The ghost history of a version written on r with clock vc: its base, and
\* every version of the record r knows that the clock covers.
CoveredHist(r, i, vc) ==
    UNION {x.hist : x \in {y \in seen[r] :
                              y.item = i /\ \A h \in R : y.vc[h] <= vc[h]}}

\* A local write of record i on device r: the decision commits it, and
\* ordinary sync (Incremental) sends the stored row to every other device.
LocalWrite(r, i, w) ==
    LET d == DecideOn(row[r][i], conf[r][i], w)
    IN /\ row' = [row EXCEPT ![r][i] = d.row]
       /\ conf' = [conf EXCEPT ![r][i] = d.conf]
       /\ seen' = [seen EXCEPT ![r] = @ \cup {w, d.row}]
       /\ written' = written \cup {w}
       /\ hc' = [hc EXCEPT ![r] = @ + 1]
       /\ nid' = nid + 1
       /\ net' = IF Incremental /\ d.applied
                 THEN net \cup {Push(r, s, d.row) : s \in R \ {r}}
                 ELSE net
       /\ UNCHANGED <<rnd, out, losses, crashes>>

\* An edit or a soft deletion of a live row: MetadataService.updateMetadata's
\* clock, the row's plus this device's next counter.
Edit(r, i) ==
    /\ nid <= NI + MaxWrites
    /\ Has(row[r][i]) /\ ~row[r][i].del
    /\ \E del \in BOOLEAN :
        LET b == row[r][i]
            vc == [b.vc EXCEPT ![r] = hc[r] + 1]
            w == [vid |-> nid, item |-> i, host |-> r, vc |-> vc, del |-> del,
                  hist |-> b.hist \cup CoveredHist(r, i, vc) \cup {nid}]
        IN LocalWrite(r, i, w)

\* ConflictResolutionService: the user keeps one side, over both clocks.
Resolve(r, i) ==
    /\ nid <= NI + MaxWrites
    /\ \E X \in conf[r][i] : \E del \in {row[r][i].del, X.del} :
        LET P == row[r][i]
            vc == [Join(P.vc, X.vc) EXCEPT ![r] = hc[r] + 1]
            w == [vid |-> nid, item |-> i, host |-> r, vc |-> vc, del |-> del,
                  hist |-> P.hist \cup X.hist \cup CoveredHist(r, i, vc)
                           \cup {nid}]
        IN LocalWrite(r, i, w)

(***************************************************************************)
(* The maintenance round.                                                  *)
(***************************************************************************)
\* A bound on the state space, not a rule of the protocol: the next round
\* starts once the last one's batches were read. Two rounds' batches in
\* flight together add only a stale diff, whose requests are answered with
\* the advertiser's current row anyway, and whose pushes the write decision
\* refuses if they are no longer newer.
StartRound(r) ==
    /\ r \in Runners
    /\ rnd[r] = 0
    /\ ~\E m \in net : m.type = "inv" /\ m.from = r
    /\ rnd' = [rnd EXCEPT ![r] = 1]
    /\ UNCHANGED <<row, conf, seen, written, hc, nid, net, out, losses,
                   crashes>>

\* The rows a batch advertises: every row in its range, tombstones too.
Advertised(r, k) ==
    {row[r][i] : i \in {j \in Range(k) :
                          Has(row[r][j]) /\ (AdvertiseTombstones \/ ~row[r][j].del)}}
HeldIn(r, k) ==
    IF AdvertiseConflicts THEN UNION {conf[r][i] : i \in Range(k)} ELSE {}

\* One page, read and enqueued as one attachment per room -- modelled as
\* one message per recipient, since each recipient consumes its own copy.
EmitBatch(r) ==
    /\ rnd[r] # 0
    /\ LET k == rnd[r]
       IN /\ net' = net \cup {Inv(r, s, k, Advertised(r, k), HeldIn(r, k)) :
                               s \in R \ {r}}
          /\ rnd' = [rnd EXCEPT ![r] = IF k = NB THEN 0 ELSE k + 1]
    /\ UNCHANGED <<row, conf, seen, written, hc, nid, out, losses, crashes>>

\* The advertised version of record i in batch m, as a set of at most one.
AdvOf(m, i) == {v \in m.vs : v.item = i}

\* The recipient needs the advertised version `a` of record i.
Needs(e, i, a) ==
    LET l == row[e][i]
    IN \/ ~Has(l)
       \/ Status(l, a) = "b_gt_a"
       \/ /\ Status(l, a) = "concurrent"
          /\ ~(SkipHeldConflict /\ \E c \in conf[e][i] : Covers(a, c))

\* The recipient holds a version the advertiser should get.
Owes(e, i, m) ==
    LET l == row[e][i]
    IN /\ PushNewer
       /\ Has(l)
       /\ IF AdvOf(m, i) = {}
          THEN RangeBounds
          ELSE LET a == CHOOSE v \in AdvOf(m, i) : TRUE
               IN \/ Status(l, a) = "a_gt_b"
                  \/ /\ Status(l, a) = "concurrent"
                     /\ ~(AdvertiseConflicts
                          /\ \E h \in m.held : h.item = i /\ Covers(l, h))

\* Device e keeps version h: its row or an open conflict is h or newer.
KeptHere(e, h) ==
    \/ Has(row[e][h.item]) /\ Covers(h, row[e][h.item])
    \/ \E c \in conf[e][h.item] : Covers(h, c)

\* The advertiser of batch m keeps version c: its advertised row or one of
\* its listed conflicts is c or newer.
KeptThere(m, c) ==
    \/ \E a \in AdvOf(m, c.item) : Covers(c, a)
    \/ \E h \in m.held : h.item = c.item /\ Covers(c, h)

\* The versions of batch m the recipient asks for: the advertised row it
\* needs, and (ConflictsTravel) each listed conflict it does not keep. A
\* conflict version held on one device only otherwise never reaches a third:
\* the row both others hold is equal, and nobody pushes the conflict.
Wanted(e, m) ==
    {a \in m.vs : Needs(e, a.item, a)}
    \cup (IF ConflictsTravel THEN {h \in m.held : ~KeptHere(e, h)} ELSE {})

\* The recipient's own conflict versions the advertiser does not keep.
OwedConflicts(e, m) ==
    IF ConflictsTravel
    THEN {c \in UNION {conf[e][i] : i \in Range(m.k)} : ~KeptThere(m, c)}
    ELSE {}

\* One batched read of the recipient's rows for the batch's range, compared
\* in memory; the requests, the pushes and the outstanding set are written
\* in one transaction with the outbox.
Diff(e, m) ==
    /\ m \in net /\ m.type = "inv" /\ m.to = e
    /\ LET d == m.from
           need == {i \in Range(m.k) :
                      /\ \E a \in Wanted(e, m) : a.item = i
                      /\ ~DedupeOutstanding
                         \/ ~\E x \in out[e] : x[1] = d /\ x[2] = i}
           asked == {a \in Wanted(e, m) : a.item \in need}
           owed == {i \in Range(m.k) : Owes(e, i, m)}
       IN /\ net' = (net \ {m})
                    \cup (IF need # {} THEN {Req(e, d, asked)} ELSE {})
                    \cup {Push(e, d, row[e][i]) : i \in owed}
                    \cup {Push(e, d, c) : c \in OwedConflicts(e, m)}
          /\ out' = [out EXCEPT ![e] = @ \cup {<<d, a.item, a>> : a \in asked}]
    /\ UNCHANGED <<row, conf, seen, written, hc, nid, rnd, losses, crashes>>

\* What answers a request for version a: the advertiser's row, unless only
\* an open conflict keeps a -- then that conflict. (The code resends the
\* row and every open conflict of the record; the others are receives the
\* write decision handles like any.)
AnswerFor(d, a) ==
    IF ~Covers(a, row[d][a.item]) /\ \E c \in conf[d][a.item] : Covers(a, c)
    THEN CHOOSE c \in conf[d][a.item] : Covers(a, c)
    ELSE row[d][a.item]

\* The advertiser answers with its current row, tombstones included, or the
\* open conflict that keeps the version asked for.
Answer(d, m) ==
    /\ m \in net /\ m.type = "req" /\ m.to = d
    /\ net' = (net \ {m}) \cup {Ans(d, m.from, AnswerFor(d, a), a) : a \in m.vs}
    /\ UNCHANGED <<row, conf, seen, written, hc, nid, rnd, out, losses,
                   crashes>>

\* A receive settles an outstanding request once the row, or an open
\* conflict, holds the version asked for or a newer one. Not settling it by
\* sender: nothing on the wire says which request a version answers.
\* (~ClearOnlyCovered: any receive of the record settles every request.)
Settles(a, d) ==
    \/ ~ClearOnlyCovered
    \/ Covers(a, d.row)
    \/ \E c \in d.conf : Covers(a, c)

\* Every version arrives through the one write decision.
Receive(e, m) ==
    /\ m \in net /\ m.type = "pay" /\ m.to = e
    /\ net' = net \ {m}
    /\ LET v == CHOOSE x \in m.vs : TRUE
           d == DecideOn(row[e][v.item], conf[e][v.item], v)
       IN /\ row' = [row EXCEPT ![e][v.item] = d.row]
          /\ conf' = [conf EXCEPT ![e][v.item] = d.conf]
          /\ seen' = [seen EXCEPT ![e] = @ \cup {v, d.row}]
          /\ out' = [out EXCEPT ![e] =
                       {x \in @ : ~(x[2] = v.item /\ Settles(x[3], d))}]
    /\ UNCHANGED <<written, hc, nid, rnd, losses, crashes>>

\* A request, or its answer, is gone: the requester's timeout frees the
\* record for the next round. (The timeout is assumed longer than a
\* delivery: it only fires once neither is still on its way.)
InFlight(e, x) ==
    \/ \E m \in net : m.type = "req" /\ m.from = e /\ m.to = x[1]
                      /\ x[3] \in m.vs
    \/ \E m \in net : m.type = "pay" /\ m.ans /\ m.from = x[1] /\ m.to = e
                      /\ x[3] \in m.held
Expire(e, x) ==
    /\ x \in out[e]
    /\ ~InFlight(e, x)
    /\ out' = [out EXCEPT ![e] = @ \ {x}]
    /\ UNCHANGED <<row, conf, seen, written, hc, nid, rnd, net, losses,
                   crashes>>

Lose(m) ==
    /\ losses < LossBudget
    /\ m \in net
    /\ net' = net \ {m}
    /\ losses' = losses + 1
    /\ UNCHANGED <<row, conf, seen, written, hc, nid, rnd, out, crashes>>

\* The databases and the outbox survive; the round's progress does not.
Crash(r) ==
    /\ crashes < MaxCrashes
    /\ crashes' = crashes + 1
    /\ rnd' = [rnd EXCEPT ![r] = 0]
    /\ out' = IF DurableOutstanding THEN out ELSE [out EXCEPT ![r] = {}]
    /\ UNCHANGED <<row, conf, seen, written, hc, nid, net, losses>>

Next ==
    \/ \E r \in R, i \in Ids : Edit(r, i) \/ Resolve(r, i)
    \/ \E r \in R : StartRound(r) \/ EmitBatch(r) \/ Crash(r)
    \/ \E m \in net : Diff(m.to, m) \/ Answer(m.to, m) \/ Receive(m.to, m)
                      \/ Lose(m)
    \/ \E e \in R : \E x \in out[e] : Expire(e, x)

\* Fairness: the protocol's own steps are taken; the user runs maintenance
\* again (Runners); writes, losses and crashes are not forced. Fairness is
\* per batch and per record: the inbound queue processes every event in
\* room order, so the batch a later round re-emits cannot starve another
\* one. (Per sender alone, TLC finds batch 1 diffed round after round while
\* batch 2, carrying a tombstone, waits forever.)
Fairness ==
    /\ \A r \in Runners : WF_vars(StartRound(r))
    /\ \A r \in R : WF_vars(EmitBatch(r))
    /\ \A e, d \in R :
        /\ \A k \in 1..NB :
            WF_vars(\E m \in net : m.from = d /\ m.k = k /\ Diff(e, m))
        /\ WF_vars(\E m \in net : m.from = e /\ Answer(d, m))
        /\ \A i \in Ids :
            /\ WF_vars(\E m \in net : m.from = d /\ m.ids = {i}
                                      /\ Receive(e, m))
            /\ WF_vars(\E x \in out[e] : x[1] = d /\ x[2] = i
                                          /\ Expire(e, x))

Spec == Init /\ [][Next]_vars
FairSpec == Spec /\ Fairness

(***************************************************************************)
(* Properties.                                                             *)
(***************************************************************************)
TypeOK ==
    /\ nid \in 1..(NI + MaxWrites + 1)
    /\ \A r \in R : rnd[r] \in 0..NB
    /\ \A r \in R : \A i \in Ids : Has(row[r][i]) => row[r][i].item = i
    /\ losses \in 0..LossBudget /\ crashes \in 0..MaxCrashes

\* An inventory only advertises versions its sender actually held.
InventoryIsReal ==
    \A m \in net : m.type = "inv" => m.vs \subseteq seen[m.from]

\* A version is asked for at most once per advertiser while the request, or
\* its answer, is on its way.
NoDuplicateRequest ==
    \A e, d \in R :
        \A a \in UNION {m.vs \cup m.held : m \in net} :
            Cardinality({m \in net :
                           \/ m.type = "req" /\ m.from = e /\ m.to = d
                              /\ a \in m.vs
                           \/ m.type = "pay" /\ m.ans /\ m.from = d
                              /\ m.to = e /\ a \in m.held}) <= 1

\* `m` causally replaced `v`.
Replaced(v, m) == v.hist \subseteq m.hist /\ v.hist # m.hist

\* No row is a version the device has seen replaced: a tombstone is never
\* undone by an answer or a push of an older copy.
NoLostTombstone ==
    \A r \in R, i \in Ids : \A m \in seen[r] :
        m.item = i => ~Replaced(row[r][i], m)

\* `v` keeps `m`: it follows it, or both delete the record.
Keeps(v, m) == m.hist \subseteq v.hist \/ (m.del /\ v.del)
KeptOn(r, m) == Keeps(row[r][m.item], m) \/ \E c \in conf[r][m.item] : Keeps(c, m)

\* Nothing a device received or wrote is dropped without the user choosing.
NothingDropped == \A r \in R : \A m \in seen[r] : KeptOn(r, m)

\* An open conflict is never a version its row or a version seen replaced.
ConflictNotStale ==
    \A r \in R, i \in Ids : \A c \in conf[r][i] :
        /\ ~(c.hist \subseteq row[r][i].hist)
        /\ \A m \in seen[r] : ~Replaced(c, m)

\* The union: every device keeps every version ever written -- by its row,
\* or by an open conflict it shows the user -- tombstones included.
UnionReached == \A r \in R : \A m \in written : KeptOn(r, m)

\* No silent divergence: every record is the same everywhere, deleted
\* everywhere, or an open conflict somewhere.
Content(v) == [vid |-> v.vid, vc |-> v.vc, del |-> v.del, hist |-> v.hist]
Agreed ==
    \A i \in Ids :
        \/ \A a, b \in R : Content(row[a][i]) = Content(row[b][i])
        \/ \A a \in R : Has(row[a][i]) /\ row[a][i].del
        \/ \E r \in R : conf[r][i] # {}

\* Only inventories remain: once the devices agree, a round requests and
\* pushes nothing -- no conflict ping-pong from round to round.
Quiet == \A m \in net : m.type = "inv"

EventuallyConverged == <>[](UnionReached /\ Agreed)
EventuallyQuiet == <>[]Quiet
\* Every round that starts finishes its batches, or is lost to a crash.
RoundTerminates == \A r \in R : [](rnd[r] # 0 => <>(rnd[r] = 0))
=============================================================================
