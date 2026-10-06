------------------------ MODULE SpeechDictionarySync ------------------------
(***************************************************************************)
(* The speech dictionary across devices: SpeechDictionaryRepository, the  *)
(* migration out of the categories' legacy `speechDictionary` lists, and  *)
(* the receive gate in JournalDb.upsertEntityDefinition.                  *)
(*                                                                         *)
(* One term, two categories. A term is one entry: none, live with the set *)
(* of categories it is limited to (empty for every category) or deleted,  *)
(* with its stamp (`updatedAt`) and its writer (`c`, standing with the    *)
(* state and set for the canonical JSON the gate breaks ties on; 0 for a  *)
(* migrated entry, which every device holding the same lists writes       *)
(* identically). The categories' legacy lists are read, never written:    *)
(* each device starts with the categories whose list holds the term, and  *)
(* they may differ, as they do on a device sync has not caught up.        *)
(* Migration can run at any point -- before or after the user has edited  *)
(* the term on another device, and before or after that edit arrives --   *)
(* which also covers a device installed later.                            *)
(*                                                                         *)
(*   Put / Delete   SpeechDictionaryRepository: the user's edits           *)
(*   Migrate        SpeechDictionaryMigration over the stored categories   *)
(*   Receive        SyncEventProcessor apply, through the recency gate     *)
(*   Resend         Settings > Sync > Sync Entities re-sending every entry *)
(*                                                                         *)
(* The switches are the design; FALSE is the alternative it rejects:      *)
(*   TotalOrder    equal stamps are ordered by content, not accepted       *)
(*   MinimalStamp  a migrated entry carries the lowest stamp, not the time *)
(*                 the migration ran                                       *)
(*   AbsentOnly    migration writes only a term the device holds no entry  *)
(*                 for, rather than adding its categories to one it holds  *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS Devs, Cats, LegacyAt, MaxStamp,
          PutBudget, DeleteBudget, ResendBudget,
          TotalOrder, MinimalStamp, AbsentOnly

ASSUME Cats = {1, 2}
ASSUME LegacyAt \in [Devs -> SUBSET Cats]

(* Device 2 has seen category 2's list hold the term; device 1 has not. *)
SplitLegacy == (1 :> {1} @@ 2 :> {1, 2})

(* A migrated entry's stamp. Every user write and migration run happens   *)
(* later, at a stamp chosen freely: device clocks are not synchronised.   *)
MigratedStamp == 1
Now == 2..MaxStamp

States == {"none", "live", "tomb"}
Rev == [st : States, cats : SUBSET Cats, s : 0..MaxStamp,
        c : {0} \cup Devs]
NoRev == [st |-> "none", cats |-> {}, s |-> 0, c |-> 0]

(* Canonical content order, standing for comparing canonical JSON. *)
CatsCode(S) == (IF 1 \in S THEN 1 ELSE 0) + (IF 2 \in S THEN 2 ELSE 0)
StCode(st) == IF st = "live" THEN 1 ELSE IF st = "tomb" THEN 2 ELSE 0
RevGT(a, b) ==
    \/ a.s > b.s
    \/ a.s = b.s /\ a.c > b.c
    \/ a.s = b.s /\ a.c = b.c /\ StCode(a.st) > StCode(b.st)
    \/ a.s = b.s /\ a.c = b.c /\ a.st = b.st
       /\ CatsCode(a.cats) > CatsCode(b.cats)

(* The receive gate: write the incoming copy unless the stored one is     *)
(* newer. Without TotalOrder an exact tie applies whichever arrived, as   *)
(* it still does for the other definitions.                               *)
Accept(inc, cur) ==
    \/ cur.st = "none"
    \/ IF TotalOrder THEN ~RevGT(cur, inc) ELSE ~(cur.s > inc.s)

Msgs == [r : Rev, from : Devs]

VARIABLES entry, log, delivered, userHist, puts, deletes, resends

vars == <<entry, log, delivered, userHist, puts, deletes, resends>>

Init ==
    /\ entry = [d \in Devs |-> NoRev]
    /\ log = {}
    /\ delivered = [d \in Devs |-> {}]
    /\ userHist = {}
    /\ puts = 0 /\ deletes = 0 /\ resends = 0

(* A local write goes through the same gate; a refused copy is re-stamped *)
(* just past the stored entry (PersistenceDefinitionOps._writeLocalEdit). *)
LocalRev(cur, r) ==
    IF Accept(r, cur) THEN r ELSE [r EXCEPT !.s = cur.s + 1]

Write(d, r) ==
    /\ r.s <= MaxStamp
    /\ entry' = [entry EXCEPT ![d] = r]
    /\ log' = log \cup {[r |-> r, from |-> d]}

------------------------------------------------------------------------------
(* The user's edits: limit the term to a set of categories (empty for     *)
(* every category), or delete it.                                         *)

Put(d, S) ==
    /\ puts < PutBudget
    /\ \E now \in Now :
         LET r == LocalRev(entry[d],
                           [st |-> "live", cats |-> S, s |-> now, c |-> d])
         IN /\ Write(d, r)
            /\ userHist' = userHist \cup {r}
    /\ puts' = puts + 1
    /\ UNCHANGED <<delivered, deletes, resends>>

Delete(d) ==
    /\ deletes < DeleteBudget /\ entry[d].st = "live"
    /\ \E now \in Now :
         LET r == LocalRev(entry[d],
                           [st |-> "tomb", cats |-> {}, s |-> now, c |-> d])
         IN /\ Write(d, r)
            /\ userHist' = userHist \cup {r}
    /\ deletes' = deletes + 1
    /\ UNCHANGED <<delivered, puts, resends>>

------------------------------------------------------------------------------
(* Migration: the term with every category whose legacy list holds it,   *)
(* at once. MigWrite is the entry it would write at time `now`, or NoRev. *)

MigWrite(d, now) ==
    LET cur == entry[d]
        fresh == [st |-> "live", cats |-> LegacyAt[d],
                  s |-> IF MinimalStamp THEN MigratedStamp ELSE now, c |-> 0]
    IN IF LegacyAt[d] = {} THEN NoRev
       ELSE IF cur.st = "none" THEN fresh
       \* Merging into an entry it holds: the categories it lacks, or the
       \* term over its deletion, through the local write.
       ELSE IF ~AbsentOnly /\ cur.st = "live" /\ cur.cats # {}
               /\ ~(LegacyAt[d] \subseteq cur.cats)
            THEN LocalRev(cur, [fresh EXCEPT !.cats = cur.cats \cup LegacyAt[d]])
       ELSE IF ~AbsentOnly /\ cur.st = "tomb" THEN LocalRev(cur, fresh)
       ELSE NoRev

Due(d) == \E now \in Now : MigWrite(d, now) # NoRev

Migrate(d) ==
    /\ \E now \in Now :
         LET r == MigWrite(d, now) IN
         /\ r # NoRev
         /\ Write(d, r)
    /\ UNCHANGED <<delivered, userHist, puts, deletes, resends>>

------------------------------------------------------------------------------
(* Sync *)

Receive(d) ==
    \E m \in log :
      /\ m.from # d /\ m \notin delivered[d]
      /\ delivered' = [delivered EXCEPT ![d] = @ \cup {m}]
      /\ entry' = IF Accept(m.r, entry[d])
                  THEN [entry EXCEPT ![d] = m.r] ELSE entry
      /\ UNCHANGED <<log, userHist, puts, deletes, resends>>

(* Sync Entities: the entry the device holds, tombstone included, again.  *)
(* A copy already applied arrives as a new delivery.                      *)
Resend(d) ==
    /\ resends < ResendBudget /\ entry[d].st # "none"
    /\ LET again == [r |-> entry[d], from |-> d]
       IN /\ log' = log \cup {again}
          /\ delivered' = [e \in Devs |-> delivered[e] \ {again}]
    /\ resends' = resends + 1
    /\ UNCHANGED <<entry, userHist, puts, deletes>>

Next ==
    \/ \E d \in Devs, S \in SUBSET Cats : Put(d, S)
    \/ \E d \in Devs : Delete(d) \/ Migrate(d) \/ Receive(d) \/ Resend(d)

Spec == Init /\ [][Next]_vars
        /\ \A d \in Devs : WF_vars(Receive(d)) /\ WF_vars(Migrate(d))

------------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ entry \in [Devs -> Rev]
    /\ log \subseteq Msgs
    /\ delivered \in [Devs -> SUBSET Msgs]
    /\ userHist \subseteq Rev
    /\ puts \in 0..PutBudget /\ deletes \in 0..DeleteBudget
    /\ resends \in 0..ResendBudget

(* Every message applied, and no migration left to run. *)
Quiescent ==
    /\ \A d \in Devs, m \in log : m.from = d \/ m \in delivered[d]
    /\ \A d \in Devs : ~Due(d)

TopUser == CHOOSE r \in userHist :
             \A o \in userHist : o = r \/ RevGT(r, o)

Converged == Quiescent => \A d, e \in Devs : entry[d] = entry[e]

(* The user's last edit of the term is what every device ends on: no      *)
(* migration, however late it runs, undoes it.                            *)
UserWins == Quiescent =>
    \A d \in Devs : userHist # {} => entry[d] = TopUser

(* A term some category's legacy list held stays in the dictionary, with  *)
(* one of the category sets a device migrated, until the user edits it.   *)
LegacyKept == Quiescent =>
    \A d \in Devs :
      ((\E e \in Devs : LegacyAt[e] # {}) /\ userHist = {})
        => /\ entry[d].st = "live"
           /\ \E e \in Devs : entry[d].cats = LegacyAt[e]

EventuallyConverged == <>[](\A d, e \in Devs : entry[d] = entry[e])
=============================================================================
