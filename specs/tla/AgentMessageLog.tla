--------------------------- MODULE AgentMessageLog ---------------------------
(***************************************************************************)
(* One agent's causal message log (ADR 0016) on several devices: local     *)
(* appends chained off the agent's head pointer, the fork healer's join    *)
(* (ADR 0018 rules 7 and 8), and sync, which delivers every row — message, *)
(* `messagePrev` edge, agent-state version — separately, once, and in any  *)
(* order.                                                                  *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Append        AgentSyncService._appendMessage: one transaction reads  *)
(*                 the state row's recentHeadMessageId, advances it past   *)
(*                 any child it already has here to a tip beyond it        *)
(*                 (AgentMessageDag.tipFrom), chains the message off that  *)
(*                 (prevMessageId + edge `msgprev-<id>`) and moves the     *)
(*                 head. A null head over a non-empty log goes through     *)
(*                 _recoverHead: the legacy spine (_backfillMessageChain)  *)
(*                 only for a log with no DAG evidence, otherwise a head   *)
(*                 of the local projection, writing no edge                *)
(*   StateWrite    every other local agent-state write (updateAgentState,  *)
(*                 _upsertAgentStatePreservingHead): keeps the persisted   *)
(*                 head, bumps the clock and updatedAt (floored, ADR 0068) *)
(*   HealPlan      ForkHealer.maybeHealFork: reads the log outside any     *)
(*                 transaction, projects the heads and plans a join when   *)
(*                 the view is complete (planJoin, the projection's        *)
(*                 danglingParentIds, _hasUnsyncedEdge)                    *)
(*   HealCommit    AgentSyncService.appendJoin: one transaction writes the *)
(*                 content-addressed join and its edges, and moves the     *)
(*                 head only while it sits on a joined parent (or is       *)
(*                 unset). An Append may run between plan and commit: the  *)
(*                 wake-start hook timed out and the executor went ahead   *)
(*   Deliver       the sync receive path: rows are keyed by id; an edge or *)
(*                 state version is resolved by vector clock, then last-   *)
(*                 writer-wins on (updatedAt, host)                        *)
(*                 (resolveAgentEntityVersions). The head is merged apart  *)
(*                 from the other fields (mergeAgentHeads, ADR 0076): of   *)
(*                 two heads the one that descends from the other here     *)
(*                 wins, and two heads with no known order go by id. A     *)
(*                 state version is read, resolved and written in one      *)
(*                 transaction (_applyAgentStateMessage)                   *)
(*   ReceiveWrite  only with AtomicReceive FALSE: the write of a state     *)
(*                 version resolved against a local row read earlier       *)
(*   Crash         process death: a planned, uncommitted join is lost;     *)
(*                 committed rows and their outbox entries survive (the    *)
(*                 sequence log re-delivers them, SyncSequence.tla)        *)
(*                                                                         *)
(* A join's identity is its parent set, as computeJoinId's digest is. A    *)
(* row's createdAt is the minting device's clock; the device with the      *)
(* highest id runs `Skew` ticks ahead, so createdAt order can disagree     *)
(* with causal order. The six switches are TRUE in the code; setting one   *)
(* FALSE restores the behaviour before ADR 0071 (the first three) or ADR    *)
(* 0076 (the last three). `badJoin`, `ctOf` and                            *)
(* `prevOf` are ghosts: what the minting device knew, which no other       *)
(* device's rows need to show.                                             *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Devices,          \* a set of positive integers
    SlowAppends,      \* local appends per device on the correct clock
    FastAppends,      \* local appends on the device whose clock runs ahead
    SlowStateWrites,  \* other local state-row writes, likewise
    FastStateWrites,
    MaxHeals,         \* committed joins per device
    MaxCrashes,
    Skew,             \* how far the highest device's clock runs ahead
    SafeRecovery,     \* a null head never rewrites an existing DAG
    ChainEdgeGate,    \* a message whose own edge has not synced defers a heal
    JoinEdgeGate,     \* any join (not only a head) whose missing edges point
                      \* at heads defers a heal
    HeadMerge,        \* a received state version's head is merged by ancestry
    TipAppend,        \* an append chains off a tip at or beyond the head
    AtomicReceive     \* a state version is read, resolved and written at once

None == [k |-> "none", d |-> 0, n |-> 0, p |-> {}]
Msg(d, n) == [k |-> "m", d |-> d, n |-> n, p |-> {}]
Join(S) == [k |-> "j", d |-> 0, n |-> 0, p |-> S]

\* Edge ids: `msgprev-<child>` for an append (and the legacy spine), and
\* `msgprev-<join>-<parent>` for a join edge.
ChainEid(x) == [from |-> x, par |-> None]
JoinEid(j, p) == [from |-> j, par |-> p]

Fast == CHOOSE d \in Devices : \A e \in Devices : e <= d
\* createdAt: unique per mint, the fast device `Skew` ticks ahead.
Stamp(d, t) == 2 * t + (IF d = Fast THEN 2 * Skew + 1 ELSE 0)
Appends(d) == IF d = Fast THEN FastAppends ELSE SlowAppends
StateWrites(d) == IF d = Fast THEN FastStateWrites ELSE SlowStateWrites

VARIABLES
    nodes,     \* per device: message rows present (messages and joins)
    edges,     \* per device: messagePrev link rows [eid, to, ver]
    st,        \* per device: the agent-state row [head, vc, ts, by]
    ctOf,      \* ghost: createdAt of each minted row
    prevOf,    \* ghost: prevMessageId each message was minted with
    sent,      \* every row version ever emitted to sync
    got,       \* per device: the emitted rows it has processed (once each)
    plan,      \* per device: a planned, uncommitted join's parents, or {}
    cnt,       \* appends per device
    sw,        \* state writes per device
    heals,     \* committed joins per device
    now,       \* global mint counter
    crashes,
    badJoin,   \* ghost: a join was planned over a non-tip
    rcv        \* per device: a resolved state row not yet written ({} or
               \* one row; only with AtomicReceive FALSE)

vars == <<nodes, edges, st, ctOf, prevOf, sent, got, plan, cnt, sw, heals,
          now, crashes, badJoin, rcv>>

Max(a, b) == IF a >= b THEN a ELSE b

-----------------------------------------------------------------------------
(* The local projection (agentEventsFromLog + project).                    *)

\* Edges are loaded by child id (getLinksFromMultiple), so only the edges of
\* present rows count.
LocalEdges(d) == {e \in edges[d] : e.eid.from \in nodes[d]}
Parents(d, x) == {e.to : e \in {f \in LocalEdges(d) : f.eid.from = x}}
Heads(d) == {x \in nodes[d] : ~\E e \in LocalEdges(d) : e.to = x}
Dangling(d) == {e.to : e \in LocalEdges(d)} \ nodes[d]

RECURSIVE Closure(_, _, _)
Closure(d, frontier, seen) ==
    IF frontier = {} THEN seen
    ELSE LET next == UNION {Parents(d, x) : x \in frontier} \ seen
         IN Closure(d, next, seen \cup next)
Ancestors(d, x) == Closure(d, {x}, {})
Cyclic(d) == \E x \in nodes[d] : x \in Ancestors(d, x)

\* _hasUnsyncedEdge, joins: a join (head or not) whose arrived parents plus
\* some other heads reproduce its content-addressed id is still waiting for
\* the edges to those heads.
JoinMissingEdges(d) ==
    \E j \in nodes[d] :
        LET missing == j.p \ Parents(d, j)
        IN j.k = "j" /\ missing # {} /\ missing \subseteq Heads(d)

\* The guard before ADR 0071 (JoinEdgeGate = FALSE): only a join head with
\* fewer than two arrived parents, and only when some other heads complete
\* its id.
PendingJoinHead(d) ==
    \E j \in Heads(d) :
        /\ j.k = "j"
        /\ Cardinality(Parents(d, j)) < 2
        /\ \E S \in SUBSET (Heads(d) \ {j}) :
              /\ Cardinality(Parents(d, j) \cup S) >= 2
              /\ Parents(d, j) \cup S = j.p

PendingJoin(d) ==
    IF JoinEdgeGate THEN JoinMissingEdges(d) ELSE PendingJoinHead(d)

\* _hasUnsyncedEdge, messages: a message whose prevMessageId names a present
\* row, but whose edge has not arrived, makes that row look like a head. (A
\* prevMessageId naming an absent row constrains nothing: the observation
\* sweep deletes the edges into what it prunes.)
UnsyncedChainEdge(d) ==
    \E x \in nodes[d] :
        /\ x.k = "m"
        /\ prevOf[x] \in nodes[d]
        /\ Parents(d, x) = {}

ViewComplete(d) ==
    /\ Dangling(d) = {}
    /\ ~PendingJoin(d)
    /\ (ChainEdgeGate => ~UnsyncedChainEdge(d))

\* A planned parent that has a real child on this device is not a tip.
TrueChild(c, p) ==
    \/ c.k = "m" /\ prevOf[c] = p
    \/ c.k = "j" /\ p \in c.p
NonTip(d, H) == \E p \in H, c \in nodes[d] : TrueChild(c, p)

\* A join here misses the edge to a parent that is not a head: absent, or
\* with another child. A join row names none of its parents — only its
\* digest does — so the healer can only test the heads it holds against the
\* digest (README: residuals).
BlindJoin(d) ==
    \E j \in nodes[d] :
        LET missing == j.p \ Parents(d, j)
        IN j.k = "j" /\ missing # {} /\ ~(missing \subseteq Heads(d))

-----------------------------------------------------------------------------
(* The legacy spine (_backfillMessageChain): every row but the oldest gets *)
(* `msgprev-<id>` to its predecessor by createdAt.                         *)

Pred(d, x) ==
    LET older == {y \in nodes[d] : ctOf[y] < ctOf[x]}
    IN CHOOSE y \in older : \A z \in older : ctOf[z] <= ctOf[y]
Newest(d) == CHOOSE y \in nodes[d] : \A z \in nodes[d] : ctOf[z] <= ctOf[y]
SpineEdges(d) ==
    {[eid |-> ChainEid(x), to |-> Pred(d, x), ver |-> <<ctOf[x], d>>] :
        x \in {y \in nodes[d] : \E z \in nodes[d] : ctOf[z] < ctOf[y]}}

\* A log with no DAG evidence: no edge, no join, no message minted with a
\* parent.
Legacy(d) ==
    /\ LocalEdges(d) = {}
    /\ \A x \in nodes[d] : x.k = "m" /\ prevOf[x] = None

\* Upsert edge rows by id; a local write replaces the row.
WriteEdges(E, new) ==
    {e \in E : ~\E f \in new : f.eid = e.eid} \cup new

-----------------------------------------------------------------------------

\* A local write of the state row: the clock ticks, updatedAt never goes
\* back (ADR 0068).
Bump(d, row, head, ts) ==
    [head |-> head, vc |-> [row.vc EXCEPT ![d] = @ + 1],
     ts |-> Max(ts, row.ts), by |-> d]

\* Every emitted row version, tagged with the device that wrote it. Unused
\* fields hold placeholders of the same shape, so TLC can compare items.
NoEdge == [eid |-> ChainEid(None), to |-> None, ver |-> <<0, 0>>]
NoRow == [head |-> None, vc |-> [e \in Devices |-> 0], ts |-> 0, by |-> 0]
NodeItem(d, x) == [t |-> "node", src |-> d, id |-> x, e |-> NoEdge, s |-> NoRow]
EdgeItems(d, E) ==
    {[t |-> "edge", src |-> d, id |-> None, e |-> e, s |-> NoRow] : e \in E}
StateItem(d, row) ==
    [t |-> "state", src |-> d, id |-> None, e |-> NoEdge, s |-> row]

\* A device has processed what it wrote itself.
Emit(d, items) ==
    /\ sent' = sent \cup items
    /\ got' = [got EXCEPT ![d] = @ \cup items]

Init ==
    /\ nodes = [d \in Devices |-> {}]
    /\ edges = [d \in Devices |-> {}]
    /\ st = [d \in Devices |-> NoRow]
    /\ ctOf = [x \in {} |-> 0]
    /\ prevOf = [x \in {} |-> None]
    /\ sent = {}
    /\ got = [d \in Devices |-> {}]
    /\ plan = [d \in Devices |-> {}]
    /\ cnt = [d \in Devices |-> 0]
    /\ sw = [d \in Devices |-> 0]
    /\ heals = [d \in Devices |-> 0]
    /\ now = 0
    /\ crashes = 0
    /\ badJoin = FALSE
    /\ rcv = [d \in Devices |-> {}]

\* The tips at or beyond head `h` (AgentMessageDag.tipFrom): `h` itself
\* when nothing here descends from it. The code follows one child at a
\* time, the lowest id first; any tip here over-approximates that choice.
Advance(d, h) ==
    LET beyond == {t \in Heads(d) : h \in Ancestors(d, t)}
    IN IF TipAppend /\ beyond # {} THEN beyond ELSE {h}

\* The head an append chains off, and the edges recovering it writes.
Recovery(d) ==
    LET h0 == st[d].head IN
    IF h0 # None THEN {[head |-> h, spine |-> {}] : h \in Advance(d, h0)}
    ELSE IF nodes[d] = {} THEN {[head |-> None, spine |-> {}]}
    ELSE IF ~SafeRecovery \/ Legacy(d)
         THEN {[head |-> Newest(d), spine |-> SpineEdges(d)]}
    \* A head of the local projection; a root on a corrupt (cyclic) log. The
    \* code prefers a head no present row names as its prevMessageId; any
    \* head here over-approximates that choice.
    ELSE IF Cyclic(d) THEN {[head |-> None, spine |-> {}]}
    ELSE {[head |-> h, spine |-> {}] : h \in Heads(d)}

Append(d) ==
    /\ cnt[d] < Appends(d)
    /\ \E r \in Recovery(d) :
        LET m == Msg(d, cnt[d] + 1)
            c == Stamp(d, now + 1)
            own == IF r.head = None THEN {}
                   ELSE {[eid |-> ChainEid(m), to |-> r.head, ver |-> <<c, d>>]}
            row == Bump(d, st[d], m, c)
        IN /\ nodes' = [nodes EXCEPT ![d] = @ \cup {m}]
           /\ edges' = [edges EXCEPT ![d] = WriteEdges(@, r.spine \cup own)]
           /\ st' = [st EXCEPT ![d] = row]
           /\ ctOf' = [x \in DOMAIN ctOf \cup {m} |->
                         IF x = m THEN c ELSE ctOf[x]]
           /\ prevOf' = [x \in DOMAIN prevOf \cup {m} |->
                           IF x = m THEN r.head ELSE prevOf[x]]
           /\ Emit(d, {NodeItem(d, m), StateItem(d, row)}
                          \cup EdgeItems(d, r.spine \cup own))
    /\ cnt' = [cnt EXCEPT ![d] = @ + 1]
    /\ now' = now + 1
    /\ UNCHANGED <<plan, sw, heals, crashes, badJoin, rcv>>

StateWrite(d) ==
    /\ sw[d] < StateWrites(d)
    /\ LET row == Bump(d, st[d], st[d].head, Stamp(d, now + 1))
       IN /\ st' = [st EXCEPT ![d] = row]
          /\ Emit(d, {StateItem(d, row)})
    /\ sw' = [sw EXCEPT ![d] = @ + 1]
    /\ now' = now + 1
    /\ UNCHANGED <<nodes, edges, ctOf, prevOf, plan, cnt, heals, crashes,
                   badJoin, rcv>>

HealPlan(d) ==
    /\ plan[d] = {}
    /\ heals[d] < MaxHeals
    /\ ~Cyclic(d)
    /\ Cardinality(Heads(d)) >= 2
    /\ ViewComplete(d)
    /\ plan' = [plan EXCEPT ![d] = Heads(d)]
    /\ badJoin' = (badJoin \/ (NonTip(d, Heads(d)) /\ ~BlindJoin(d)))
    /\ UNCHANGED <<nodes, edges, st, ctOf, prevOf, sent, got, cnt, sw, heals,
                   now, crashes, rcv>>

HealCommit(d) ==
    /\ plan[d] # {}
    /\ LET P == plan[d]
           j == Join(P)
           c == Stamp(d, now + 1)
           E == {[eid |-> JoinEid(j, p), to |-> p, ver |-> <<c, d>>] : p \in P}
           move == st[d].head # j /\ (st[d].head = None \/ st[d].head \in P)
           row == IF move THEN Bump(d, st[d], j, c) ELSE st[d]
       IN /\ nodes' = [nodes EXCEPT ![d] = @ \cup {j}]
          /\ edges' = [edges EXCEPT ![d] = WriteEdges(@, E)]
          /\ st' = [st EXCEPT ![d] = row]
          /\ ctOf' = IF j \in DOMAIN ctOf THEN ctOf
                     ELSE [x \in DOMAIN ctOf \cup {j} |->
                             IF x = j THEN c ELSE ctOf[x]]
          /\ Emit(d, {NodeItem(d, j)} \cup EdgeItems(d, E)
                     \cup (IF move THEN {StateItem(d, row)} ELSE {}))
    /\ plan' = [plan EXCEPT ![d] = {}]
    /\ heals' = [heals EXCEPT ![d] = @ + 1]
    /\ now' = now + 1
    /\ UNCHANGED <<prevOf, cnt, sw, crashes, badJoin, rcv>>

Crash(d) ==
    /\ crashes < MaxCrashes
    /\ plan[d] # {}
    /\ plan' = [plan EXCEPT ![d] = {}]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<nodes, edges, st, ctOf, prevOf, sent, got, cnt, sw, heals,
                   now, badJoin, rcv>>

-----------------------------------------------------------------------------
(* Receiving.                                                              *)

Dominates(a, b) == (\A e \in Devices : a[e] >= b[e]) /\ a # b
Later(a, b) == a[1] > b[1] \/ (a[1] = b[1] /\ a[2] > b[2])

\* Head `a` is an ancestor of `b` here: the question the caller answers from
\* the local DAG before the merge (AgentMessageDag.ancestryOf).
Below(d, a, b) == a \in Ancestors(d, b)

\* mergeAgentHeads: an unset head carries no information; of two heads the
\* one that descends from the other wins; two heads with no order known
\* here — a true fork, or rows not yet delivered — go by a fixed order on
\* ids, never by clock or arrival. TLC's value order stands in for the
\* code's id order.
MergeHead(d, l, i) ==
    IF i = None \/ i = l THEN l
    ELSE IF l = None THEN i
    ELSE IF Below(d, l, i) THEN i
    ELSE IF Below(d, i, l) THEN l
    ELSE CHOOSE x \in {l, i} : TRUE

\* resolveAgentEntityVersions for the state row. A dominating version keeps
\* the local head only when that head is known to descend from its own (or
\* its own is unset); a concurrent pair merges the heads.
ResolveState(d, local, in) ==
    IF Dominates(in.vc, local.vc) THEN
        IF HeadMerge /\ (in.head = None \/ Below(d, in.head, local.head))
        THEN [in EXCEPT !.head = local.head]
        ELSE in
    ELSE IF Dominates(local.vc, in.vc) \/ local.vc = in.vc THEN local
    ELSE LET w == IF Later(<<in.ts, in.by>>, <<local.ts, local.by>>)
                  THEN in ELSE local
         IN IF HeadMerge THEN [w EXCEPT !.head = MergeHead(d, local.head, in.head)]
            ELSE w

\* Every edge version is concurrent with every other one (each link write
\* starts from a null clock), so last-writer-wins decides.
ResolveEdges(E, in) ==
    LET same == {e \in E : e.eid = in.eid} IN
    IF same = {} THEN E \cup {in}
    ELSE LET cur == CHOOSE e \in same : TRUE IN
         IF Later(in.ver, cur.ver) THEN (E \ same) \cup {in} ELSE E

\* The processor handles one row at a time, so nothing is delivered to a
\* device while it holds a resolved state row it has not written.
Deliver(d, i) ==
    /\ rcv[d] = {}
    /\ i \in sent \ got[d]
    /\ got' = [got EXCEPT ![d] = @ \cup {i}]
    /\ CASE i.t = "node" ->
              /\ nodes' = [nodes EXCEPT ![d] = @ \cup {i.id}]
              /\ UNCHANGED <<edges, st, rcv>>
         [] i.t = "edge" ->
              /\ edges' = [edges EXCEPT ![d] = ResolveEdges(@, i.e)]
              /\ UNCHANGED <<nodes, st, rcv>>
         [] OTHER ->
              /\ IF AtomicReceive
                 THEN /\ st' = [st EXCEPT ![d] = ResolveState(d, @, i.s)]
                      /\ UNCHANGED rcv
                 ELSE /\ rcv' = [rcv EXCEPT ![d] = {ResolveState(d, st[d], i.s)}]
                      /\ UNCHANGED st
              /\ UNCHANGED <<nodes, edges>>
    /\ UNCHANGED <<ctOf, prevOf, sent, plan, cnt, sw, heals, now, crashes,
                   badJoin>>

\* The write of a state row resolved against the row read before it: any
\* local write in between is lost.
ReceiveWrite(d) ==
    /\ rcv[d] # {}
    /\ st' = [st EXCEPT ![d] = CHOOSE r \in rcv[d] : TRUE]
    /\ rcv' = [rcv EXCEPT ![d] = {}]
    /\ UNCHANGED <<nodes, edges, ctOf, prevOf, sent, got, plan, cnt, sw, heals,
                   now, crashes, badJoin>>

Next ==
    \/ \E d \in Devices :
          \/ Append(d) \/ StateWrite(d) \/ HealPlan(d) \/ HealCommit(d)
          \/ Crash(d) \/ ReceiveWrite(d)
    \/ \E d \in Devices, i \in sent : Deliver(d, i)

\* Sync delivers everything eventually; a wake that finds a fork over a
\* complete view heals it; a planned join commits unless the process dies.
Fairness ==
    \A d \in Devices :
        /\ WF_vars(HealPlan(d))
        /\ WF_vars(HealCommit(d))
        /\ WF_vars(\E i \in sent : Deliver(d, i))
        /\ WF_vars(ReceiveWrite(d))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
(* Properties.                                                             *)

TypeOK ==
    /\ \A d \in Devices : plan[d] = {} \/ Cardinality(plan[d]) >= 2
    /\ \A d \in Devices : got[d] \subseteq sent
    /\ now \in Nat

\* The log never holds a cycle: canonicalOrder would throw, and the
\* reconcile fold and the healer would skip the agent for good.
Acyclic == \A d \in Devices : ~Cyclic(d)

\* An edge id names one parent for ever. Two targets for one id resolve
\* differently on different devices, so their DAGs need not converge.
EdgesImmutable ==
    \A i, j \in {s \in sent : s.t = "edge"} :
        i.e.eid = j.e.eid => i.e.to = j.e.to

\* A join is only planned over tips: never over a row this device already
\* holds a child of (planJoin's complete-view gate) — short of a BlindJoin,
\* which HealPlan does not count (README: residuals).
NoJoinOverNonTip == ~badJoin

AllDelivered == \A d \in Devices : got[d] = sent

\* Once sync settles, every device holds the same DAG.
Converged ==
    AllDelivered =>
        \A d, e \in Devices :
            {<<x.eid, x.to>> : x \in edges[d]} = {<<x.eid, x.to>> : x \in edges[e]}

\* Every device ends with one head: forks heal.
EventuallySingleHead ==
    <>[](\A d \in Devices : Cardinality(Heads(d)) <= 1)

\* A compact view for reading counterexamples (`ALIAS TraceView`): message
\* <<d, n>> is device d's n-th append, a join is the set of its parents.
RECURSIVE Short(_)
Short(x) ==
    IF x.k = "m" THEN <<x.d, x.n>>
    ELSE IF x.k = "j" THEN {Short(p) : p \in x.p}
    ELSE "none"
TraceView ==
    [d \in Devices |->
        [nodes |-> {Short(x) : x \in nodes[d]},
         edges |-> {<<Short(e.eid.from), Short(e.to)>> : e \in edges[d]},
         head |-> Short(st[d].head),
         plan |-> {Short(x) : x \in plan[d]}]]

\* A device's own write moves its head only forward: the new head descends
\* from the old one. appendJoin's guard is what keeps a join committed after
\* the executor appended (a timed-out heal) from moving the head back onto
\* the join and orphaning that append.
LocalHeadAdvances ==
    [][\A d \in Devices :
         (/\ sent' # sent
          /\ (sent' \ sent) \subseteq got'[d]
          /\ st[d].head # None
          /\ st'[d].head # st[d].head)
            => st[d].head \in (Ancestors(d, st[d].head))']_vars

\* No state write — a delivered version above all — moves the head pointer
\* back to an ancestor of the one it replaces (ADR 0076). A version whose
\* head is not known here to be older can still move it sideways, onto
\* another fork's tip, or onto a row still in flight; `AppendsOffTips` is
\* what keeps that from forking the log.
HeadNeverRegresses ==
    [][\A d \in Devices :
         st[d].head # None => st'[d].head \notin Ancestors(d, st[d].head)]_vars

\* An append never chains off a row that already has a child here: the log
\* forks only when two devices append concurrently, never because one of
\* them holds a stale head pointer.
AppendsOffTips ==
    [][\A d \in Devices :
         \A m \in nodes'[d] \ nodes[d] :
             (m.k = "m" /\ m.d = d /\ prevOf'[m] # None)
                 => ~\E e \in LocalEdges(d) : e.to = prevOf'[m]]_vars

\* Once sync settles on one head, every device's next append chains off it,
\* whatever its head pointer says.
SettledHead ==
    \A d \in Devices :
        (AllDelivered /\ rcv[d] = {} /\ Cardinality(Heads(d)) = 1)
            => {r.head : r \in Recovery(d)} = Heads(d)

\* Not claimed: the head pointers themselves agree once sync settles. A
\* pointer left on an ancestor by a merge made before the rows arrived
\* stays there until the next append advances past it.
PointersConverge ==
    (AllDelivered /\ \A d \in Devices : Cardinality(Heads(d)) = 1)
        => \A d, e \in Devices : st[d].head = st[e].head
=============================================================================
