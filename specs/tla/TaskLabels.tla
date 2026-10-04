------------------------------ MODULE TaskLabels ------------------------------
(***************************************************************************)
(* A task's labels, set by the user's label picker and by the task agent.  *)
(* The task holds its labels and a suppressed set (aiSuppressedLabelIds):  *)
(* a label the user takes off is suppressed, so the agent does not put it  *)
(* back; one the user adds is unsuppressed.                                *)
(*                                                                         *)
(* Both writers decide on a read and write later. The picker shows the     *)
(* labels it read when it opened, and commits when the user closes it. The *)
(* agent's assignment reads the suppressed set, validates its proposal     *)
(* against it, and then adds what is left. Every write is built on the     *)
(* stored task (ADR 0083); what this spec checks is what each write takes  *)
(* from its earlier read.                                                  *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Open        the picker reads the task's labels (label selection      *)
(*               modal)                                                    *)
(*   Commit(c)   the user closes it with the labels c chosen               *)
(*               (LabelsRepository.updateLabels; formerly setLabels)       *)
(*   AgentRead   the assignment reads the suppressed set and picks a      *)
(*               label (LabelAssignmentProcessor.processAssignment)        *)
(*   AgentWrite  it adds the label (LabelsRepository.assignLabels;         *)
(*               formerly addLabels)                                       *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Labels,
    MaxCommits,
    MaxAgentOps,
    PickerDelta,        \* the picker writes what the user added and
                        \* removed, applied to the stored labels; FALSE is
                        \* the former setLabels, which wrote the whole set
                        \* the user chose, diffed against the stored one
    SuppressionAtWrite  \* the agent's add skips a label suppressed on the
                        \* stored task, in the write, and leaves the
                        \* suppressed set alone; FALSE is the former path,
                        \* the manual add, which checked nothing and
                        \* unsuppressed what it added

VARIABLES
    labels,      \* the task's labels, as stored
    supp,        \* the task's suppressed labels, as stored
    seen,        \* the labels the open picker read; {} with none open
    open,        \* a picker is open
    commits,
    agentPc,     \* "idle", or the label the agent read as allowed
    agentOps,
    removedByUser, \* ghost: labels the user took off and has not put back
    silent       \* ghost: a commit removed a label the picker never showed

vars == <<labels, supp, seen, open, commits, agentPc, agentOps,
          removedByUser, silent>>

Init ==
    /\ labels = {}
    /\ supp = {}
    /\ seen = {}
    /\ open = FALSE
    /\ commits = 0
    /\ agentPc = "idle"
    /\ agentOps = 0
    /\ removedByUser = {}
    /\ silent = FALSE

Open ==
    /\ ~open
    /\ commits < MaxCommits
    /\ open' = TRUE
    /\ seen' = labels
    /\ UNCHANGED <<labels, supp, commits, agentPc, agentOps, removedByUser,
                   silent>>

\* The user closes the picker with the labels `chosen`: they added
\* chosen \ seen and removed seen \ chosen.
Commit(chosen) ==
    /\ open
    /\ LET added == chosen \ seen
           removed == seen \ chosen
           next == IF PickerDelta THEN (labels \ removed) \cup added
                   ELSE chosen
           \* What the write takes off and puts on, against the stored set.
           off == labels \ next
           on == next \ labels
       IN /\ labels' = next
          /\ supp' = (supp \cup off) \ on
          /\ silent' = (silent \/ off \ seen # {})
          /\ removedByUser' = (removedByUser \cup removed) \ added
    /\ open' = FALSE
    /\ seen' = {}
    /\ commits' = commits + 1
    /\ UNCHANGED <<agentPc, agentOps>>

\* The assignment reads the suppressed set and proposes a label that is
\* neither on the task nor suppressed.
AgentRead ==
    /\ agentPc = "idle"
    /\ agentOps < MaxAgentOps
    /\ \E l \in Labels \ (labels \cup supp) : agentPc' = l
    /\ agentOps' = agentOps + 1
    /\ UNCHANGED <<labels, supp, seen, open, commits, removedByUser, silent>>

AgentWrite ==
    /\ agentPc # "idle"
    /\ LET l == agentPc IN
         IF SuppressionAtWrite
         THEN /\ labels' = IF l \in supp THEN labels ELSE labels \cup {l}
              /\ UNCHANGED supp
         ELSE /\ labels' = labels \cup {l}
              /\ supp' = supp \ {l}
    /\ agentPc' = "idle"
    /\ UNCHANGED <<seen, open, commits, agentOps, removedByUser, silent>>

Next ==
    \/ Open
    \/ \E c \in SUBSET Labels : Commit(c)
    \/ AgentRead
    \/ AgentWrite

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
TypeOK ==
    /\ labels \subseteq Labels
    /\ supp \subseteq Labels
    /\ seen \subseteq Labels
    /\ agentPc \in Labels \cup {"idle"}
    /\ removedByUser \subseteq Labels

\* A label the user took off stays off until the user puts it back: the
\* agent does not bring it back.
RemoveWins == removedByUser \cap labels = {}

\* A label leaves the task only by the user's choice of one the picker
\* showed: a label another writer added while the picker was open is kept,
\* and not suppressed as if the user had rejected it.
NoSilentRemoval == ~silent
=============================================================================
