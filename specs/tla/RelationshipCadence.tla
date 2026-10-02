-------------------------- MODULE RelationshipCadence --------------------------
(***************************************************************************)
(* One tracked person's check-in cadence, derived on devices that sit in   *)
(* different time zones. Every device runs the same deterministic tick     *)
(* (RelationshipAgentPhaseA) over the check-ins it holds and writes the    *)
(* one register row and the per-episode escalation records; the records   *)
(* sync as agent entities and a lease elects one device to run each        *)
(* episode, which writes the briefing. The question is whether devices in  *)
(* different zones derive the same due day, arm one escalation per lapse,  *)
(* keep the register still once everything has arrived, and notice new    *)
(* evidence the way the device that wrote it does.                         *)
(*                                                                         *)
(* Time is a global hour counter `t` (UTC). A device's wall clock is       *)
(* `t + Off[r]`, its UTC offset in hours. A journal time is stored the way *)
(* Dart serializes a local DateTime: the writer's wall-clock components,   *)
(* without an offset, beside the `utcOffset` the entry was created with.   *)
(* A reader that calls `.toUtc()` on such a value parses the components in *)
(* its own zone (`c - Off[r]`); `relationshipStoredInstant` uses the stored *)
(* offset instead (`c - off`), and a calendar day is read off the          *)
(* components alone (`Day(c)`). Days change at UTC midnight (`Day(t)`), as  *)
(* `GoalWindow.dayUtc(now.toUtc())` reads them.                            *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Save      a check-in saved on a device: `dateFrom` and `updatedAt`    *)
(*             are the device's wall clock, `utcOffset` its offset         *)
(*             (MetadataService.createMetadata)                            *)
(*   Touch     RelationshipRepository.touchCheckIn: `updatedAt` moves to   *)
(*             the toucher's wall clock through                            *)
(*             MetadataService.updateMetadata, which keeps the creation    *)
(*             `utcOffset` (OffsetRefreshed = FALSE) or stamps the         *)
(*             toucher's (TRUE)                                            *)
(*   Tick      RelationshipAgentPhaseA.execute on one device, from the     *)
(*             daily cadence wake or a check-in landing: deriveCadenceFacts *)
(*             over the check-ins the device holds, _upsertRegister when   *)
(*             the row changed, then the lapse escalation on the newly-due *)
(*             edge (relationshipEscalationWake, keyed by the due day),    *)
(*             else the refresh escalation when the newest evidence is     *)
(*             newer than the briefing (relationshipReportRefreshEscalation *)
(*             Wake, keyed by the evidence's `updatedAt` components);      *)
(*             both armed only when the device holds no record of that id *)
(*             (_armEscalation)                                            *)
(*   Run       the escalation's lease elects one device                    *)
(*             (ScheduledWakeLease.tla, taken as given: each record runs   *)
(*             once); RelationshipAgentWorkflow derives again, stands down *)
(*             when the cadence is no longer due or the refresh was        *)
(*             superseded (relationshipRefreshSuperseded), else writes the *)
(*             briefing (`createdAt`: the device's wall clock, or UTC with  *)
(*             ReportStampUtc); the record is consumed                     *)
(*   Sync      everything a device is missing from one store lands at     *)
(*             once: a check-in version applied by the journal (a touch    *)
(*             succeeds the creation; concurrent touches are not           *)
(*             modelled); the register, a record and the briefing by       *)
(*             resolveAgentEntityVersions — the later `updatedAt` for the  *)
(*             register and the briefing, the later `scheduledAt` then     *)
(*             `consumed` for a record (agent_concurrent_resolver.dart),   *)
(*             rules that are joins, so the order of arrival is immaterial *)
(*   Advance   the clock, `Step` hours at a time                           *)
(*                                                                         *)
(* The design switches, TRUE in the checked-in configurations:             *)
(*   DayFromWallClock  the due day is the check-in's wall-clock calendar   *)
(*                     day plus the cadence (R-03); FALSE: the UTC day of  *)
(*                     `dateFrom.toUtc()`, the code at a0f9af57f, which    *)
(*                     reads the components in the reader's zone           *)
(*   OffsetRefreshed   updateMetadata stamps the device's own offset       *)
(*                     beside the new `updatedAt` (R-11g); FALSE: the      *)
(*                     creation offset stays, so a touch from another zone *)
(*                     names an instant hours off                          *)
(*   ReportStampUtc    the briefing's `createdAt` is written in UTC, as    *)
(*                     the nudge's is; FALSE: the writer's wall clock,     *)
(*                     which a peer in another zone reads as another       *)
(*                     instant                                             *)
(*   TrackingStart     "creation": with no check-in the cadence counts     *)
(*                     from the person's `dateFrom` (the code, ADR 0039);  *)
(*                     "mark": from `importantSince` (R-10, a product      *)
(*                     decision for the owner)                             *)
(*                                                                         *)
(* Not modelled: the lease's own races (ScheduledWakeLease.tla), lost      *)
(* deliveries and backfill, the nudges (R-08, rejected), the OS reminder   *)
(* and the card (projections of the register), a run that fails and backs *)
(* off, and the maintenance repair that resumes a backed-off retry         *)
(* (_resumeConfiguredEscalations: a successor with an earlier              *)
(* `scheduledAt`, the RankDrop residual of the sync pipeline README); the  *)
(* daily cadence wake's own local-time deadline (R-11f, abstracted into    *)
(* Tick running at any hour); DST (an offset is a constant).               *)
(***************************************************************************)
EXTENDS Integers, FiniteSets, Sequences

CONSTANTS
    N,              \* devices 1..N, at most three
    OffA, OffB, OffC, \* the devices' UTC offsets in hours, in that order
    Cadence,        \* checkInCadenceDays
    Step,           \* hours the clock advances at a time
    MaxHours,       \* the clock runs from T0 to T0 + MaxHours
    MaxCheckIns, MaxTouches, MaxTicks, MaxRuns,
    CreatedAt,      \* the person's `dateFrom`: device 1's wall clock, hours
    MarkedAt,       \* `importantSince`: device 1's wall clock, hours
    DayFromWallClock, OffsetRefreshed, ReportStampUtc, TrackingStart

ASSUME N \in 1..3
ASSUME \A b \in {DayFromWallClock, OffsetRefreshed, ReportStampUtc} :
    b \in BOOLEAN
ASSUME TrackingStart \in {"creation", "mark"}

R == 1..N
Off == <<OffA, OffB, OffC>>
\* Hours start a day in, so every wall clock stays positive.
T0 == 24
Day(h) == h \div 24
NoReg == [st |-> "none", due |-> 0, at |-> 0, n |-> 0, basis |-> <<>>]
NoRep == [c |-> 0, off |-> 0, at |-> 0, n |-> 0]

VARIABLES
    t,        \* UTC hours
    ci,       \* every check-in: [c, off, u, uoff, by, tby, v]
    held,     \* per device, per check-in: the version it holds (0: none)
    reg,      \* per device: the register row it holds
    regs,     \* every register version written
    esc,      \* per device: the escalation records it holds, by (kind, key)
    escs,     \* every record version written
    rep,      \* per device: the briefing it holds
    reps,     \* every briefing written
    ran,      \* the records a lease has elected a device to run
    w,        \* agent writes so far: the order the resolver's tiebreak reads
    touches, ticks, runs

vars == <<t, ci, held, reg, regs, esc, escs, rep, reps, ran, w, touches,
          ticks, runs>>

Kinds == {"lapse", "refresh"}

-----------------------------------------------------------------------------
(* Reading stored times on device r *)

\* `dateFrom.toUtc()` on device r: the components in the reader's zone.
ReadInstant(c, r) == c - Off[r]

\* The check-ins device r holds.
Held(r) == {i \in 1..Len(ci) : held[r][i] > 0}

\* The newest check-in by `dateFrom` components, as deriveCadenceFacts
\* picks it (`isAfter` on the parsed values; one zone per device, so the
\* components order them).
Newest(r) ==
    CHOOSE i \in Held(r) : \A j \in Held(r) : ci[j].c <= ci[i].c

\* The reference components and the offset they were written with:
\* the newest check-in, else tracking start (ADR 0039).
RefC(r) ==
    IF Held(r) # {} THEN ci[Newest(r)].c
    ELSE IF TrackingStart = "mark" THEN MarkedAt ELSE CreatedAt

\* The due day device r derives (deriveCadenceFacts).
DueDay(r) ==
    (IF DayFromWallClock THEN Day(RefC(r)) ELSE Day(ReadInstant(RefC(r), r)))
    + Cadence

\* The due day every device should derive: the writer's calendar day.
TrueDueDay(r) == Day(RefC(r)) + Cadence

Status(r) == IF Day(t) >= DueDay(r) THEN "due" ELSE "ok"

\* relationshipStoredInstant of a check-in's `updatedAt`: the stored
\* components back through the stored offset.
EvidenceInstant(i) == ci[i].u - ci[i].uoff

\* The instant the toucher meant.
TrueEvidenceInstant(i) == ci[i].u - Off[ci[i].tby]

\* The newest evidence device r holds (`lastEvidenceAt`), and its key
\* (`lastEvidenceKey`: the `updatedAt` components).
HasEvidence(r) == Held(r) # {}
NewestEvidence(r) ==
    CHOOSE i \in Held(r) :
        \A j \in Held(r) : EvidenceInstant(j) <= EvidenceInstant(i)
EvidenceKey(r) == ci[NewestEvidence(r)].u

\* The briefing's instant as device r reads it (relationshipEvidenceNewerThan
\* compares `report.createdAt` with the evidence instant).
ReportInstant(r) ==
    IF ReportStampUtc THEN rep[r].at ELSE ReadInstant(rep[r].c, r)

\* `reportStale` on device r.
Stale(r) ==
    /\ HasEvidence(r)
    /\ \/ rep[r] = NoRep
       \/ EvidenceInstant(NewestEvidence(r)) > ReportInstant(r)

\* What the truth says, over everything written: the newest evidence
\* instant against the newest briefing's instant.
AllIds == 1..Len(ci)
TruthStale ==
    /\ AllIds # {}
    /\ LET newest == CHOOSE i \in AllIds :
                        \A j \in AllIds :
                            TrueEvidenceInstant(j) <= TrueEvidenceInstant(i)
       IN \/ reps = {}
          \/ \A p \in reps : TrueEvidenceInstant(newest) > p.at

-----------------------------------------------------------------------------
(* Resolution: resolveAgentEntityVersions for the three entity kinds *)

\* The later `updatedAt`; two writes in the same hour by the order they
\* were written, which a successor of the same device dominates and a
\* canonical clock order settles between devices.
Later(a, b) == a.at > b.at \/ (a.at = b.at /\ a.n > b.n)

\* A scheduled-wake record: the later `scheduledAt`, then `consumed`. Two
\* devices arming one episode write the identical record, so nothing else
\* orders two versions of one key.
RecordWins(a, b) ==
    \/ a.sched > b.sched
    \/ a.sched = b.sched /\ a.st = "consumed" /\ b.st # "consumed"

Resolved(a, b) == IF RecordWins(b, a) THEN b ELSE a

-----------------------------------------------------------------------------
(* Init *)

Init ==
    /\ t = T0
    /\ ci = <<>>
    /\ held = [r \in R |-> <<>>]
    /\ reg = [r \in R |-> NoReg]
    /\ regs = {}
    /\ esc = [r \in R |-> {}]
    /\ escs = {}
    /\ rep = [r \in R |-> NoRep]
    /\ reps = {}
    /\ ran = {}
    /\ w = 0
    /\ touches = 0 /\ ticks = 0 /\ runs = 0

-----------------------------------------------------------------------------
(* The journal: check-ins *)

Save(r) ==
    /\ Len(ci) < MaxCheckIns
    /\ LET wall == t + Off[r]
           new == [c |-> wall, off |-> Off[r], u |-> wall, uoff |-> Off[r],
                   by |-> r, tby |-> r, v |-> 1]
       IN /\ ci' = Append(ci, new)
          /\ held' = [s \in R |-> Append(held[s], IF s = r THEN 1 ELSE 0)]
    /\ UNCHANGED <<t, reg, regs, esc, escs, rep, reps, ran, w, touches,
                   ticks, runs>>

\* A touch on a device that holds the latest version, once every device
\* does: one writer at a time.
Touch(r, i) ==
    /\ touches < MaxTouches
    /\ i \in 1..Len(ci)
    /\ \A s \in R : held[s][i] = ci[i].v
    /\ LET wall == t + Off[r]
           next == [ci[i] EXCEPT !.u = wall,
                                 !.uoff = IF OffsetRefreshed THEN Off[r] ELSE @,
                                 !.tby = r,
                                 !.v = @ + 1]
       IN /\ ci' = [ci EXCEPT ![i] = next]
          /\ held' = [held EXCEPT ![r][i] = next.v]
    /\ touches' = touches + 1
    /\ UNCHANGED <<t, reg, regs, esc, escs, rep, reps, ran, w, ticks, runs>>

\* Sync lands every check-in version device r is missing. The journal's
\* own merge rules are not in question here (JournalReplication.tla), and
\* a check-in's versions are written one at a time, so one step suffices.
SyncJournal(r) ==
    /\ \E i \in 1..Len(ci) : held[r][i] < ci[i].v
    /\ held' = [held EXCEPT ![r] = [i \in 1..Len(ci) |-> ci[i].v]]
    /\ UNCHANGED <<t, ci, reg, regs, esc, escs, rep, reps, ran, w, touches,
                   ticks, runs>>

-----------------------------------------------------------------------------
(* Phase A *)

HasRecord(r, kind, key) == \E e \in esc[r] : e.kind = kind /\ e.key = key

\* The record a tick arms: the lapse episode at the due day's UTC midnight,
\* the refresh episode at the evidence's instant (plus a settle window
\* shorter than an hour).
LapseRecord(r) ==
    [kind |-> "lapse", key |-> DueDay(r), sched |-> DueDay(r) * 24,
     st |-> "pending"]
RefreshRecord(r) ==
    [kind |-> "refresh", key |-> EvidenceKey(r),
     sched |-> EvidenceInstant(NewestEvidence(r)), st |-> "pending"]

Tick(r) ==
    /\ ticks < MaxTicks
    /\ ticks' = ticks + 1
    /\ w' = w + 1
    /\ LET row == [st |-> Status(r), due |-> DueDay(r), at |-> t, n |-> w + 1,
                   \* The check-in versions the derivation read.
                   basis |-> [i \in 1..Len(ci) |-> held[r][i]]]
           changed == reg[r].st # row.st \/ reg[r].due # row.due
           newlyDue == Status(r) = "due" /\ reg[r].st # "due"
           arm == IF newlyDue /\ ~HasRecord(r, "lapse", DueDay(r))
                  THEN {LapseRecord(r)}
                  ELSE IF ~newlyDue /\ Stale(r)
                          /\ ~HasRecord(r, "refresh", EvidenceKey(r))
                  THEN {RefreshRecord(r)}
                  ELSE {}
       IN /\ reg' = [reg EXCEPT ![r] = IF changed THEN row ELSE @]
          /\ regs' = IF changed THEN regs \cup {row} ELSE regs
          /\ esc' = [esc EXCEPT ![r] = @ \cup arm]
          /\ escs' = escs \cup arm
    /\ UNCHANGED <<t, ci, held, rep, reps, ran, touches, runs>>

-----------------------------------------------------------------------------
(* Phase B: the elected run of an escalation record *)

Run(r, e) ==
    /\ runs < MaxRuns
    /\ e \in esc[r] /\ e.st = "pending" /\ e.sched <= t
    /\ <<e.kind, e.key>> \notin ran
    /\ ran' = ran \cup {<<e.kind, e.key>>}
    /\ runs' = runs + 1
    /\ w' = w + 1
    /\ LET briefs == IF e.kind = "lapse" THEN Status(r) = "due"
                     ELSE HasEvidence(r) /\ EvidenceKey(r) = e.key
           report == [c |-> t + Off[r], off |-> Off[r], at |-> t, n |-> w + 1]
           consumed == [e EXCEPT !.st = "consumed"]
       IN /\ rep' = [rep EXCEPT ![r] = IF briefs THEN report ELSE @]
          /\ reps' = IF briefs THEN reps \cup {report} ELSE reps
          /\ esc' = [esc EXCEPT ![r] = (@ \ {e}) \cup {consumed}]
          /\ escs' = escs \cup {consumed}
    /\ UNCHANGED <<t, ci, held, reg, regs, touches, ticks>>

-----------------------------------------------------------------------------
(* Sync of the agent entities *)

\* The register version, the briefing version and the record version the
\* resolver would leave on device r once every write has reached it. Each
\* rule is a join — the later `updatedAt`, the later `scheduledAt` then
\* `consumed` — so the order of arrival does not change the outcome, and
\* sync lands everything device r is missing in one step.
LatestOf(S, held_) ==
    IF \E v \in S : Later(v, held_)
    THEN CHOOSE v \in S : \A x \in S : ~Later(x, v)
    ELSE held_
ResolvedRecords(r) ==
    {CHOOSE v \in {x \in escs \cup esc[r] : x.kind = k.kind /\ x.key = k.key} :
        \A x \in escs \cup esc[r] :
            x.kind = k.kind /\ x.key = k.key => ~RecordWins(x, v)
     : k \in {[kind |-> x.kind, key |-> x.key] : x \in escs \cup esc[r]}}

SyncAgent(r) ==
    /\ LET nreg == LatestOf(regs, reg[r])
           nrep == LatestOf(reps, rep[r])
           nesc == ResolvedRecords(r)
       IN /\ nreg # reg[r] \/ nrep # rep[r] \/ nesc # esc[r]
          /\ reg' = [reg EXCEPT ![r] = nreg]
          /\ rep' = [rep EXCEPT ![r] = nrep]
          /\ esc' = [esc EXCEPT ![r] = nesc]
    /\ UNCHANGED <<t, ci, held, regs, escs, reps, ran, w, touches, ticks, runs>>

Advance ==
    /\ t + Step <= T0 + MaxHours
    /\ t' = t + Step
    /\ UNCHANGED <<ci, held, reg, regs, esc, escs, rep, reps, ran, w, touches,
                   ticks, runs>>

Next ==
    \/ \E r \in R : Save(r) \/ Tick(r) \/ SyncJournal(r) \/ SyncAgent(r)
    \/ \E r \in R, i \in 1..Len(ci) : Touch(r, i)
    \/ \E r \in R : \E e \in esc[r] : Run(r, e)
    \/ Advance

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ t \in T0..(T0 + MaxHours)
    /\ Len(ci) <= MaxCheckIns
    /\ \A r \in R : Len(held[r]) = Len(ci)
    /\ touches <= MaxTouches /\ ticks <= MaxTicks /\ runs <= MaxRuns

\* Every device holds every check-in version, the newest register and
\* briefing, and every record version resolved.
Quiescent ==
    /\ \A r \in R, i \in 1..Len(ci) : held[r][i] = ci[i].v
    /\ \A r \in R, v \in regs : ~Later(v, reg[r])
    /\ \A r \in R, v \in reps : ~Later(v, rep[r])
    /\ \A r \in R, v \in escs :
        \E e \in esc[r] : e.kind = v.kind /\ e.key = v.key /\ ~RecordWins(v, e)

\* Two devices holding the same newest check-in (or none) derive the same
\* due day.
SameReference(r, s) ==
    (Held(r) = {} /\ Held(s) = {})
    \/ (Held(r) # {} /\ Held(s) # {} /\ Newest(r) = Newest(s))
DueDayAgreed ==
    \A r, s \in R : SameReference(r, s) => DueDay(r) = DueDay(s)

\* Every lapse escalation is keyed by a due day some check-in, or the
\* tracking start, names on the writer's calendar: one episode per lapse,
\* never one per zone.
EscalationKeyIsTheDueDay ==
    \A v \in escs : v.kind = "lapse" =>
        \/ \E i \in 1..Len(ci) : v.key = Day(ci[i].c) + Cadence
        \/ v.key = Day(IF TrackingStart = "mark" THEN MarkedAt ELSE CreatedAt)
                   + Cadence

\* Once everything has arrived, a register row derived from every check-in
\* version there is names the due day each device derives: the next tick
\* on any device writes nothing, instead of two zones rewriting the row at
\* each other.
RowCurrent(r) ==
    reg[r] # NoReg /\ reg[r].basis = [i \in 1..Len(ci) |-> ci[i].v]
RegisterStable ==
    Quiescent => \A r \in R : RowCurrent(r) => reg[r].due = DueDay(r)

\* Once everything has arrived, every device agrees with the writer about
\* whether the briefing is behind the evidence.
StalenessAgreed ==
    Quiescent => \A r \in R : Stale(r) = TruthStale

\* Once everything has arrived, evidence newer than the briefing is seen as
\* such by at least one device, which arms the refresh on its next tick.
BriefedOnNewEvidence ==
    Quiescent /\ TruthStale => \E r \in R : Stale(r)

\* Once everything has arrived, every device holds the same register, the
\* same briefing and the same records.
Converged ==
    Quiescent =>
        \A r, s \in R : reg[r] = reg[s] /\ rep[r] = rep[s] /\ esc[r] = esc[s]

\* With the cadence counted from the mark, no lapse escalation names a day
\* before one cadence after it (the first reminder "one cadence after
\* tracking starts", ADR 0039's intent).
FirstReminderAfterMark ==
    \A v \in escs : v.kind = "lapse" => v.key >= Day(MarkedAt) + Cadence
=============================================================================
