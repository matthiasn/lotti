-------------------------- MODULE ChangeSetConfirm --------------------------
(***************************************************************************)
(* Confirming one proposed change (a change-set item): the persisted item  *)
(* status, the tool dispatch that applies the change, and the callers that *)
(* may run concurrently — a double tap, a "confirm all" racing a single    *)
(* confirm, a retry after a failure.                                       *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Read          ChangeSetConfirmationService._confirmItem: freshChange- *)
(*                 Set and the `status == pending` check                   *)
(*   MarkConfirmed claimChangeSetItem: an atomic pending -> confirmed      *)
(*                 compare-and-swap                                        *)
(*   Dispatch*     the tool dispatcher; a failure reverts to pending or    *)
(*                 retracts                                                *)
(*   Hook*         _onConfirmedDecision; a throw is logged, the item stays *)
(*                 confirmed                                               *)
(*   Reject        rejectItem: claimChangeSetItem to `rejected`, with the  *)
(*                 decision in the same transaction                        *)
(*   Crash         process death between any two steps                    *)
(*                                                                         *)
(* `applied` is a ghost: how many times the change actually took effect.   *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Callers,      \* concurrent confirm attempts
    MaxAttempts,  \* bound on (re)tries per caller
    MaxCrashes,
    Faults        \* subset of FaultKinds

FaultKinds == {
    "dispatchFails",      \* the tool reports failure without an effect
    "failsAfterEffect",   \* the tool throws after its effect landed
    "hookThrows"          \* _onConfirmedDecision throws after a dispatch
}

ASSUME Faults \subseteq FaultKinds

Status == {"pending", "confirmed", "rejected", "retracted"}
Pc == {"idle", "checked", "marked", "dispatched", "done"}

VARIABLES
    status,     \* persisted item status
    applied,    \* ghost: times the change took effect
    pc,         \* per caller: progress through _confirmItem
    attempts,   \* per caller: attempts started
    crashes

vars == <<status, applied, pc, attempts, crashes>>

Init ==
    /\ status = "pending"
    /\ applied = 0
    /\ pc = [c \in Callers |-> "idle"]
    /\ attempts = [c \in Callers |-> 0]
    /\ crashes = 0

\* Start (or retry) a confirm: re-read, give up unless pending.
Read(c) ==
    /\ pc[c] \in {"idle", "done"}
    /\ attempts[c] < MaxAttempts
    /\ attempts' = [attempts EXCEPT ![c] = @ + 1]
    /\ pc' = [pc EXCEPT ![c] = IF status = "pending" THEN "checked" ELSE "done"]
    /\ UNCHANGED <<status, applied, crashes>>

\* Claim the item: one compare-and-swap from pending to confirmed. A caller
\* that lost the race — someone confirmed, retracted or reverted it since
\* its read — stops without dispatching.
MarkConfirmed(c) ==
    /\ pc[c] = "checked"
    /\ IF status = "pending"
       THEN /\ status' = "confirmed"
            /\ pc' = [pc EXCEPT ![c] = "marked"]
       ELSE /\ pc' = [pc EXCEPT ![c] = "done"]
            /\ UNCHANGED status
    /\ UNCHANGED <<applied, attempts, crashes>>

DispatchOk(c) ==
    /\ pc[c] = "marked"
    /\ applied' = applied + 1
    /\ pc' = [pc EXCEPT ![c] = "dispatched"]
    /\ UNCHANGED <<status, attempts, crashes>>

\* The dispatcher reports failure: revert to pending so the user can retry.
DispatchFails(c) ==
    /\ "dispatchFails" \in Faults
    /\ pc[c] = "marked"
    /\ status' = "pending"
    /\ pc' = [pc EXCEPT ![c] = "done"]
    /\ UNCHANGED <<applied, attempts, crashes>>

\* The tool took effect, then threw: reported as a failure, reverted.
FailsAfterEffect(c) ==
    /\ "failsAfterEffect" \in Faults
    /\ pc[c] = "marked"
    /\ applied' = applied + 1
    /\ status' = "pending"
    /\ pc' = [pc EXCEPT ![c] = "done"]
    /\ UNCHANGED <<attempts, crashes>>

HookOk(c) ==
    /\ pc[c] = "dispatched"
    /\ pc' = [pc EXCEPT ![c] = "done"]
    /\ UNCHANGED <<status, applied, attempts, crashes>>

\* _onConfirmedDecision throws after a successful dispatch. The change has
\* taken effect, so the item stays confirmed; the failure is only logged.
HookThrows(c) ==
    /\ "hookThrows" \in Faults
    /\ pc[c] = "dispatched"
    /\ pc' = [pc EXCEPT ![c] = "done"]
    /\ UNCHANGED <<status, applied, attempts, crashes>>

\* A reject is a compare-and-swap from pending too, so it can neither
\* overwrite a confirm that claimed the item nor be overwritten by one.
Reject(c) ==
    /\ pc[c] \in {"idle", "done"}
    /\ attempts[c] < MaxAttempts
    /\ status = "pending"
    /\ status' = "rejected"
    /\ attempts' = [attempts EXCEPT ![c] = @ + 1]
    /\ pc' = [pc EXCEPT ![c] = "done"]
    /\ UNCHANGED <<applied, crashes>>

\* Every in-flight confirm dies; persisted status and effects survive.
Crash ==
    /\ crashes < MaxCrashes
    /\ \E c \in Callers : pc[c] \in {"checked", "marked", "dispatched"}
    /\ pc' = [c \in Callers |-> IF pc[c] = "idle" THEN "idle" ELSE "done"]
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<status, applied, attempts>>

Next ==
    \/ \E c \in Callers :
          \/ Read(c) \/ MarkConfirmed(c)
          \/ DispatchOk(c) \/ DispatchFails(c) \/ FailsAfterEffect(c)
          \/ HookOk(c) \/ HookThrows(c) \/ Reject(c)
    \/ Crash

\* A started confirm runs to its end; nobody is forced to (re)try.
Fairness ==
    \A c \in Callers :
        /\ WF_vars(MarkConfirmed(c))
        /\ WF_vars(DispatchOk(c) \/ DispatchFails(c) \/ FailsAfterEffect(c))
        /\ WF_vars(HookOk(c) \/ HookThrows(c))

Spec == Init /\ [][Next]_vars /\ Fairness

TypeOK ==
    /\ status \in Status
    /\ applied \in Nat
    /\ pc \in [Callers -> Pc]

\* A confirmed change takes effect at most once.
AtMostOnceApply == applied <= 1

\* An item shown as rejected never took effect.
RejectedMeansNotApplied == status = "rejected" => applied = 0

\* An item shown as confirmed has taken effect, once nothing is in flight.
ConfirmedMeansApplied ==
    (status = "confirmed" /\ \A c \in Callers : pc[c] \in {"idle", "done"})
        => applied >= 1
=============================================================================
