--------------------------- MODULE TaskCategoryMove ---------------------------
(***************************************************************************)
(* Moving a task to another category, across a crash. The category is on  *)
(* every row: the task, the entries linked from it (timers, audio,         *)
(* images, linked tasks), its checklists and their items. A task's project *)
(* must be in its category (`ProjectRepository.linkTaskToProject` refuses  *)
(* a cross-category link). A move is several writes, in this order: the   *)
(* task, each linked entry, each checklist with its items, and last the    *)
(* sweep that unlinks a project left in the old category. The app can die *)
(* between any two of them.                                                *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Move     EntryCategoryMove.move: with MoveIntent the move is recorded *)
(*            first (CategoryMoveIntents)                                  *)
(*   Step     one write of the cascade, in order                          *)
(*   Finish   the cascade is done and its record cleared                   *)
(*   Crash    the app dies with a move in flight                           *)
(*   Restart  the next start; with MoveIntent it replays a recorded move   *)
(*            whose task holds the recorded category, from the step after *)
(*            the task's write, and drops one whose task does not          *)
(*            (EntryCategoryMove.replay)                                   *)
(*                                                                         *)
(* One linked entry and one checklist stand for any number: each is one    *)
(* write of the same kind, and the cascade's writes are idempotent.        *)
(***************************************************************************)
EXTENDS Naturals, Sequences

CONSTANTS
    Cats,            \* the categories a task can be moved to
    ProjectCat,      \* the category of the task's project
    MaxCrashes,
    MoveIntent,      \* a move is recorded before its first write and
                     \* replayed at the next start; FALSE is the former
                     \* EntryController.updateCategoryId, which recorded
                     \* nothing
    ChecklistsFollow \* a task's checklists and their items move with it;
                     \* FALSE is the former cascade, which moved only the
                     \* entries linked from the task

Ents == {"task", "entry", "checklist"}
Steps == <<"task", "entry", "checklist", "unlink">>

VARIABLES
    cat,       \* each row's category
    linked,    \* the task is in its project
    target,    \* the category the move in flight writes
    pc,        \* 0 no move in flight, k the next step to write
    intent,    \* the recorded move: its category, or "none"
    up,
    crashes

vars == <<cat, linked, target, pc, intent, up, crashes>>

Init ==
    /\ cat = [e \in Ents |-> ProjectCat]
    /\ linked = TRUE
    /\ target = "none"
    /\ pc = 0
    /\ intent = "none"
    /\ up = TRUE
    /\ crashes = 0

Move(c) ==
    /\ up
    /\ pc = 0
    /\ c # cat["task"]
    /\ target' = c
    /\ intent' = IF MoveIntent THEN c ELSE "none"
    /\ pc' = 1
    /\ UNCHANGED <<cat, linked, up, crashes>>

Step ==
    /\ up
    /\ pc \in 1..Len(Steps)
    /\ LET s == Steps[pc] IN
         CASE s = "unlink" ->
                /\ linked' = (linked /\ cat["task"] = ProjectCat)
                /\ UNCHANGED cat
           [] s = "checklist" /\ ~ChecklistsFollow ->
                UNCHANGED <<cat, linked>>
           [] OTHER ->
                /\ cat' = [cat EXCEPT ![s] = target]
                /\ UNCHANGED linked
    /\ pc' = pc + 1
    /\ UNCHANGED <<target, intent, up, crashes>>

Finish ==
    /\ up
    /\ pc = Len(Steps) + 1
    /\ pc' = 0
    /\ intent' = "none"
    /\ target' = "none"
    /\ UNCHANGED <<cat, linked, up, crashes>>

Crash ==
    /\ up
    /\ pc # 0
    /\ crashes < MaxCrashes
    /\ up' = FALSE
    /\ pc' = 0
    /\ target' = "none"
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<cat, linked, intent>>

\* A recorded move is replayed only while the task holds its category: the
\* task's write landed. One whose task does not was never begun, and its
\* followers are where the task is.
Restart ==
    /\ ~up
    /\ up' = TRUE
    /\ IF intent # "none" /\ cat["task"] = intent
       THEN /\ target' = intent
            /\ pc' = 2
            /\ UNCHANGED intent
       ELSE /\ intent' = "none"
            /\ UNCHANGED <<target, pc>>
    /\ UNCHANGED <<cat, linked, crashes>>

Next == (\E c \in Cats : Move(c)) \/ Step \/ Finish \/ Crash \/ Restart

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
TypeOK ==
    /\ cat \in [Ents -> Cats \cup {ProjectCat}]
    /\ linked \in BOOLEAN
    /\ pc \in 0..(Len(Steps) + 1)
    /\ crashes \in 0..MaxCrashes

Quiet == up /\ pc = 0

\* Once no move is in flight, everything that belongs to the task is in its
\* category, and so is its project, if it is in one.
Consistent ==
    Quiet =>
        /\ \A e \in Ents : cat[e] = cat["task"]
        /\ (linked => cat["task"] = ProjectCat)
=============================================================================
