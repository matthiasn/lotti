--------------------------- MODULE DefinitionClocks ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************)
(* One entity definition (a category, label, habit, dashboard, measurable  *)
(* or speech dictionary entry) replicated as a whole document between      *)
(* hosts. Every local write reserves the host's next counter and extends   *)
(* the stored vector clock by it. The receiving gate keeps a version whose *)
(* clock dominates; two concurrent versions are settled last-writer-wins   *)
(* (updatedAt, then content), and the winner is stored under the JOIN of   *)
(* both clocks — strictly greater than either, so no counter is spent on   *)
(* the resolution and nothing is sent because of it.                       *)
(*                                                                         *)
(* Rows written by older builds carry no clock. A manual migration stamps  *)
(* a host's clockless rows, as writes with unchanged content; the user may *)
(* run it on one host only. A clockless side is ordered by updatedAt       *)
(* alone, and a clockless row that keeps its place against a clocked copy *)
(* stamps itself on top of that copy's clock, so its content wins          *)
(* everywhere without the migration running on its host.                  *)
(*                                                                         *)
(* With Backfill, delivery is lossy (MaxLoss). A receiver learns every     *)
(* counter in a clock it processes, sees the counters below it as gaps,   *)
(* and asks for them; any host whose stored version covers the counter    *)
(* answers with that version and a hint naming the counter (sequence-log  *)
(* backfill). Head announcements expose a lost latest counter. Without   *)
(* it, delivery is reliable and the sequence log is left out.             *)
(*                                                                         *)
(* Switches, each TRUE in the implementation, FALSE to reproduce the       *)
(* failure it guards against (README):                                     *)
(*   JoinOnResolve     — store the join, not the winner's own clock        *)
(*   ContentTieBreak   — an exact updatedAt tie is ordered by content      *)
(*   NullFallsBack     — a clockless side is ordered by updatedAt, not     *)
(*                       ranked below every clock                          *)
(*   MonotoneEditStamp — a local write stamps updatedAt above the stored   *)
(*                       version's                                         *)
(*   StampsBeaten      — a clockless row that beats a clocked copy stamps  *)
(*                       itself                                            *)
(***************************************************************************)
CONSTANTS Hosts, MaxCounter, Stamps, MaxLoss, Legacy, Backfill,
          JoinOnResolve, ContentTieBreak, NullFallsBack, MonotoneEditStamp,
          StampsBeaten

ASSUME /\ Cardinality(Hosts) \in 2..3
       /\ MaxCounter \in 1..3
       /\ Stamps \subseteq 1..9 /\ Stamps # {}
       /\ MaxLoss \in Nat
       /\ Legacy \in BOOLEAN
       \* Without the sequence-log repair nothing recovers a lost message.
       /\ Backfill \in BOOLEAN /\ (~Backfill => MaxLoss = 0)

Ix == CHOOSE f \in [Hosts -> 1..Cardinality(Hosts)] :
          \A x, y \in Hosts : x # y => f[x] # f[y]
Counters == 0..MaxCounter
Zero == [h \in Hosts |-> 0]
Clocks == [Hosts -> Counters]
\* Content ids: a legacy row Ix(h), host h's write at counter n 10*Ix(h)+n.
\* Their numeric order is the canonical content order of the tie-break.
LegacyContent(h) == Ix[h]
EditContent(h, n) == 10 * Ix[h] + n
Contents == {LegacyContent(h) : h \in Hosts}
            \cup {EditContent(h, n) : h \in Hosts, n \in 1..MaxCounter}
None == [content |-> 0, stamp |-> 0, clock |-> Zero, hasClock |-> FALSE]
Versions == [content : Contents, stamp : Stamps, clock : Clocks,
             hasClock : BOOLEAN]
Messages == [version : Versions, hint : (Hosts \X (1..MaxCounter)) \cup {<<>>}]

Leq(x, y) == \A h \in Hosts : x[h] <= y[h]
Join(x, y) == [h \in Hosts |-> IF x[h] >= y[h] THEN x[h] ELSE y[h]]

\* Last-writer-wins between two versions: the later updatedAt, then the
\* greater content; without ContentTieBreak an exact tie takes the incoming.
Later(in, st) ==
    \/ in.stamp > st.stamp
    \/ /\ in.stamp = st.stamp
       /\ IF ContentTieBreak THEN in.content >= st.content ELSE TRUE

\* The receiving gate: what is stored after [in] meets [st].
\* A clockless copy never displaces a clocked row; a clockless row meets any
\* copy by updatedAt (NullFallsBack) instead of yielding to every clock.
Gate(st, in) ==
    IF st = None THEN in
    ELSE IF ~st.hasClock /\ ~in.hasClock
    THEN IF Later(in, st) THEN in ELSE st
    ELSE IF ~in.hasClock THEN st
    ELSE IF ~st.hasClock
    THEN IF ~NullFallsBack \/ Later(in, st) THEN in ELSE st
    ELSE IF st.clock = in.clock THEN st
    ELSE IF Leq(st.clock, in.clock) THEN in
    ELSE IF Leq(in.clock, st.clock) THEN st
    ELSE LET w == IF Later(in, st) THEN in ELSE st
         IN [w EXCEPT !.clock = IF JoinOnResolve
                                THEN Join(st.clock, in.clock) ELSE @,
                      !.hasClock = TRUE]

\* What a host remembers of a version it has held or received.
Seen(v) == [content |-> v.content, stamp |-> v.stamp]
ContentsOf(S) == {k.content : k \in S}

VARIABLES row, ctr, net, rec, seen, losses, known, edits, beaten, migrated,
          resent
vars == <<row, ctr, net, rec, seen, losses, known, edits, beaten, migrated,
          resent>>

Init ==
    /\ row \in IF Legacy
               THEN {[h \in Hosts |-> [content |-> LegacyContent(h),
                                       stamp |-> at[h], clock |-> Zero,
                                       hasClock |-> FALSE]]
                       : at \in [Hosts -> Stamps]}
               ELSE {[h \in Hosts |-> None]}
    /\ ctr = [h \in Hosts |-> 0]
    /\ net = [h \in Hosts |-> {}]
    /\ rec = [h \in Hosts |-> [o \in Hosts |-> {}]]
    /\ seen = [h \in Hosts |-> [o \in Hosts |-> 0]]
    /\ losses = 0
    /\ known = [h \in Hosts |-> IF Legacy THEN {Seen(row[h])} ELSE {}]
    /\ edits = {}
    /\ beaten = [h \in Hosts |-> Zero]
    /\ migrated = FALSE
    /\ resent = {}

Broadcast(h, v) == [x \in Hosts |->
    IF x = h THEN net[x] ELSE net[x] \cup {[version |-> v, hint |-> <<>>]}]

\* A local write: the next own counter on top of the stored clock.
Edit(h) ==
    /\ ctr[h] < MaxCounter
    /\ \E stamp \in Stamps :
         /\ ~MonotoneEditStamp \/ row[h] = None \/ stamp > row[h].stamp
         /\ LET n == ctr[h] + 1
                v == [content |-> EditContent(h, n), stamp |-> stamp,
                      clock |-> [row[h].clock EXCEPT ![h] = n],
                      hasClock |-> TRUE]
            IN /\ row' = [row EXCEPT ![h] = v]
               /\ ctr' = [ctr EXCEPT ![h] = n]
               /\ net' = Broadcast(h, v)
               /\ known' = [known EXCEPT ![h] = @ \cup {Seen(v)}]
               /\ edits' = edits \cup {[content |-> v.content,
                                        before |-> ContentsOf(known[h])]}
               /\ beaten' = [beaten EXCEPT ![h] = Zero]
    /\ UNCHANGED <<rec, seen, losses, migrated, resent>>

\* Stamping a clockless row: same content and updatedAt, the next own
\* counter on top of any clocked copy it has beaten.
StampRow(h) ==
    /\ row[h] # None /\ ~row[h].hasClock /\ ctr[h] < MaxCounter
    /\ LET n == ctr[h] + 1
           v == [row[h] EXCEPT !.clock = [beaten[h] EXCEPT ![h] = n],
                               !.hasClock = TRUE]
       IN /\ row' = [row EXCEPT ![h] = v]
          /\ ctr' = [ctr EXCEPT ![h] = n]
          /\ net' = Broadcast(h, v)
          /\ beaten' = [beaten EXCEPT ![h] = Zero]
    /\ UNCHANGED <<rec, seen, losses, known, edits, resent>>

\* The maintenance re-send of a stored row that is still clockless — the one
\* copy a re-send adds that a clocked write did not already send. A user's
\* one-off action: once per host bounds it, as it is in practice.
Resend(h) ==
    /\ row[h] # None /\ ~row[h].hasClock /\ h \notin resent
    /\ net' = Broadcast(h, row[h])
    /\ resent' = resent \cup {h}
    /\ UNCHANGED <<row, ctr, rec, seen, losses, known, edits, beaten, migrated>>

\* The manual migration, which the user runs on whichever host they choose.
Migrate(h) == StampRow(h) /\ migrated' = TRUE

\* A clockless row that kept its place against a clocked copy.
StampBeaten(h) == beaten[h] # Zero /\ StampRow(h) /\ UNCHANGED migrated

\* Every counter in a processed clock is received; those below are gaps.
Learn(h, m) ==
    [o \in Hosts |->
        IF o = h THEN rec[h][o]
        ELSE rec[h][o]
             \cup (IF m.version.hasClock /\ m.version.clock[o] > 0
                   THEN {m.version.clock[o]} ELSE {})
             \cup (IF m.hint # <<>> /\ m.hint[1] = o THEN {m.hint[2]} ELSE {})]

Deliver(h, m) ==
    /\ m \in net[h]
    /\ row' = [row EXCEPT ![h] = Gate(@, m.version)]
    /\ net' = [net EXCEPT ![h] = @ \ {m}]
    /\ rec' = IF Backfill THEN [rec EXCEPT ![h] = Learn(h, m)] ELSE rec
    /\ seen' = IF Backfill
               THEN [seen EXCEPT ![h] = [o \in Hosts |->
                      IF o # h /\ m.version.hasClock /\ m.version.clock[o] > @[o]
                      THEN m.version.clock[o] ELSE @[o]]]
               ELSE seen
    /\ known' = [known EXCEPT ![h] = @ \cup {Seen(m.version)}]
    /\ beaten' = [beaten EXCEPT ![h] =
         IF StampsBeaten /\ row[h] # None /\ ~row[h].hasClock
            /\ m.version.hasClock /\ Gate(row[h], m.version) = row[h]
         THEN Join(@, m.version.clock) ELSE @]
    /\ UNCHANGED <<ctr, losses, edits, migrated, resent>>

Lose(h, m) ==
    /\ m \in net[h] /\ losses < MaxLoss
    /\ net' = [net EXCEPT ![h] = @ \ {m}]
    /\ losses' = losses + 1
    /\ UNCHANGED <<row, ctr, rec, seen, known, edits, beaten, migrated,
                   resent>>

Gap(h, o) == {k \in 1..seen[h][o] : k \notin rec[h][o]}

\* Backfill: any host whose version covers the counter answers with it.
Answer(h, o, k) ==
    /\ Backfill /\ o # h /\ k \in Gap(h, o)
    /\ \E g \in Hosts \ {h} :
         /\ row[g].hasClock /\ row[g].clock[o] >= k
         /\ LET m == [version |-> row[g], hint |-> <<o, k>>]
            IN /\ m \notin net[h]
               /\ net' = [net EXCEPT ![h] = @ \cup {m}]
    /\ UNCHANGED <<row, ctr, rec, seen, losses, known, edits, beaten,
                   migrated, resent>>

\* Periodic head announcement: a lost latest counter becomes a visible gap.
Announce(o, h) ==
    /\ Backfill /\ o # h /\ seen[h][o] < ctr[o]
    /\ seen' = [seen EXCEPT ![h][o] = ctr[o]]
    /\ UNCHANGED <<row, ctr, net, rec, losses, known, edits, beaten, migrated,
                   resent>>

\* Fairness is per inbox: a quiet host eventually drains what reached it.
DeliverAny(h) == \E m \in net[h] : Deliver(h, m)

Next == \/ \E h \in Hosts : Edit(h) \/ Migrate(h) \/ StampBeaten(h) \/ Resend(h)
        \/ \E h \in Hosts : DeliverAny(h) \/ \E m \in net[h] : Lose(h, m)
        \/ \E h, o \in Hosts, k \in 1..MaxCounter : Answer(h, o, k)
        \/ \E h, o \in Hosts : Announce(o, h)

Spec == Init /\ [][Next]_vars
        /\ (\A h \in Hosts : WF_vars(StampBeaten(h)))
        /\ (\A h \in Hosts : WF_vars(DeliverAny(h)))
        /\ (\A h, o \in Hosts, k \in 1..MaxCounter : WF_vars(Answer(h, o, k)))
        /\ (\A h, o \in Hosts : WF_vars(Announce(o, h)))

TypeOK == /\ row \in [Hosts -> Versions \cup {None}]
          /\ ctr \in [Hosts -> Counters]
          /\ net \in [Hosts -> SUBSET Messages]
          /\ losses \in 0..MaxLoss

\* Equal clocks name one version: the same document on every host.
EqualClocksAgree == \A a, b \in Hosts :
    (row[a].hasClock /\ row[b].hasClock /\ row[a].clock = row[b].clock)
        => row[a] = row[b]

\* A write supersedes everything its author had seen: wherever the write is
\* known, none of those versions is the stored one.
CausalWriteWins == \A h \in Hosts, e \in edits :
    e.content \in ContentsOf(known[h]) => row[h].content \notin e.before

\* Legacy rows replicated by updatedAt before clocks existed; giving them
\* clocks must not change which one wins. A host may hold an older one for
\* a while — a clockless copy does not displace a clocked row — but never
\* replaces a legacy version by an older one ...
IsLegacy(content) == content \in {LegacyContent(x) : x \in Hosts}
LegacyNeverRegresses == [][\A h \in Hosts :
    (/\ IsLegacy(row[h].content) /\ IsLegacy(row'[h].content)
     /\ row'[h].content # row[h].content)
        => Later(row'[h], row[h])]_vars

\* ... and once the migration has run, with nothing edited, every host ends
\* up holding the newest legacy version.
NewestLegacy ==
    LET L == {k \in UNION {known[h] : h \in Hosts} : IsLegacy(k.content)}
    IN (CHOOSE k \in L : \A j \in L : j = k \/ ~Later(j, k)).content
NewestLegacyWins ==
    <>[]((migrated /\ edits = {}) =>
         \A h \in Hosts : row[h].content = NewestLegacy)

\* Resolution spends no counter: every counter is a write or a stamp.
CountersAreWrites == \A h, g \in Hosts : row[g].clock[h] <= ctr[h]

\* Once the migration has run on any one host — or every row was written
\* with a clock — all hosts end up holding the same content, under a clock
\* unless nothing was ever written.
Converged == \A a, b \in Hosts : /\ row[a].content = row[b].content
                                 /\ row[a] = None \/ row[a].hasClock
EventuallyConverged == (<>(migrated \/ ~Legacy)) => <>[]Converged

\* Every counter a host learns of is eventually received: some host's
\* stored version still covers it, so a backfill request is answered.
GapsHeal == <>[](\A h, o \in Hosts : Gap(h, o) = {})
=============================================================================
