---------------------------- MODULE AiConfigClocks ----------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************)
(* One AI configuration id — a provider, model, prompt, inference profile  *)
(* or skill — and how its versions are repaired when a message is lost     *)
(* (ADR 0136). AiConfigReplication checks the order versions are kept in; *)
(* this model takes that order as given and checks the counters on top.    *)
(*                                                                         *)
(* A version is a live row or a hard deletion (a stamp with no row), with  *)
(* AiConfigDb's stamp and its content (ADR 0094). The stamp decides: the   *)
(* greater stamp wins, on a tie a deletion beats a row, then the greater   *)
(* content. The vector clock never orders versions. It lets a receiver see *)
(* that it missed one: every write sent spends the writer's next counter   *)
(* on top of the clock held, a receiver learns the counters in a clock it  *)
(* processes and sees the ones below as gaps, a head announcement exposes  *)
(* a lost latest counter, and any host whose held clock covers a missing   *)
(* counter answers with the version it holds now and a hint naming the    *)
(* counter (sequence-log backfill). Delivery is lossy (MaxLoss).            *)
(*                                                                         *)
(* Writes:                                                                  *)
(*   Edit     a user's save or deletion: stamped past the held version, so *)
(*            it is always written (AiConfigDb._nextLocalStamp)            *)
(*   Derive   a write a device works out for itself: a provider's orphan   *)
(*            model deleted at the provider deletion's stamp, or a model   *)
(*            created at its provider's stamp. Its stamp is not the        *)
(*            device's clock, so it may tie or trail the held one          *)
(*                                                                         *)
(* Switches, each TRUE in the implementation, FALSE to reproduce the       *)
(* failure it guards against (README):                                     *)
(*   JoinOnApply      a written copy is held under the join of both clocks, *)
(*                    not its own                                           *)
(* A copy that loses still joins its clock into the held one, as the code   *)
(* does. No property here needs that: the writer of a counter always holds  *)
(* it, and every host answers. It matters once the writer's device is gone  *)
(* for good, which this model leaves out.                                   *)
(*   ClockOnDeletion  a hard deletion keeps the clock (ai_config_versions), *)
(*                    not only the row                                      *)
(*   DerivedCounts    a derived write spends a counter like an edit         *)
(*   SendHeld         a derived write is sent only as the version it        *)
(*                    leaves held: one that would lose locally is not      *)
(*                    written (the orphan cleanup skips a newer model; a   *)
(*                    model that would lose at its provider's stamp takes  *)
(*                    the next local stamp instead)                        *)
(***************************************************************************)
CONSTANTS Hosts, MaxCounter, Stamps, MaxLoss, MaxDerive,
          JoinOnApply, ClockOnDeletion, DerivedCounts,
          SendHeld

ASSUME /\ Cardinality(Hosts) \in 2..3
       /\ MaxCounter \in 1..3
       /\ Stamps \subseteq 1..9 /\ Stamps # {}
       /\ MaxLoss \in Nat /\ MaxDerive \in Nat

Ix == CHOOSE f \in [Hosts -> 1..Cardinality(Hosts)] :
          \A x, y \in Hosts : x # y => f[x] # f[y]
Counters == 0..MaxCounter
Zero == [h \in Hosts |-> 0]
Clocks == [Hosts -> Counters]
Kinds == {"none", "live", "gone"}
\* Host h's row written at its counter n, or as its d-th derived write.
\* Deletions carry no content: two at one stamp are one version.
EditContent(h, n) == 10 * Ix[h] + n
DeriveContent(h, d) == 100 + 10 * Ix[h] + d
Contents == {0} \cup {EditContent(h, n) : h \in Hosts, n \in 1..MaxCounter}
            \cup {DeriveContent(h, d) : h \in Hosts, d \in 1..MaxDerive}
None == [kind |-> "none", stamp |-> 0, content |-> 0, clock |-> Zero]
Versions == [kind : Kinds, stamp : {0} \cup Stamps, content : Contents,
             clock : Clocks]
Messages == [version : Versions, hint : (Hosts \X (1..MaxCounter)) \cup {<<>>}]

Join(x, y) == [h \in Hosts |-> IF x[h] >= y[h] THEN x[h] ELSE y[h]]

\* AiConfigDb's order (ADR 0094): stamp, then a deletion over a row, then
\* content. Same names one version whatever the clocks.
Same(a, b) == a.kind = b.kind /\ a.stamp = b.stamp /\ a.content = b.content
Above(a, b) ==
    \/ a.stamp > b.stamp
    \/ /\ a.stamp = b.stamp
       /\ \/ a.kind = "gone" /\ b.kind # "gone"
          \/ a.kind = b.kind /\ a.content > b.content
AtLeast(a, b) == Above(a, b) \/ Same(a, b)

\* What a host holds: without ClockOnDeletion a hard deletion keeps no clock.
Held(v) == IF v.kind = "gone" /\ ~ClockOnDeletion
           THEN [v EXCEPT !.clock = Zero] ELSE v

\* The receiving rule: applyConfigVersion and applyConfigDeletion.
Gate(st, in) ==
    IF st.kind = "none" THEN Held(in)
    ELSE IF Above(in, st)
    THEN Held([in EXCEPT !.clock = IF JoinOnApply THEN Join(st.clock, @)
                                   ELSE @])
    ELSE Held([st EXCEPT !.clock = Join(@, in.clock)])

\* A written version, by the counter it spent.
Record(o, k, v) == [o |-> o, k |-> k, version |-> v]

\* `written`: each counter spent, with its version. `sent`: every version
\* that went out, counted or not.
VARIABLES row, ctr, net, rec, seen, losses, written, derived, sent
vars == <<row, ctr, net, rec, seen, losses, written, derived, sent>>

Init ==
    /\ row = [h \in Hosts |-> None]
    /\ ctr = [h \in Hosts |-> 0]
    /\ net = [h \in Hosts |-> {}]
    /\ rec = [h \in Hosts |-> [o \in Hosts |-> {}]]
    /\ seen = [h \in Hosts |-> [o \in Hosts |-> 0]]
    /\ losses = 0
    /\ written = {}
    /\ derived = [h \in Hosts |-> 0]
    /\ sent = {}

Broadcast(h, v) == [x \in Hosts |->
    IF x = h THEN net[x] ELSE net[x] \cup {[version |-> v, hint |-> <<>>]}]

\* A user's save or deletion: the next counter on top of the held clock, a
\* stamp past the held version.
Edit(h) ==
    /\ ctr[h] < MaxCounter
    /\ \E kind \in {"live", "gone"}, stamp \in Stamps :
         /\ stamp > row[h].stamp
         /\ LET n == ctr[h] + 1
                v == [kind |-> kind, stamp |-> stamp,
                      content |-> IF kind = "live" THEN EditContent(h, n)
                                  ELSE 0,
                      clock |-> [row[h].clock EXCEPT ![h] = n]]
            IN /\ row' = [row EXCEPT ![h] = Held(v)]
               /\ ctr' = [ctr EXCEPT ![h] = n]
               /\ net' = Broadcast(h, v)
               /\ written' = written \cup {Record(h, n, v)}
               /\ sent' = sent \cup {v}
    /\ UNCHANGED <<rec, seen, losses, derived>>

\* A derived write: any stamp, applied locally through the receiving rule.
\* With SendHeld only one that wins there is written and sent; without it a
\* losing one is sent all the same. Without DerivedCounts it carries the
\* held clock and spends no counter.
Derive(h) ==
    /\ derived[h] < MaxDerive
    /\ DerivedCounts => ctr[h] < MaxCounter
    /\ \E kind \in {"live", "gone"}, stamp \in Stamps :
         LET d == derived[h] + 1
             n == ctr[h] + 1
             v == [kind |-> kind, stamp |-> stamp,
                   content |-> IF kind = "live" THEN DeriveContent(h, d)
                               ELSE 0,
                   clock |-> IF DerivedCounts
                             THEN [row[h].clock EXCEPT ![h] = n]
                             ELSE row[h].clock]
         IN /\ SendHeld => row[h].kind = "none" \/ Above(v, row[h])
            /\ row' = [row EXCEPT ![h] = Gate(@, v)]
            /\ ctr' = IF DerivedCounts THEN [ctr EXCEPT ![h] = n] ELSE ctr
            /\ net' = Broadcast(h, v)
            /\ written' = IF DerivedCounts
                          THEN written \cup {Record(h, n, v)} ELSE written
            /\ derived' = [derived EXCEPT ![h] = d]
            /\ sent' = sent \cup {v}
    /\ UNCHANGED <<rec, seen, losses>>

\* Every counter in a processed clock is received; those below are gaps.
Learn(h, m) ==
    [o \in Hosts |->
        IF o = h THEN rec[h][o]
        ELSE rec[h][o]
             \cup (IF m.version.clock[o] > 0 THEN {m.version.clock[o]} ELSE {})
             \cup (IF m.hint # <<>> /\ m.hint[1] = o THEN {m.hint[2]} ELSE {})]

Deliver(h, m) ==
    /\ m \in net[h]
    /\ row' = [row EXCEPT ![h] = Gate(@, m.version)]
    /\ net' = [net EXCEPT ![h] = @ \ {m}]
    /\ rec' = [rec EXCEPT ![h] = Learn(h, m)]
    /\ seen' = [seen EXCEPT ![h] = [o \in Hosts |->
                  IF o # h /\ m.version.clock[o] > @[o]
                  THEN m.version.clock[o] ELSE @[o]]]
    /\ UNCHANGED <<ctr, losses, written, derived, sent>>

Lose(h, m) ==
    /\ m \in net[h] /\ losses < MaxLoss
    /\ net' = [net EXCEPT ![h] = @ \ {m}]
    /\ losses' = losses + 1
    /\ UNCHANGED <<row, ctr, rec, seen, written, derived, sent>>

Gap(h, o) == {k \in 1..seen[h][o] : k \notin rec[h][o]}

\* Backfill: any host whose held clock covers the counter answers with the
\* version it holds now. One answer per counter is in flight at a time: a
\* request is re-sent only after its answer is lost or processed.
Answer(h, o, k) ==
    /\ o # h /\ k \in Gap(h, o)
    /\ ~\E m \in net[h] : m.hint = <<o, k>>
    /\ \E g \in Hosts \ {h} :
         /\ row[g].kind # "none" /\ row[g].clock[o] >= k
         /\ net' = [net EXCEPT ![h] =
                      @ \cup {[version |-> row[g], hint |-> <<o, k>>]}]
    /\ UNCHANGED <<row, ctr, rec, seen, losses, written, derived, sent>>

\* Periodic head announcement: a lost latest counter becomes a visible gap.
Announce(o, h) ==
    /\ o # h /\ seen[h][o] < ctr[o]
    /\ seen' = [seen EXCEPT ![h][o] = ctr[o]]
    /\ UNCHANGED <<row, ctr, net, rec, losses, written, derived, sent>>

DeliverAny(h) == \E m \in net[h] : Deliver(h, m)

Next == \/ \E h \in Hosts : Edit(h) \/ Derive(h)
        \/ \E h \in Hosts : DeliverAny(h) \/ \E m \in net[h] : Lose(h, m)
        \/ \E h, o \in Hosts, k \in 1..MaxCounter : Answer(h, o, k)
        \/ \E h, o \in Hosts : Announce(o, h)

Spec == Init /\ [][Next]_vars
        /\ (\A h \in Hosts : WF_vars(DeliverAny(h)))
        /\ (\A h, o \in Hosts, k \in 1..MaxCounter : WF_vars(Answer(h, o, k)))
        /\ (\A h, o \in Hosts : WF_vars(Announce(o, h)))

TypeOK == /\ row \in [Hosts -> Versions]
          /\ ctr \in [Hosts -> Counters]
          /\ net \in [Hosts -> SUBSET Messages]
          /\ losses \in 0..MaxLoss

\* Every counter a clock holds was spent on a write.
CountersAreWrites == \A h, g \in Hosts : row[g].clock[h] <= ctr[h]

\* A held clock answers only for versions the held one supersedes: the
\* version a backfill answer carries never sets a receiver back.
CoverageSound == \A g \in Hosts, w \in written :
    row[g].clock[w.o] >= w.k => AtLeast(row[g], w.version)

\* A host never goes back to an older version.
NeverRegresses == [][\A h \in Hosts : AtLeast(row'[h], row[h])]_vars

\* The newest version sent: what every host must end on.
Newest == CHOOSE v \in sent : \A u \in sent : AtLeast(v, u)

\* Every host ends on the same version, and it is the newest written.
Converged ==
    \A a, b \in Hosts : Same(row[a], row[b])
EventuallyConverged ==
    <>[](\/ sent = {}
         \/ \A h \in Hosts : Same(row[h], Newest))

\* Every counter a host learns of is eventually received.
GapsHeal == <>[](\A h, o \in Hosts : Gap(h, o) = {})
=============================================================================
