---------------------- MODULE OwnCounterSettlement ----------------------
(***************************************************************************)
(* Refines the atomic Settle/Respond and MigrateFallback steps in           *)
(* SyncSequence.tla at the awaits that matter to own-counter recovery.      *)
(* One inactive reservation (counter 3) names one payload, in either the   *)
(* sequence log or SettingsDb. No live write can still commit counter 3    *)
(* once settlement reads begin. Payloads are not purged in this model.     *)
(*                                                                         *)
(* MigrationInsert/Remove: VectorClockService.migrateUnrecordedReservations *)
(* ReadRow/Fallback/Recheck, Decide, Bind:                                  *)
(*   BackfillResponseHandler._settleOwnCounter                             *)
(* BatchAnswer: an earlier _answerFromEntry for counter 2 in the batch.     *)
(*   enqueueMessage may swallow an outbox failure, yet sentPayloads is set. *)
(* AdvancePayload: version 3 commits after that answer, before settlement. *)
(* Enqueue: _answerFromEntry with a fresh set and durable: true.            *)
(*   A thrown enqueue leaves the reservation available to a later retry.  *)
(*                                                                         *)
(* The switches are mutation points: disabling one reproduces its defect. *)
(* A stale journal payload models an enqueue that queued an older copy   *)
(* than the stored row, as the removed JSON sidecar could (ADR 0087).    *)
(* This safety model excludes peers, retries, crashes, payload deletion   *)
(* and store wiring;                                                       *)
(* SyncSequence.tla covers the wider protocol at a coarser granularity.    *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS RecheckSequence, RequireDurableEnqueue, RequireFreshDescriptor
ASSUME RecheckSequence \in BOOLEAN /\ RequireDurableEnqueue \in BOOLEAN
       /\ RequireFreshDescriptor \in BOOLEAN

Rows == {"none", "reserved", "received", "burned"}
Steps == {"batch", "row", "fallback", "recheck", "decide", "enqueue",
          "bind", "done"}

VARIABLES row, fallback, payloadVersion, queuedVersion, batchAttempted,
          pc, rowSeen, fallbackSeen, burnSent
vars == <<row, fallback, payloadVersion, queuedVersion, batchAttempted,
          pc, rowSeen, fallbackSeen, burnSent>>

Init ==
    /\ row \in {"none", "reserved"}
    /\ fallback = (row = "none")
    /\ payloadVersion \in {2, 3}
    /\ queuedVersion = 0
    /\ batchAttempted = FALSE
    /\ pc = "batch"
    /\ rowSeen = "none"
    /\ fallbackSeen = FALSE
    /\ burnSent = FALSE

\* These are separate durable writes, in different databases, in this order.
MigrationInsert ==
    /\ fallback /\ row = "none"
    /\ row' = "reserved"
    /\ UNCHANGED <<fallback, payloadVersion, queuedVersion, batchAttempted,
                    pc, rowSeen, fallbackSeen, burnSent>>

MigrationRemove ==
    /\ fallback /\ row # "none"
    /\ fallback' = FALSE
    /\ UNCHANGED <<row, payloadVersion, queuedVersion, batchAttempted,
                    pc, rowSeen, fallbackSeen, burnSent>>

\* Either no earlier answer, or an attempt that succeeds or silently fails.
BatchAnswer ==
    /\ pc = "batch"
    /\ batchAttempted' \in BOOLEAN
    /\ queuedVersion' \in
        IF batchAttempted' THEN {0, payloadVersion} ELSE {0}
    /\ pc' = "row"
    /\ UNCHANGED <<row, fallback, payloadVersion, rowSeen, fallbackSeen,
                    burnSent>>

AdvancePayload ==
    /\ pc = "row" /\ payloadVersion = 2
    /\ payloadVersion' = 3
    /\ UNCHANGED <<row, fallback, queuedVersion, batchAttempted,
                    pc, rowSeen, fallbackSeen, burnSent>>

ReadRow ==
    /\ pc = "row"
    /\ rowSeen' = row
    /\ pc' = IF row = "none" THEN "fallback" ELSE "decide"
    /\ UNCHANGED <<row, fallback, payloadVersion, queuedVersion,
                    batchAttempted, fallbackSeen, burnSent>>

ReadFallback ==
    /\ pc = "fallback"
    /\ fallbackSeen' = fallback
    /\ pc' = IF ~fallback /\ RecheckSequence THEN "recheck" ELSE "decide"
    /\ UNCHANGED <<row, fallback, payloadVersion, queuedVersion,
                    batchAttempted, rowSeen, burnSent>>

Recheck ==
    /\ pc = "recheck"
    /\ rowSeen' = row
    /\ pc' = "decide"
    /\ UNCHANGED <<row, fallback, payloadVersion, queuedVersion,
                    batchAttempted, fallbackSeen, burnSent>>

HasIntent == rowSeen = "reserved" \/ fallbackSeen

Decide ==
    /\ pc = "decide"
    /\ IF rowSeen \in {"received", "burned"}
       THEN /\ pc' = "done"
            /\ UNCHANGED <<row, burnSent>>
       ELSE IF HasIntent /\ payloadVersion = 3
            THEN /\ pc' = "enqueue"
                 /\ UNCHANGED <<row, burnSent>>
            ELSE /\ pc' = "done"
                 /\ row' = "burned"
                 /\ burnSent' = TRUE
    /\ UNCHANGED <<fallback, payloadVersion, queuedVersion, batchAttempted,
                    rowSeen, fallbackSeen>>

Enqueue ==
    /\ pc = "enqueue"
    /\ IF batchAttempted /\ ~RequireDurableEnqueue
       THEN /\ pc' = "bind"
            /\ UNCHANGED queuedVersion
       ELSE \/ /\ pc' = "bind"
               /\ queuedVersion' = payloadVersion
            \/ /\ pc' = "done" \* Enqueue throws: leave the row retryable.
               /\ UNCHANGED queuedVersion
            \/ /\ ~RequireFreshDescriptor
               /\ pc' = "bind"
               /\ queuedVersion' = 2 \* Queues an older copy than the row.
    /\ UNCHANGED <<row, fallback, payloadVersion, batchAttempted,
                    rowSeen, fallbackSeen, burnSent>>

Bind ==
    /\ pc = "bind"
    /\ row' = IF row \in {"none", "reserved"} THEN "received" ELSE row
    /\ pc' = "done"
    /\ UNCHANGED <<fallback, payloadVersion, queuedVersion, batchAttempted,
                    rowSeen, fallbackSeen, burnSent>>

Next == MigrationInsert \/ MigrationRemove \/ BatchAnswer \/ AdvancePayload
        \/ ReadRow \/ ReadFallback \/ Recheck \/ Decide \/ Enqueue \/ Bind

TypeOK ==
    /\ row \in Rows /\ rowSeen \in Rows /\ pc \in Steps
    /\ fallback \in BOOLEAN /\ fallbackSeen \in BOOLEAN
    /\ batchAttempted \in BOOLEAN /\ burnSent \in BOOLEAN
    /\ payloadVersion \in {2, 3} /\ queuedVersion \in {0, 2, 3}

NoFalseBurn == payloadVersion = 3 => ~burnSent /\ row # "burned"
BoundHasQueuedPayload == row = "received" => queuedVersion >= 3

Spec == Init /\ [][Next]_vars
=============================================================================
