------------------------- MODULE EntryLinkIdentity -------------------------
(***************************************************************************)
(* Replicas of one journal entry link -- one (fromId, toId, type) -- whose *)
(* versions are written on any device and delivered to every replica in  *)
(* any order, any number of times: as its own `entryLink` message, as a   *)
(* backfill answer, and inside every journal-entity message, which embeds *)
(* a snapshot of the entry's links. `linked_entries` holds one row per    *)
(* (from_id, to_id, type) (a UNIQUE constraint) and one per id.           *)
(*                                                                         *)
(* ADR 0078 orders the versions of one link id by (updatedAt, canonical   *)
(* clock, content), and its writers make an edit extend the stored row's  *)
(* clock and never stamp it earlier. The question here is the one that    *)
(* order leaves open: two devices that create the same link offline, each *)
(* under its own random id. The receive refused a live row with another   *)
(* id as a duplicate, and replaced a hidden one outright. So a removal on *)
(* one device -- a tombstone of its own id -- was refused where the other *)
(* id was live, and that device's next snapshot replaced the tombstone    *)
(* with its live row: the link came back on the device that removed it.  *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Link      PersistenceLogic.createLink, ProjectRepository's link and  *)
(*             the rating link: a fresh link takes the id derived from    *)
(*             its triple (`entryLinkId`), or revives the stored row's    *)
(*             id, extending its clock (`removedVersion`)                 *)
(*   Unlink    JournalRepository.removeLink/removeTypedLink and the       *)
(*             project unlink: the stored row's next version, tombstoned, *)
(*             through `updateLink`                                        *)
(*   Deliver   JournalDb.upsertEntryLink, in one transaction               *)
(*   Read      a linked-entry card takes its copy of the link: the row it  *)
(*             renders (LinkedEntriesController, EntryDetailsWidget)       *)
(*   Edit      the card's hide or collapse toggle, a version of the link   *)
(*             with that flag changed: from the card's copy through        *)
(*             `updateLink`, or with EditOnStored applied to the stored    *)
(*             link (`JournalRepository.changeLink`)                       *)
(*                                                                         *)
(* A legacy replica runs the build before this change: it mints a random  *)
(* id for a fresh link and receives with the old duplicate rule. It is    *)
(* outside the guarantees when it writes; the checks cover the others.    *)
(*                                                                         *)
(* The two design switches are the fixes of ADR 0096; FALSE restores the  *)
(* old behaviour and its counterexample (README).                          *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    N,             \* replicas 1..N
    Legacy,        \* replicas running the build before ADR 0096
    LegacyWrites,  \* may a legacy replica write, or only receive?
    MaxWrites,     \* local writes, across all replicas
    MaxTime,       \* the wall clock runs 0..MaxTime
    Skew,          \* how far a write's updatedAt may lag the clock
    CardEdits,     \* do cards read and edit the link (Read, Edit)?
    \* Design switches: TRUE is the code after ADR 0096.
    DerivedId,         \* a fresh link takes the id derived from its triple
    TripleIsIdentity,  \* the receive orders every version of the triple
    EditOnStored       \* a card's edit is applied to the stored link and
                       \* refused when that link is removed; FALSE is the
                       \* former toggles, which wrote the card's copy

R == 1..N
ASSUME Legacy \subseteq R
ASSUME \A b \in {LegacyWrites, DerivedId, TripleIsIdentity, CardEdits,
                  EditOnStored} : b \in BOOLEAN

Modern == R \ Legacy
\* The replicas the guarantees cover: every one when legacy replicas only
\* receive, the modern ones when a legacy replica writes too.
Checked == IF LegacyWrites THEN Modern ELSE R
Writers == IF LegacyWrites THEN R ELSE Modern

\* Link ids: 0 is no row, 1..N the random id replica r mints for a fresh
\* link, and N + 1 the id derived from the triple.
Derived == N + 1

Zero == [r \in R |-> 0]
Max(a, b) == IF a > b THEN a ELSE b
CanonGt(a, b) == \E k \in R : a[k] > b[k] /\ \A j \in R : j < k => a[j] = b[j]

\* A version: its write number (standing for its serialized content), link
\* id, writer, live or tombstoned, clock, updatedAt, and -- ghosts -- the
\* write numbers its writer had received or made when it wrote it, and
\* whether it is an edit that made a removed link live again.
Absent == [n |-> 0, id |-> 0, host |-> 0, live |-> FALSE, vc |-> Zero,
           ts |-> 0, saw |-> {}, revived |-> FALSE]

\* ADR 0078's order: the later updatedAt, then the canonical clock, then
\* the content.
Greater(a, b) ==
    \/ a.ts > b.ts
    \/ a.ts = b.ts /\ CanonGt(a.vc, b.vc)
    \/ a.ts = b.ts /\ a.vc = b.vc /\ a.n > b.n

VARIABLES
    row,        \* per replica: the stored row for the triple
    sent,       \* every write ever made
    delivered,  \* per replica: the versions it has received or made
    now,        \* the wall clock
    hc,         \* per replica: the last counter VectorClockService issued
    snap        \* per replica: the copy of the link a card renders

vars == <<row, sent, delivered, now, hc, snap>>

Init ==
    /\ row = [r \in R |-> Absent]
    /\ sent = {}
    /\ delivered = [r \in R |-> {}]
    /\ now = 0
    /\ hc = [r \in R |-> 0]
    /\ snap = [r \in R |-> Absent]

\* The row replica r keeps when version i arrives while it holds l.
\* After the fix, one register per triple: the greater version stays,
\* whatever its id. Before it, and on a legacy replica: the order applied
\* only to the same id, a live row with another id refused the arrival as
\* a duplicate, and a hidden one was deleted to make room for it.
Receive(r, l, i) ==
    IF l.n = 0 THEN i
    ELSE IF TripleIsIdentity /\ r \in Modern
         THEN IF Greater(i, l) THEN i ELSE l
    ELSE IF i.id = l.id THEN IF Greater(i, l) THEN i ELSE l
    ELSE IF l.live THEN l
    ELSE i

\* The id a fresh write takes: the stored row's, which it succeeds, or for
\* a link never stored here the derived id -- or a random one, before the
\* fix and on a legacy replica.
IdFor(r) ==
    IF row[r].n # 0 THEN row[r].id
    ELSE IF DerivedId /\ r \in Modern THEN Derived
    ELSE r

Stamps == (IF now > Skew THEN now - Skew ELSE 0)..now

\* ADR 0078's writers: the clock extends the stored row's by this host's
\* next counter, and updatedAt is never older than the row's.
NewVersion(r, live, t) ==
    [n |-> Cardinality(sent) + 1, id |-> IdFor(r), host |-> r, live |-> live,
     vc |-> [row[r].vc EXCEPT ![r] = hc[r] + 1],
     ts |-> Max(t, row[r].ts), saw |-> {m.n : m \in delivered[r]},
     revived |-> FALSE]

Commit(r, v) ==
    /\ sent' = sent \cup {v}
    /\ delivered' = [delivered EXCEPT ![r] = @ \cup {v}]
    /\ row' = [row EXCEPT ![r] = v]
    /\ hc' = [hc EXCEPT ![r] = @ + 1]
    /\ UNCHANGED <<now, snap>>

\* Creating the link: none is stored here, or the stored one is removed.
Link(r) ==
    /\ r \in Writers
    /\ Cardinality(sent) < MaxWrites
    /\ ~row[r].live
    /\ \E t \in Stamps : Commit(r, NewVersion(r, TRUE, t))

\* Removing the live link.
Unlink(r) ==
    /\ r \in Writers
    /\ Cardinality(sent) < MaxWrites
    /\ row[r].live
    /\ \E t \in Stamps : Commit(r, NewVersion(r, FALSE, t))

Deliver(r) ==
    /\ \E m \in sent :
        /\ row' = [row EXCEPT ![r] = Receive(r, @, m)]
        /\ delivered' = [delivered EXCEPT ![r] = @ \cup {m}]
    /\ UNCHANGED <<sent, now, hc, snap>>

Tick ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<row, sent, delivered, hc, snap>>

\* A card renders the link as stored, live or not, and keeps that copy
\* until it renders again.
Read(r) ==
    /\ CardEdits
    /\ snap[r] # row[r]
    /\ snap' = [snap EXCEPT ![r] = row[r]]
    /\ UNCHANGED <<row, sent, delivered, now, hc>>

\* The card's hide or collapse toggle on the link it shows. Applied to the
\* stored link, it is refused once that link is removed. Written from the
\* copy, it is a live version under a clock that extends the stored row's
\* and an updatedAt no older than it -- the newer version, wherever it goes.
Edit(r) ==
    /\ CardEdits
    /\ r \in Writers
    /\ Cardinality(sent) < MaxWrites
    /\ snap[r].live
    /\ EditOnStored => row[r].live
    /\ \E t \in Stamps :
          Commit(r, [NewVersion(r, TRUE, t) EXCEPT !.revived = ~row[r].live])

Next ==
    \/ Tick
    \/ \E r \in R : Link(r) \/ Unlink(r) \/ Deliver(r) \/ Read(r) \/ Edit(r)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MaxTime
    /\ \A r \in R : /\ row[r].id \in 0..Derived
                    /\ row[r].n \in 0..MaxWrites
                    /\ delivered[r] \subseteq sent

\* Every write has reached every replica.
Quiescent == \A r \in R : sent \subseteq delivered[r]

\* Strong eventual consistency: the same writes received, the same row.
Converged == Quiescent => \A a, b \in Checked : row[a] = row[b]

\* A replica never holds a version that a write it received was made over:
\* a removal takes away every version of the link its writer had seen,
\* whatever id each carried, and a late copy of one does not bring it back.
NoLostSuccessor ==
    \A r \in Checked : \A m \in delivered[r] :
        m.host \in Checked => row[r].n \notin m.saw

\* An edit of a link's flags never brings back a removed link: only linking
\* again does.
NoRevival == \A m \in sent : ~m.revived
=============================================================================
