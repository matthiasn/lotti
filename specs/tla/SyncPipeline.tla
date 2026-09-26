---------------------------- MODULE SyncPipeline ----------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************)
(* Composed durable-write / outbox / room / inbound / receipt / repair       *)
(* protocol. All message kinds use the SAME queues, send/mark window and    *)
(* delivery actions, including requests, payload resends, hints and burns. *)
(* A causal chain or two concurrent writers and receiving devices. Each    *)
(* origin has its own retained payload and per-peer sequence head. Payload *)
(* families differ at staging, collapse, attachment preparation and apply. *)
(*                                                                         *)
(* Recovery runs at release/startup/request and on a periodic timer. Weak  *)
(* fairness assumes the app eventually runs with usable stores and fair   *)
(* timer scheduling. See the scope/obligation table in README.             *)
(* Retained room history is offered fairly to the durable inbound queue;  *)
(* pagination and floor mechanics refine that interface in InboundQueue.   *)
(* No purge, missing stores or permanent partitions. Head-enabled models *)
(* assume recurring origin announcements and timely automatic repair.    *)
(***************************************************************************)
CONSTANTS Family, Peers, MaxCounter, SeparateEntities, AbortCounters, ConcurrentWriters,
          MaxFaults, MaxCrashes, FaultKinds,
          DurableBurn, BindAfterEnqueue, ReceiptAfterApply, VerifyHints,
          PrepareExactPayload, RetryReceipts, AnnounceHeads, MixedFamilies, NamespacePayloads

ASSUME /\ Family \in {"journal", "entryLink", "agentEntity", "agentLink",
                       "notification", "consumptionEvent"}
       /\ MaxCounter \in 1..3
       /\ ConcurrentWriters => MaxCounter >= 2
       /\ MixedFamilies => MaxCounter = 2 /\ Family # "notification"
       /\ AbortCounters \subseteq 1..MaxCounter
       /\ Peers # {} /\ Peers \cap {"sourceA", "sourceB"} = {}
       /\ MaxFaults \in Nat /\ MaxCrashes \in Nat
       /\ FaultKinds \subseteq {"stage", "burnStage", "send", "receive", "apply", "receipt"}

Counters == 1..MaxCounter
FamilyAt(c) == IF MixedFamilies /\ c = MaxCounter THEN "notification" ELSE Family
IsImmutable(c) == FamilyAt(c) = "consumptionEvent"
Entity(c) == <<IF NamespacePayloads THEN FamilyAt(c) ELSE Family,
               IF SeparateEntities \/ IsImmutable(c) THEN c ELSE 1>>
Entities == {Entity(c) : c \in Counters}
Origins == IF ConcurrentWriters THEN {"sourceA", "sourceB"} ELSE {"sourceA"}
Origin(c) == IF ConcurrentWriters /\ c = 2 THEN "sourceB" ELSE "sourceA"
Counter(c) == IF ConcurrentWriters /\ c = 2 THEN 1
              ELSE IF ConcurrentWriters /\ c >= 3 THEN c - 1 ELSE c
Nodes == Peers \cup Origins
IsNotification(c) == FamilyAt(c) = "notification"
FileBacked(c) == FamilyAt(c) \in {"journal", "notification"}
CanCollapse(c) == FamilyAt(c) \in {"journal", "entryLink", "agentEntity", "agentLink"}
Kind(c) == IF IsNotification(c) /\ ~MixedFamilies /\ ~ConcurrentWriters /\ ~SeparateEntities /\ c = 2 THEN "state" ELSE "full"
SameEntity(a, b) == Entity(a) = Entity(b)
Covers(a, b) == SameEntity(a, b) /\
    Origin(a) = Origin(b) /\ Counter(a) >= Counter(b)
Max(S) == CHOOSE v \in S : \A w \in S : v >= w

\* A data message names an immutable payload generation independently of
\* its announced counter and covered counters. Hints carry no payload.
Message(k, sender, target, v, c, cov) ==
    [kind |-> k, sender |-> sender, target |-> target,
     version |-> v, counter |-> c, covered |-> cov]
Data(k, v, c, cov) == Message(k, Origin(c), "all", v, c, cov)
Request(p, c) == Message("request", p, Origin(c), 0, c, {})
Hint(p, c) == Message("hint", Origin(c), p, 0, c, {})
Head(c) == Message("head", Origin(c), "all", 0, c, {})
Burn(c) == Message("burn", Origin(c), "all", 0, c, {})
Coverable(v) == {c \in Counters : c # v /\ Covers(v, c)}
DataCandidates ==
    UNION {{Data(k, v, v, cov) :
              k \in (IF IsNotification(v) THEN {"full", "state"} ELSE {"full"}),
              cov \in SUBSET Counters} : v \in Counters}
    \cup {Data("full", v, c, cov) :
                  v \in {x \in Counters : FamilyAt(x) = "journal"},
                  c \in {x \in Counters : FamilyAt(x) = "journal"},
                  cov \in SUBSET Counters}
DataMessages == {m \in DataCandidates : m.covered \subseteq Coverable(m.counter)}
Messages == DataMessages \cup {Request(p, c) : p \in Peers, c \in Counters}
            \cup {Hint(p, c) : p \in Peers, c \in Counters}
            \cup {Burn(c) : c \in Counters}
            \cup (IF AnnounceHeads THEN {Head(c) : c \in Counters} ELSE {})
IsData(m) == m.kind \in {"full", "state"}
Targets(m) == IF m.target = "all" THEN Peers ELSE {m.target}
Carries(m) == {m.counter} \cup m.covered
OutStates == {"absent", "pending", "claimed", "transmitted", "folded", "sent"}
InStates == {"absent", "queued", "applied", "done", "abandoned"}
\* "reserved" includes an inactive, named burnPending row after release.
OwnStates == {"none", "reserved", "bound", "burned"}

\* Actual payload state: latest full version plus a joined lifecycle bit.
\* A state patch can advance the stored clock without supplying base content.
EmptyRow == [version |-> 0, content |-> 0, conflict |-> 0, marked |-> FALSE]
Content(v) == IF Kind(v) = "state" THEN 1 ELSE v
Marked(v) == Kind(v) = "state"
Merge(row, m) ==
    IF FamilyAt(m.version) = "journal" /\ ConcurrentWriters /\ row.version # 0
       /\ ~Covers(m.version, row.version) /\ ~Covers(row.version, m.version)
    THEN [row EXCEPT !.conflict =
          IF @ = 0 \/ Covers(m.version, @) THEN m.version ELSE @]
    ELSE IF m.kind = "state"
    THEN [row EXCEPT !.version = IF m.version > @ THEN m.version ELSE @,
                      !.marked = TRUE]
    ELSE [version |-> IF m.version > row.version THEN m.version ELSE row.version,
          content |-> IF Content(m.version) > row.content
                      THEN Content(m.version) ELSE row.content,
          conflict |-> row.conflict,
          marked |-> row.marked \/ Marked(m.version)]

VARIABLE s
vars == <<s>>
Init == s = [
    next |-> 1, phase |-> "idle",
    own |-> [c \in Counters |-> "none"],
    source |-> [o \in Origins |-> [e \in Entities |-> 0]],
    committed |-> {},
    staged |-> {},
    descriptor |-> [o \in Origins |-> [e \in Entities |-> 0]],
    out |-> [m \in Messages |-> "absent"],
    again |-> {}, room |-> {}, files |-> {},
    inbox |-> [n \in Nodes |-> [m \in Messages |-> "absent"]],
    downloaded |-> [p \in Peers |-> {}],
    rows |-> [p \in Peers |-> [e \in Entities |-> EmptyRow]],
    applied |-> [p \in Peers |-> {}],
    received |-> [p \in Peers |-> {}],
    burned |-> [p \in Peers |-> {}],
    head |-> [p \in Peers |-> [o \in Origins |-> 0]],
    announced |-> [p \in Peers |-> [o \in Origins |-> 0]],
    hints |-> [p \in Peers |-> {}],
    faults |-> 0, crashes |-> 0]
CanFault(k) == k \in FaultKinds /\ s.faults < MaxFaults
Pending(m) == s.out[m] = "pending"
Queued(n, m) == s.inbox[n][m] = "queued"
Active(c) == s.next = c /\ s.phase # "idle"
SourceCovers(c) == LET v == s.source[Origin(c)][Entity(c)] IN
                     v # 0 /\ Covers(v, c)
Resend(c) == Data(Kind(c), s.source[Origin(c)][Entity(c)], s.source[Origin(c)][Entity(c)], {})
Resolved(p) == s.received[p] \cup s.burned[p]

Observed(p, c) == Counter(c) <= Max({s.head[p][Origin(c)], s.announced[p][Origin(c)]})
Known(p) == {c \in Counters : Observed(p, c)}
AllKnown(p) == Counters \subseteq Known(p)
Observe(head, counters) == [o \in Origins |->
    Max({head[o]} \cup {Counter(c) : c \in {x \in counters : Origin(x) = o}})]

\* Appending an identical resend never mutates an in-flight claim. One
\* additional durable copy suffices in this bounded, idempotent abstraction.
Enqueue(st, m) == [st EXCEPT
    !.out[m] = IF @ \in {"absent", "sent", "folded"} THEN "pending" ELSE @,
    !.again = IF st.out[m] \in {"claimed", "transmitted"} THEN @ \cup {m} ELSE @]

Reserve == /\ s.phase = "idle" /\ s.next \in Counters
           /\ s' = [s EXCEPT !.own[s.next] = "reserved", !.phase = "reserved"]
Commit == /\ s.phase = "reserved" /\ s.next \notin AbortCounters
          /\ Kind(s.next) # "state" \/ s.source[Origin(s.next)][Entity(s.next)] # 0
          /\ s' = [s EXCEPT !.source[Origin(s.next)][Entity(s.next)] = s.next,
                            !.committed = @ \cup {s.next}, !.phase = "committed"]
Abort == /\ s.phase = "reserved"
         /\ s.next \in AbortCounters \/
               (Kind(s.next) = "state" /\ s.source[Origin(s.next)][Entity(s.next)] = 0)
         /\ s' = [s EXCEPT !.next = @ + 1, !.phase = "idle"]
Stage == /\ s.phase = "committed"
         /\ LET c == s.next
                m == Data(Kind(c), c, c, {})
            IN s' = [Enqueue(s, m) EXCEPT !.staged = @ \cup {c}, !.phase = "staged"]
FailStage == /\ s.phase = "committed" /\ CanFault("stage")
             /\ s' = [s EXCEPT !.faults = @ + 1, !.phase = "idle",
                       !.own[s.next] = IF BindAfterEnqueue THEN @ ELSE "bound",
                       !.next = @ + 1]
Bind == /\ s.phase = "staged"
        /\ s' = [s EXCEPT !.own[s.next] = "bound", !.phase = "idle", !.next = @ + 1]
\* Sidecar refresh is a separate durable write. Exact preparation below
\* falls back to the retained canonical row if this descriptor is stale.
Refresh(o, e) == /\ e[1] = "journal" /\ s.descriptor[o][e] < s.source[o][e]
              /\ s' = [s EXCEPT !.descriptor[o][e] = s.source[o][e]]

\* Own-counter recovery queues before binding, as separate durable steps.
RecoverStage(c) ==
    /\ s.own[c] = "reserved" /\ ~Active(c) /\ SourceCovers(c)
    /\ s.out[Resend(c)] = "absent"
    /\ s' = [Enqueue(s, Resend(c)) EXCEPT !.staged = @ \cup {c}]
RecoverBind(c) ==
    /\ s.own[c] = "reserved" /\ ~Active(c) /\ SourceCovers(c)
    /\ s.out[Resend(c)] # "absent"
    /\ s' = [s EXCEPT !.own[c] = "bound"]
BurnStage(c) ==
    /\ s.own[c] = "reserved" /\ ~Active(c) /\ ~SourceCovers(c)
    /\ s.out[Burn(c)] = "absent"
    /\ s' = Enqueue(s, Burn(c))
FailBurnStage(c) ==
    /\ s.own[c] = "reserved" /\ ~Active(c) /\ ~SourceCovers(c)
    /\ s.out[Burn(c)] = "absent" /\ CanFault("burnStage")
    /\ s' = [s EXCEPT !.faults = @ + 1,
                !.own[c] = IF DurableBurn THEN @ ELSE "burned"]
BurnBind(c) ==
    /\ s.own[c] = "reserved" /\ ~Active(c) /\ ~SourceCovers(c)
    /\ s.out[Burn(c)] # "absent"
    /\ s' = [s EXCEPT !.own[c] = "burned"]

\* The claim/collapse is shared by ordinary data and repair resends. Control
\* traffic never collapses. This models a successful CAS; failed CAS retries.
Claim(m) ==
    /\ Pending(m)
    /\ ~CanCollapse(m.version) \/ ~IsData(m) \/
          ~\E x \in DataMessages : Pending(x) /\ x.kind = m.kind
                    /\ Covers(x.version, m.version) /\ x.version > m.version
    /\ LET members == IF CanCollapse(m.version) /\ IsData(m)
                      THEN {x \in DataMessages : Pending(x) /\ x.kind = m.kind
                              /\ Covers(m.version, x.version)} ELSE {m}
           cov == UNION {Carries(x) : x \in members} \ {m.counter}
           send == IF IsData(m)
                   THEN [m EXCEPT !.covered = @ \cup cov] ELSE m
       IN s' = [s EXCEPT !.out = [x \in Messages |->
                    IF x = send THEN "claimed"
                    ELSE IF x \in members THEN "folded" ELSE s.out[x]]]
\* A file generation is uploaded independently of its envelope. A journal
\* can send a fresher canonical snapshot while covering its claimed counter.
Upload(m) == /\ s.out[m] = "claimed" /\ m.kind = "full" /\ FileBacked(m.version)
             /\ m.version \notin s.files
             /\ s' = [s EXCEPT !.files = @ \cup {m.version}]
Send(m) == /\ s.out[m] = "claimed"
           /\ m.kind # "full" \/ ~FileBacked(m.version) \/ m.version \in s.files
           /\ LET actual == IF FamilyAt(m.version) = "journal" /\ ~PrepareExactPayload
                                /\ s.descriptor[m.sender][Entity(m.version)] # 0
                            THEN [m EXCEPT !.version = s.descriptor[m.sender][Entity(m.version)]]
                            ELSE m
              IN s' = [s EXCEPT !.room = @ \cup {actual}, !.out[m] = "transmitted",
                        !.inbox = [n \in Nodes |-> [x \in Messages |->
                          IF x = actual /\ n \in Targets(actual)
                             /\ s.inbox[n][x] \in {"done", "abandoned"}
                          THEN "absent" ELSE s.inbox[n][x]]]]
MarkSent(m) == /\ s.out[m] = "transmitted"
               /\ s' = [s EXCEPT !.out[m] = IF m \in s.again THEN "pending" ELSE "sent",
                                 !.again = @ \ {m}]
\* A failed send remains retryable. A crash after Send but before MarkSent
\* reclaims the same immutable message; duplicate transport copies stutter.
SendFail(m) == /\ s.out[m] = "claimed" /\ CanFault("send")
               /\ s' = [s EXCEPT !.out[m] = "pending", !.faults = @ + 1]

Deliver(n, m) == /\ m \in s.room /\ n \in Targets(m)
                 /\ s.inbox[n][m] = "absent"
                 /\ s' = [s EXCEPT !.inbox[n][m] = "queued"]
Download(p, v) == /\ v \in s.files \ s.downloaded[p]
                  /\ s' = [s EXCEPT !.downloaded[p] = @ \cup {v}]
\* A permanently abandoned inbound attempt exercises sequence repair.
\* Requests and hints may fail too; request retry re-arms them below.
Abandon(n, m) == /\ Queued(n, m) /\ CanFault("receive")
                 /\ s' = [s EXCEPT !.inbox[n][m] = "abandoned", !.faults = @ + 1]
Apply(p, m) ==
    /\ Queued(p, m) /\ IsData(m)
    /\ ~FileBacked(m.version) \/ m.kind = "state" \/ m.version \in s.downloaded[p]
    /\ m.kind # "state" \/ s.rows[p][Entity(m.version)].content # 0
    /\ s' = [s EXCEPT !.rows[p][Entity(m.version)] = Merge(@, m),
              !.applied[p] = @ \cup {m.version}, !.inbox[p][m] = "applied"]
ApplyFail(p, m) == /\ Queued(p, m) /\ IsData(m) /\ CanFault("apply")
                   /\ s' = [s EXCEPT !.faults = @ + 1]
Record(p, m) ==
    /\ IsData(m)
    /\ s.inbox[p][m] = "applied" \/ (~ReceiptAfterApply /\ Queued(p, m))
    /\ s' = [s EXCEPT !.received[p] = @ \cup (Carries(m) \ s.burned[p]),
              !.head[p] = Observe(@, Carries(m)),
              !.inbox[p][m] = "done"]
\* A failed sequence write leaves delivery retryable, including at the tail.
\* RetryReceipts=FALSE reproduces the old swallowed-error counterexample.
RecordFail(p, m) == /\ IsData(m) /\ s.inbox[p][m] = "applied"
                    /\ CanFault("receipt")
                    /\ s' = [s EXCEPT !.inbox[p][m] = IF RetryReceipts THEN "queued" ELSE "done",
                                      !.faults = @ + 1]
ReceiveBurn(p, m) ==
    /\ Queued(p, m) /\ m.kind = "burn"
    /\ s' = [s EXCEPT !.burned[p] = IF m.counter \in s.received[p] THEN @ ELSE @ \cup {m.counter},
                        !.inbox[p][m] = "done"]
ReceiveHint(p, m) ==
    /\ Queued(p, m) /\ m.kind = "hint"
    /\ s' = [s EXCEPT !.hints[p] = @ \cup {m.counter}, !.inbox[p][m] = "done"]
VerifyHint(p, c) ==
    /\ c \in s.hints[p] \ Resolved(p)
    /\ ~VerifyHints \/ (s.rows[p][Entity(c)].version # 0 /\ Covers(s.rows[p][Entity(c)].version, c))
    /\ s' = [s EXCEPT !.received[p] = @ \cup {c}]

\* A request itself goes through the peer outbox and the origin's inbox.
QueueRequest(p, c) ==
    /\ c \in Known(p) \ Resolved(p)
    /\ s.out[Request(p, c)] = "absent"
    /\ s' = Enqueue(s, Request(p, c))
Answer(p, c) ==
    /\ Queued(Origin(c), Request(p, c)) /\ ~Active(c)
    /\ LET payload == IF SourceCovers(c) THEN Resend(c) ELSE Burn(c)
       IN s' = [Enqueue(s, payload) EXCEPT !.inbox[Origin(c)][Request(p, c)] = "applied"]
AnswerHint(p, c) ==
    /\ s.inbox[Origin(c)][Request(p, c)] = "applied"
    /\ LET queued == IF SourceCovers(c) THEN Enqueue(s, Hint(p, c)) ELSE s
       IN s' = [queued EXCEPT !.inbox[Origin(c)][Request(p, c)] = "done"]
\* Abstract the request-count/backoff scheduler: while a visible gap is
\* unresolved, another request may redeliver a previously abandoned payload.
\* It MUST still traverse source apply, outbox send, peer apply and hint proof.
RetryRequest(p, c) ==
    /\ c \in Known(p) \ Resolved(p)
    /\ s.out[Request(p, c)] = "sent"
    /\ s.inbox[Origin(c)][Request(p, c)] \in {"done", "abandoned"}
    /\ s' = Enqueue(s, Request(p, c))

Crash(n) ==
    /\ s.crashes < MaxCrashes
    /\ s' = [s EXCEPT !.crashes = @ + 1,
              !.next = IF n # Origin(s.next) \/ s.phase = "idle" THEN @ ELSE @ + 1,
              !.phase = IF n = Origin(s.next) THEN "idle" ELSE @,
              !.out = [m \in Messages |-> IF m.sender = n /\ s.out[m] \in {"claimed", "transmitted"}
                                          THEN "pending" ELSE s.out[m]],
              !.announced = [p \in Peers |-> IF p = n
                  THEN [o \in Origins |-> 0] ELSE s.announced[p]],
              !.inbox[n] = [m \in Messages |->
                  IF s.inbox[n][m] = "applied" THEN "queued" ELSE s.inbox[n][m]]]


\* Periodic recovery announces a durable settled own head. Announcing only
\* after finite writes quiesce is sufficient for the eventuality claim and
\* bounds redundant intermediate announcements. It is never a receipt.
\* The runtime expires observations; this abstraction assumes an eventually
\* available origin and a repair pass within a fresh announcement window.
QueueHead(c) ==
    /\ AnnounceHeads
    /\ s.next > MaxCounter /\ s.phase = "idle"
    /\ s.own[c] \in {"bound", "burned"}
    /\ ~\E other \in Counters : Origin(other) = Origin(c) /\ Counter(other) > Counter(c)
    /\ s.out[Head(c)] \in {"absent", "sent"}
    /\ s' = Enqueue(s, Head(c))
ReceiveHead(p, m) ==
    /\ Queued(p, m) /\ m.kind = "head"
    /\ s' = [s EXCEPT !.announced[p] = Observe(@, {m.counter}),
                        !.inbox[p][m] = "done"]

Next == Reserve \/ Commit \/ Abort \/ Stage \/ FailStage \/ Bind
        \/ (\E n \in Nodes : Crash(n))
        \/ (\E o \in Origins, e \in Entities : Refresh(o, e))
        \/ (\E c \in Counters : RecoverStage(c) \/ RecoverBind(c)
                                \/ BurnStage(c) \/ FailBurnStage(c) \/ BurnBind(c) \/ QueueHead(c))
        \/ (\E m \in Messages : Claim(m) \/ Upload(m) \/ Send(m)
                                 \/ MarkSent(m) \/ SendFail(m))
        \/ (\E n \in Nodes, m \in Messages : Deliver(n, m) \/ Abandon(n, m))
        \/ (\E p \in Peers, m \in Messages : Apply(p, m) \/ ApplyFail(p, m)
                        \/ Record(p, m) \/ RecordFail(p, m)
                        \/ ReceiveBurn(p, m) \/ ReceiveHint(p, m) \/ ReceiveHead(p, m))
        \/ (\E p \in Peers, c \in Counters : Download(p, c) \/ VerifyHint(p, c)
                    \/ QueueRequest(p, c) \/ Answer(p, c) \/ AnswerHint(p, c)
                    \/ RetryRequest(p, c))

Spec == Init /\ [][Next]_vars
        /\ WF_vars(Reserve) /\ WF_vars(Commit) /\ WF_vars(Abort)
        /\ WF_vars(Stage) /\ WF_vars(Bind)
        /\ (\A c \in Counters : WF_vars(RecoverStage(c)) /\ WF_vars(RecoverBind(c))
                         /\ WF_vars(BurnStage(c)) /\ WF_vars(BurnBind(c)) /\ WF_vars(QueueHead(c)))
        /\ (\A o \in Origins, e \in Entities : WF_vars(Refresh(o, e)))
        /\ (\A m \in Messages : WF_vars(Claim(m)) /\ WF_vars(Upload(m))
                          /\ WF_vars(Send(m)) /\ WF_vars(MarkSent(m)))
        /\ (\A n \in Nodes, m \in Messages : WF_vars(Deliver(n, m)))
        /\ (\A p \in Peers, m \in Messages : WF_vars(Apply(p, m)) /\ WF_vars(Record(p, m))
                         /\ WF_vars(ReceiveBurn(p, m)) /\ WF_vars(ReceiveHint(p, m)) /\ WF_vars(ReceiveHead(p, m)))
        /\ (\A p \in Peers, c \in Counters : WF_vars(Download(p, c))
                  /\ WF_vars(VerifyHint(p, c)) /\ WF_vars(QueueRequest(p, c))
                  /\ WF_vars(Answer(p, c)) /\ WF_vars(AnswerHint(p, c))
                  /\ WF_vars(RetryRequest(p, c)))

TypeOK == /\ s.next \in 1..(MaxCounter + 1)
          /\ s.phase \in {"idle", "reserved", "committed", "staged"}
          /\ s.own \in [Counters -> OwnStates]
          /\ s.committed \subseteq Counters /\ s.staged \subseteq Counters
          /\ s.again \subseteq Messages
          /\ s.received \in [Peers -> SUBSET Counters]
          /\ s.burned \in [Peers -> SUBSET Counters]
          /\ s.applied \in [Peers -> SUBSET Counters]
          /\ s.hints \in [Peers -> SUBSET Counters]
          /\ s.head \in [Peers -> [Origins -> 0..MaxCounter]]
          /\ s.announced \in [Peers -> [Origins -> 0..MaxCounter]]
          /\ s.downloaded \in [Peers -> SUBSET Counters]
          /\ s.rows \in [Peers -> [Entities ->
                 [version : 0..MaxCounter, content : 0..MaxCounter, conflict : 0..MaxCounter, marked : BOOLEAN]]]
          /\ s.source \in [Origins -> [Entities -> 0..MaxCounter]]
          /\ s.descriptor \in [Origins -> [Entities -> 0..MaxCounter]]
          /\ s.out \in [Messages -> OutStates]
          /\ s.room \subseteq Messages /\ s.files \subseteq Counters
          /\ s.inbox \in [Nodes -> [Messages -> InStates]]
          /\ s.faults \in 0..MaxFaults /\ s.crashes \in 0..MaxCrashes
PayloadFamilySafe == \A p \in Peers, e \in Entities :
    \A v \in {s.rows[p][e].version, s.rows[p][e].content, s.rows[p][e].conflict} \ {0} :
        FamilyAt(v) = e[1]
NoFalseBurn == /\ \A c \in s.committed : s.own[c] # "burned"
               /\ \A p \in Peers : s.burned[p] \cap s.committed = {}
BurnHasDurableMarker == \A c \in Counters : s.own[c] = "burned" =>
                                                   s.out[Burn(c)] # "absent"
BoundHasDurablePayload == \A c \in Counters : s.own[c] = "bound" =>
    \E m \in DataMessages : s.out[m] # "absent" /\ Covers(m.version, c)
StagedHasDurablePayload == \A c \in s.staged :
    \E m \in DataMessages : s.out[m] \in {"pending", "claimed", "transmitted", "sent"}
                            /\ Covers(m.version, c)
NoFalseReceipt == \A p \in Peers : \A c \in s.received[p] :
    \E v \in s.applied[p] : Covers(v, c)
CausalCoverage == \A m \in s.room : IsData(m) =>
    \A c \in Carries(m) : Covers(m.version, c)
NoContentlessState == \A p \in Peers, e \in Entities :
    s.rows[p][e].marked => s.rows[p][e].content # 0
Represents(p, c) ==
    IF FamilyAt(c) = "journal"
    THEN LET row == s.rows[p][Entity(c)] IN
         (row.version # 0 /\ Covers(row.version, c))
         \/ (row.conflict # 0 /\ Covers(row.conflict, c))
    ELSE /\ s.rows[p][Entity(c)].content >= Content(c)
         /\ Marked(c) => s.rows[p][Entity(c)].marked
AcknowledgedPayload == \A p \in Peers, c \in s.committed :
    c \in s.received[p] => Represents(p, c)
PayloadView(p, e) == IF e[1] = "journal"
    THEN {s.rows[p][e].version, s.rows[p][e].conflict} \ {0}
    ELSE {s.rows[p][e].content}
SettledPeersAgree == (s.next > MaxCounter /\
    (\A p \in Peers : s.committed \subseteq s.received[p])) =>
    (\A a, b \in Peers, e \in Entities : PayloadView(a,e) = PayloadView(b,e))
CommittedReachesPeer == \A p \in Peers, c \in Counters :
    c \in s.committed ~> Represents(p, c)
VisiblePayloadsConverge == \A p \in Peers :
    AllKnown(p) ~> (\A c \in s.committed : Represents(p, c))
VisibleGapHeals == \A p \in Peers, c \in Counters :
    Observed(p, c) ~> c \in Resolved(p)
CommittedReachesRoom == \A c \in Counters : c \in s.committed ~>
    (\E m \in s.room : IsData(m) /\ Covers(m.version, c))
BurnReachesPeer == \A p \in Peers, c \in Counters :
    s.own[c] = "burned" ~> c \in Resolved(p)
=============================================================================
