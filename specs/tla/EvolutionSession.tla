------------------------- MODULE EvolutionSession -------------------------
(***************************************************************************)
(* One evolution session (a template or soul 1-on-1) and the version it    *)
(* produces, across replicas. The session row is a synced agent entity     *)
(* (`EvolutionSessionEntity`, last-writer-wins on updatedAt); the version  *)
(* is created by the owning device, the only one holding the session's     *)
(* conversation in memory. The questions: does a session whose proposal    *)
(* was adopted end completed, naming its version, on every replica? Does   *)
(* it produce that version exactly once? Does a terminal status ever       *)
(* regress?                                                                *)
(*                                                                         *)
(* Replica 1 owns the session. What is modelled, and where it lives:       *)
(*                                                                         *)
(*   Approve     TemplateEvolutionWorkflow.approveProposal and             *)
(*               completeSoulSession (soul_evolution_workflow.dart):       *)
(*               create the version (AgentTemplateService.createVersion /  *)
(*               SoulDocumentService.createVersion, whose version rows and *)
(*               head are VersionHeads.tla), persist notes and the recap,  *)
(*               then write the session `completed` naming the version.    *)
(*               With `AtomicApprove` all of it is one transaction and an  *)
(*               approval of a session already completed returns its       *)
(*               version; without it the steps commit one by one           *)
(*               (ApproveCreate, ApproveFail, ApproveComplete) and the     *)
(*               template path's in-memory cache (`VersionCache`) is what  *)
(*               stops a retry from minting a second version               *)
(*   Abandon     abandonSession, from the chat page's close or dispose:   *)
(*               drops the in-memory session and writes `abandoned` if the *)
(*               row it read is active                                     *)
(*   Sweep       _abandonStaleActiveSessions, run by startSession and after *)
(*               an approval on any device: every session the device reads *)
(*               as active and does not hold in memory becomes `abandoned` *)
(*   Crash       the owner's process dies: the in-memory session is gone   *)
(*   Snapshot    a writer's read of the row, which a delivery can overtake *)
(*               before the write (the read and the upsert are separate)   *)
(*   Write       AgentSyncService._upsertEntityRaw with                    *)
(*               resolveLocalAgentWrite (ADR 0068), as AgentReplication.tla *)
(*   Deliver     resolveAgentEntityVersions: dominance, then the type's    *)
(*               override, then updatedAt, then the canonical clock        *)
(*                                                                         *)
(*   Receive     the same, read and written in one transaction or, as    *)
(*               before, with an await between (ReceiveRead, ReceiveWrite) *)
(*                                                                         *)
(* The three design switches are the fixes of ADR 0081; FALSE restores the *)
(* old behaviour and its counterexample (README).                          *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,                  \* replicas 1..N; replica 1 owns the session
    MaxWrites,          \* session-row writes, the creation included
    MaxTime,            \* the wall clock runs 0..MaxTime
    Skew,               \* how far a write's updatedAt may lag the clock
    Crashes,            \* may the owner's process die?
    VersionCache,       \* old design: does a retry reuse the cached version?
    \* Design switches: TRUE is the code after ADR 0081.
    CompletedOutranks,  \* a concurrent pair: completed > abandoned > active
    AtomicApprove,      \* version, notes, recap and completion commit as one
    AtomicReceive       \* the receive reads and writes the row in one transaction

ASSUME \A b \in {Crashes, VersionCache, CompletedOutranks, AtomicApprove,
                 AtomicReceive} : b \in BOOLEAN

R == 1..N
Owner == 1
Zero == [r \in R |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
Join(a, b) == [r \in R |-> Max(a[r], b[r])]
Leq(a, b) == \A r \in R : a[r] <= b[r]
CanonGt(a, b) == \E k \in R : a[k] > b[k] /\ \A j \in R : j < k => a[j] = b[j]

Statuses == {"active", "completed", "abandoned"}
Rank(st) == CASE st = "active" -> 0 [] st = "abandoned" -> 1 [] st = "completed" -> 2

\* A version of the session row: its write id, status, the version it
\* names (0: none), clock and updatedAt. Write 1 is the creation, made by
\* the owner at time 0 and already received everywhere.
Created == [id |-> 1, st |-> "active", ver |-> 0,
            vc |-> [r \in R |-> IF r = Owner THEN 1 ELSE 0], ts |-> 0]

VARIABLES
    row,        \* per replica: the persisted session row
    snap,       \* per replica: the row as a writer last read it
    sent,       \* every write ever made
    delivered,  \* per replica: the writes it has received or made
    now,        \* the wall clock
    hc,         \* per replica: the last counter VectorClockService issued
    made,       \* versions the session has created (committed)
    mem,        \* the owner still holds the session in memory
    pend,       \* old design: the version this approval created, 0 if none
    cache,      \* old design: the template path's cached version, 0 if none
    rd          \* per replica: a receive that has read the row, not written

vars == <<row, snap, sent, delivered, now, hc, made, mem, pend, cache, rd>>

NoRead == [m |-> Created, l |-> Created, on |-> FALSE]

Init ==
    /\ row = [r \in R |-> Created]
    /\ snap = [r \in R |-> Created]
    /\ sent = {Created}
    /\ delivered = [r \in R |-> {Created}]
    /\ now = 0
    /\ hc = [r \in R |-> IF r = Owner THEN 1 ELSE 0]
    /\ made = 0
    /\ mem = TRUE
    /\ pend = 0
    /\ cache = 0
    /\ rd = [r \in R |-> NoRead]

\* The concurrent winner: the override (resolveConcurrentAgentEntityOverride),
\* then updatedAt, then the canonical clock tiebreak.
Winner(l, i) ==
    IF CompletedOutranks /\ Rank(l.st) # Rank(i.st)
    THEN IF Rank(l.st) > Rank(i.st) THEN l ELSE i
    ELSE IF i.ts > l.ts THEN i
    ELSE IF l.ts > i.ts THEN l
    ELSE IF CanonGt(i.vc, l.vc) THEN i ELSE l

\* resolveAgentEntityVersions: dominance first, then the concurrent winner.
Merge(l, i) ==
    IF Leq(i.vc, l.vc) THEN l
    ELSE IF Leq(l.vc, i.vc) THEN i
    ELSE Winner(l, i)

\* The row a writer read: the persisted one, or an older read that a
\* delivery has since overtaken. A device's own write refreshes its read.
Bases(r) == {row[r], snap[r]}

\* A local write built on base B (resolveLocalAgentWrite): a base that does
\* not cover the persisted row is resolved against it as if concurrent; the
\* clock covers both; updatedAt never goes back.
NewVersion(r, B, st, ver, t) ==
    LET P == row[r]
        w == [B EXCEPT !.st = st, !.ver = ver, !.ts = t]
        fields == IF Leq(P.vc, B.vc) THEN w ELSE Winner(P, w)
    IN [id |-> Cardinality(sent) + 1, st |-> fields.st, ver |-> fields.ver,
        vc |-> [Join(B.vc, P.vc) EXCEPT ![r] = hc[r] + 1],
        ts |-> Max(fields.ts, P.ts)]

Stamps == (IF now > Skew THEN now - Skew ELSE 0)..now

Write(r, B, st, ver) ==
    /\ Cardinality(sent) < MaxWrites
    /\ \E t \in Stamps :
        LET v == NewVersion(r, B, st, ver, t)
        IN /\ sent' = sent \cup {v}
           /\ delivered' = [delivered EXCEPT ![r] = @ \cup {v}]
           /\ row' = [row EXCEPT ![r] = v]
           /\ snap' = [snap EXCEPT ![r] = v]
           /\ hc' = [hc EXCEPT ![r] = @ + 1]

Unwritten == UNCHANGED <<row, snap, sent, delivered, hc>>

Snapshot(r) ==
    /\ snap[r] # row[r]
    /\ snap' = [snap EXCEPT ![r] = row[r]]
    /\ UNCHANGED <<row, sent, delivered, now, hc, made, mem, pend, cache, rd>>

(***************************************************************************)
(* The approval, after ADR 0081: one transaction, which reads the session  *)
(* row itself. A row already completed names the version to return; a     *)
(* post-commit failure (the outbox flush throws after the commit) leaves   *)
(* the session in memory for a retry.                                      *)
(***************************************************************************)
ApproveAtomic ==
    /\ AtomicApprove
    /\ mem
    /\ IF row[Owner].st = "completed"
       THEN /\ mem' = FALSE
            /\ Unwritten
            /\ UNCHANGED made
       ELSE /\ made' = made + 1
            /\ Write(Owner, row[Owner], "completed", made + 1)
            /\ mem' \in BOOLEAN
    /\ UNCHANGED <<now, pend, cache, rd>>

(***************************************************************************)
(* The approval before ADR 0081: the version commits on its own, then     *)
(* notes and the recap (either may throw, and the approval returns null   *)
(* with the session still in memory), then the session row. Only the      *)
(* template path caches the version for a retry.                          *)
(***************************************************************************)
ApproveCreate ==
    /\ ~AtomicApprove
    /\ mem /\ pend = 0
    /\ LET v == IF VersionCache /\ cache # 0 THEN cache ELSE made + 1
       IN /\ pend' = v
          /\ made' = Max(made, v)
          /\ cache' = IF VersionCache THEN v ELSE 0
    /\ Unwritten
    /\ UNCHANGED <<now, mem, rd>>

ApproveFail ==
    /\ pend # 0
    /\ pend' = 0
    /\ Unwritten
    /\ UNCHANGED <<now, made, mem, cache, rd>>

ApproveComplete ==
    /\ pend # 0
    /\ \E B \in Bases(Owner) : Write(Owner, B, "completed", pend)
    /\ pend' = 0
    /\ mem' = FALSE
    /\ UNCHANGED <<now, made, cache, rd>>

\* The user leaves the chat: the session is dropped from memory and marked
\* abandoned if the row read is still active.
Abandon ==
    /\ mem /\ pend = 0
    /\ mem' = FALSE
    /\ \E B \in Bases(Owner) :
        IF B.st = "active"
        THEN Write(Owner, B, "abandoned", B.ver)
        ELSE Unwritten
    /\ UNCHANGED <<now, made, pend, cache, rd>>

\* Another session starts, or another one is approved, on replica r: every
\* session it reads as active and does not hold in memory is abandoned.
Sweep(r) ==
    /\ r # Owner \/ ~mem
    /\ \E B \in Bases(r) :
        /\ B.st = "active"
        /\ Write(r, B, "abandoned", B.ver)
    /\ UNCHANGED <<now, made, mem, pend, cache, rd>>

Crash ==
    /\ Crashes
    /\ mem \/ pend # 0
    /\ mem' = FALSE
    /\ pend' = 0
    /\ cache' = 0
    /\ Unwritten
    /\ UNCHANGED <<now, made, rd>>

\* After ADR 0081 the session row is read, resolved and written in one
\* transaction, as agent state and change sets are.
Deliver(r) ==
    /\ AtomicReceive
    /\ \E m \in sent \ delivered[r] :
        /\ row' = [row EXCEPT ![r] = Merge(@, m)]
        /\ delivered' = [delivered EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<snap, sent, now, hc, made, mem, pend, cache, rd>>

\* Before: _resolveIncomingAgentEntity reads the row, and the resolved row
\* is written after an await, where a local write can commit.
ReceiveRead(r) ==
    /\ ~AtomicReceive
    /\ ~rd[r].on
    /\ \E m \in sent \ delivered[r] :
        rd' = [rd EXCEPT ![r] = [m |-> m, l |-> row[r], on |-> TRUE]]
    /\ UNCHANGED <<row, snap, sent, delivered, now, hc, made, mem, pend, cache>>

ReceiveWrite(r) ==
    /\ rd[r].on
    /\ LET res == Merge(rd[r].l, rd[r].m)
       IN row' = IF res = rd[r].l THEN row ELSE [row EXCEPT ![r] = res]
    /\ delivered' = [delivered EXCEPT ![r] = @ \cup {rd[r].m}]
    /\ rd' = [rd EXCEPT ![r] = NoRead]
    /\ UNCHANGED <<snap, sent, now, hc, made, mem, pend, cache>>

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<row, snap, sent, delivered, hc, made, mem, pend, cache, rd>>

Next ==
    \/ Tick \/ ApproveAtomic \/ ApproveCreate \/ ApproveFail
    \/ ApproveComplete \/ Abandon \/ Crash
    \/ \E r \in R : \/ Snapshot(r) \/ Sweep(r) \/ Deliver(r)
                   \/ ReceiveRead(r) \/ ReceiveWrite(r)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MaxTime
    /\ \A r \in R : /\ row[r].st \in Statuses
                    /\ row[r].id \in 1..MaxWrites
                    /\ delivered[r] \subseteq sent
    /\ mem \in BOOLEAN

Quiescent == \A r \in R : delivered[r] = sent /\ ~rd[r].on

\* The owner is done with the session: nothing is in memory or in flight.
Settled == Quiescent /\ ~mem /\ pend = 0

Content(v) == [id |-> v.id, st |-> v.st, ver |-> v.ver]

\* Every replica that has received every write holds the same row.
Converged == Quiescent => \A a, b \in R : Content(row[a]) = Content(row[b])

\* A session creates at most one version.
OneVersion == made <= 1

\* A session whose version exists ends completed, naming that version,
\* everywhere: an adopted proposal is never recorded as abandoned (which
\* the feedback extraction reads as a negative signal) or left active.
AdoptionRecorded ==
    (Settled /\ made > 0) =>
        \A r \in R : row[r].st = "completed" /\ row[r].ver = made

\* A completed row names a version the session created.
CompletedNamesVersion ==
    \A r \in R : row[r].st = "completed" => row[r].ver \in 1..made

\* Terminal statuses do not regress: completed stays completed, and no
\* terminal row becomes active again.
CompletedStays ==
    [][\A r \in R : row[r].st = "completed" => row'[r].st = "completed"]_vars
NeverReactivated ==
    [][\A r \in R : row[r].st # "active" => row'[r].st # "active"]_vars
=============================================================================
