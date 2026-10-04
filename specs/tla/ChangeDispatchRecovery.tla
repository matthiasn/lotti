------------------------ MODULE ChangeDispatchRecovery ------------------------
(***************************************************************************)
(* Applying a confirmed change whose tool writes several rows, across a    *)
(* crash. A confirmation claims the item -- pending to confirmed, with its *)
(* decision, in one transaction -- and then dispatches the tool. A         *)
(* create-style tool writes its entity under an id derived from the        *)
(* item's effect (ADR 0075), then the rows that hang off it: the follow-up *)
(* task's link to its source task and its project, the project agent's     *)
(* task's project link, the agent assigned to the new task. The app can    *)
(* die between any two of those writes. Another device can dispatch the    *)
(* same item too, before the two have synced (ADR 0075's residual).        *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Confirm   ChangeSetConfirmationService._confirmItem: the claim, and   *)
(*             with DispatchIntent the dispatch recorded first             *)
(*             (ChangeDispatchIntents)                                     *)
(*   Step      the tool's writes, in order: FollowUpTaskHandler and        *)
(*             ProjectToolDispatcher's create_task -- the task, then its   *)
(*             link or project, then its agent                             *)
(*   Finish    the dispatch's outcome is written and its intent cleared    *)
(*   Crash     the app dies with the dispatch in flight                    *)
(*   Restart   the next start; with DispatchIntent it resumes every        *)
(*             recorded dispatch whose item is still confirmed             *)
(*             (ChangeSetConfirmationService.resumeInterrupted)            *)
(*   Remote    another device dispatches the same effect once the entity  *)
(*             has reached it                                              *)
(*                                                                         *)
(* A dispatch that finds its entity already created is what TailOnRerun   *)
(* decides: it writes the steps that are missing, or it reports success   *)
(* with nothing more done.                                                 *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    TailLen,         \* how many of the writes after the entity the tool makes
    MaxCrashes,
    MaxRemote,       \* dispatches of the same effect on another device
    TailOnRerun,     \* a dispatch finding its entity writes what is
                     \* missing; FALSE is the former `_createdBefore`, which
                     \* reported success with nothing more done
    DispatchIntent   \* a dispatch is recorded before the claim and resumed
                     \* at the next start while its item is confirmed;
                     \* FALSE is the former service, which recorded nothing

\* The writes after the entity, in order: the source link, the project
\* link, the agent.
After == SubSeq(<<"link", "project", "agent">>, 1, TailLen)
Steps == <<"create">> \o After
StepSet == {Steps[i] : i \in 1..Len(Steps)}

VARIABLES
    status,    \* the item: "pending" or "confirmed"
    done,      \* the writes that have landed
    created,   \* ghost: how many times the entity was created
    pc,        \* the local dispatch: 0 none, k the next step to write
    intent,    \* a dispatch recorded and not yet finished
    up,        \* the app runs
    crashes,
    remote

vars == <<status, done, created, pc, intent, up, crashes, remote>>

Init ==
    /\ status = "pending"
    /\ done = {}
    /\ created = 0
    /\ pc = 0
    /\ intent = FALSE
    /\ up = TRUE
    /\ crashes = 0
    /\ remote = 0

\* Where a dispatch starts: at the entity, or -- the entity already there --
\* at the first missing write after it, or nowhere.
Begin ==
    IF "create" \notin done THEN 1
    ELSE IF TailOnRerun
         THEN IF \E i \in 2..Len(Steps) : Steps[i] \notin done
              THEN CHOOSE i \in 2..Len(Steps) :
                     Steps[i] \notin done
                     /\ \A j \in 2..(i - 1) : Steps[j] \in done
              ELSE Len(Steps) + 1
         ELSE Len(Steps) + 1

Confirm ==
    /\ up
    /\ pc = 0
    /\ status = "pending"
    /\ status' = "confirmed"
    /\ intent' = DispatchIntent
    /\ pc' = Begin
    /\ UNCHANGED <<done, created, up, crashes, remote>>

\* One write of the tool. Every write is idempotent: the entity's id is
\* derived, a link's id is derived from its triple, the project link and
\* the agent check for an existing one.
Step ==
    /\ up
    /\ pc \in 1..Len(Steps)
    /\ LET s == Steps[pc] IN
       /\ done' = done \cup {s}
       /\ created' = IF s = "create" /\ s \notin done THEN created + 1
                     ELSE created
    /\ pc' = pc + 1
    /\ UNCHANGED <<status, intent, up, crashes, remote>>

\* The tool returned: the outcome is written and the intent dropped.
Finish ==
    /\ up
    /\ pc = Len(Steps) + 1
    /\ pc' = 0
    /\ intent' = FALSE
    /\ UNCHANGED <<status, done, created, up, crashes, remote>>

Crash ==
    /\ up
    /\ crashes < MaxCrashes
    /\ pc # 0
    /\ up' = FALSE
    /\ pc' = 0
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<status, done, created, intent, remote>>

\* The next start resumes a recorded dispatch of a confirmed item, and drops
\* one whose item is no longer confirmed (the claim never landed).
Restart ==
    /\ ~up
    /\ up' = TRUE
    /\ IF intent /\ status = "confirmed"
       THEN /\ pc' = Begin
            /\ UNCHANGED intent
       ELSE /\ pc' = 0
            /\ intent' = FALSE
    /\ UNCHANGED <<status, done, created, crashes, remote>>

\* Another device dispatches the same effect, once the entity has reached
\* it: by TailOnRerun it writes what is missing (its writes arrive here),
\* or nothing.
Remote ==
    /\ remote < MaxRemote
    /\ "create" \in done
    /\ remote' = remote + 1
    /\ done' = IF TailOnRerun THEN StepSet ELSE done
    /\ UNCHANGED <<status, created, pc, intent, up, crashes>>

Next == Confirm \/ Step \/ Finish \/ Crash \/ Restart \/ Remote

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
TypeOK ==
    /\ status \in {"pending", "confirmed"}
    /\ done \subseteq StepSet
    /\ pc \in 0..(Len(Steps) + 1)
    /\ intent \in BOOLEAN
    /\ crashes \in 0..MaxCrashes

Quiet == up /\ pc = 0 /\ ~intent

\* Once nothing is in flight, an item shown confirmed has its whole effect:
\* the task with its link, its project and its agent.
ConfirmedMeansComplete ==
    (Quiet /\ status = "confirmed") => done = StepSet

\* However often the effect is dispatched, its entity is created once.
AtMostOnceCreate == created <= 1
=============================================================================
