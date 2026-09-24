--------------------------- MODULE DayProcessingJob ---------------------------
(***************************************************************************)
(* One Daily OS agent job (draftPlan or refinePlan) in the device-local    *)
(* processing outbox, executed through agent wakes (ADR 0044, ADR 0070).   *)
(* One request — one requestedAt — so every wake in the model carries the  *)
(* same processing-intent token.                                           *)
(*                                                                         *)
(* Two workers can hold claims on the job: the runtime's agent lane, and   *)
(* the lane of a runtime the provider rebuilt while an attempt of the old  *)
(* one was still awaiting its wake (DayProcessingRuntime.dispose does not  *)
(* stop an in-flight drain). A claim's lease is three minutes and is never *)
(* renewed; the wait for the wake is three minutes too, and the wake can   *)
(* sit behind single flight, or run on after the ten-minute cap aborted    *)
(* it, for much longer.                                                    *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Claim          DayProcessingOutboxRepository._claim: one UPDATE that  *)
(*                  picks a queued row, or a running row whose lease       *)
(*                  expired, and stamps a fresh claim_token                *)
(*   LeaseExpires   time passing lease_until                               *)
(*   Check          DayAgentJobExecutor.execute: the live-wake look and   *)
(*                  the artifact pre-check (after ADR 0070 it attaches to  *)
(*                  a live wake of the same request)                       *)
(*   Enqueue        after the remaining reads, the live-wake look again    *)
(*                  and enqueueWake, with nothing awaited in between       *)
(*   Record         recordRunKey — deliberately unfenced                   *)
(*   Hear           a WakeRunCompletion for the awaited run key            *)
(*   Timeout        the wakeTimeout on that wait                           *)
(*   Report         markSucceeded / markFailure through _updateClaimed:    *)
(*                  applied only while the row is running under this       *)
(*                  worker's claim_token, else ClaimRevoked                *)
(*   WakeStart ..   the wake runtime: single flight per agent, a run that  *)
(*                  commits its artifact, fails, or is aborted (and runs   *)
(*                  on, possibly committing later)                         *)
(*   Cancel,        the Activity view's cancel and retryNow                *)
(*   RetryNow                                                              *)
(*   Crash          process death: workers and wakes die (processing wakes *)
(*                  are never WakeIntentStore intents), the row survives   *)
(*                                                                         *)
(* Design switch (TRUE is the code after ADR 0070):                        *)
(*   AttachToLiveWake  an attempt that finds a wake of its request still   *)
(*                     queued or running awaits that wake instead of       *)
(*                     enqueueing another, and a wait that times out on a  *)
(*                     live wake defers without counting an attempt        *)
(*   RecheckBeforeEnqueue  the live-wake look is repeated with nothing      *)
(*                     awaited before the enqueue, so it and the enqueue   *)
(*                     are atomic                                          *)
(* Timing assumption (FALSE in the checked-in configurations):             *)
(*   ProvenanceRace    a wake may commit its artifact before the attempt   *)
(*                     that enqueued it has recorded its run key           *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Workers,
    Kind,              \* "draft" | "refine"
    MaxWakes,          \* bound on wakes enqueued for the request
    MaxAttempts,       \* DayAgentJobExecutor.maxAttempts
    MaxCrashes,
    MaxUser,           \* bound on cancel / retryNow taps
    AttachToLiveWake,
    RecheckBeforeEnqueue,
    ProvenanceRace

Wakes == 1..MaxWakes
NoWake == 0
NoClaim == 0
\* isTerminal in the Dart code; `failed` can still be retried.
Final == {"succeeded", "cancelled"}
Settled == Final \cup {"failed"}
\* Claim tokens are opaque; a fresh one only has to differ from every
\* token a worker or the row still holds.
Tokens == 1..(Cardinality(Workers) + 1)
Live == {"queued", "running", "aborted"}

VARIABLES
    status,     \* the row: "queued" | "running" | Settled
    claim,      \* claim_token of the row, or NoClaim
    leaseLive,  \* lease_until is still in the future
    attempts,
    failedOnce, \* lastFailureClass was set at least once
    runKeys,    \* run keys recorded for the request
    pc,         \* per worker: "idle" | "claimed" | "checked" | "enqueued"
                \*             | "waiting"
                \*             | "ok" | "fail" | "defer"
    tok,        \* per worker: the claim token it holds
    wk,         \* per worker: the wake it awaits
    heard,      \* per worker: "none" | "completed" | "failed"
    wake,       \* per wake: "none" | Live | "done" | "dead"
    artifact,   \* wakes whose artifact (plan / ChangeSet) committed
    sup,        \* per worker: its claim was superseded (ghost)
    nextWake,
    crashes,
    user,
    starts,     \* ghost: inferences started for the request
    wasted,     \* ghost: inferences started after its artifact existed
    stale       \* ghost: fenced writes applied under a revoked claim

vars == <<status, claim, leaseLive, attempts, failedOnce, runKeys, pc, tok,
          wk, heard, wake, artifact, sup, nextWake, crashes, user,
          starts, wasted, stale>>

jobVars == <<status, claim, leaseLive, attempts, failedOnce, runKeys>>
workerVars == <<pc, tok, wk, heard>>
wakeVars == <<wake, artifact, nextWake, starts, wasted>>

Init ==
    /\ status = "queued"
    /\ claim = NoClaim
    /\ leaseLive = FALSE
    /\ attempts = 0
    /\ failedOnce = FALSE
    /\ runKeys = {}
    /\ pc = [w \in Workers |-> "idle"]
    /\ tok = [w \in Workers |-> NoClaim]
    /\ wk = [w \in Workers |-> NoWake]
    /\ heard = [w \in Workers |-> "none"]
    /\ wake = [k \in Wakes |-> "none"]
    /\ artifact = {}
    /\ sup = [w \in Workers |-> FALSE]
    /\ nextWake = 1
    /\ crashes = 0
    /\ user = 0
    /\ starts = 0
    /\ wasted = 0
    /\ stale = 0

LiveWakes == {k \in Wakes : wake[k] \in Live}

Busy == {w \in Workers : pc[w] # "idle"}

\* A worker holding the row's current claim loses it.
Supersede(v) == sup[v] \/ (pc[v] # "idle" /\ tok[v] = claim)

\* DayAgentJobExecutor._artifactOutcome: does an artifact satisfy the job?
Satisfied(extra) ==
    LET known == runKeys \cup extra
    IN IF known # {}
       THEN artifact \cap known # {}
       ELSE IF Kind = "draft"
            \* No provenance: the plan's updatedAt against requestedAt.
            THEN artifact # {}
            \* Refine: the legacy time window only for an attempted job;
            \* a never-attempted one has no artifact by assumption.
            ELSE (attempts > 0 \/ failedOnce) /\ artifact # {}

----------------------------------------------------------------------------
(* The outbox and the executor. *)

Claim(w) ==
    /\ pc[w] = "idle"
    /\ \/ status = "queued"
       \/ status = "running" /\ ~leaseLive
    /\ \E t \in Tokens \ ({claim} \cup {tok[v] : v \in Busy}) :
          /\ claim' = t
          /\ tok' = [tok EXCEPT ![w] = t]
    /\ status' = "running"
    /\ leaseLive' = TRUE
    /\ pc' = [pc EXCEPT ![w] = "claimed"]
    /\ wk' = [wk EXCEPT ![w] = NoWake]
    /\ heard' = [heard EXCEPT ![w] = "none"]
    /\ sup' = [v \in Workers |-> IF v = w THEN FALSE ELSE Supersede(v)]
    /\ UNCHANGED <<attempts, failedOnce, runKeys, wakeVars, crashes, user,
                   stale>>

\* Three minutes pass. Only the wait for a wake takes that long: a holder
\* that is checking or reporting finishes first, so the lease lapses only
\* while its holder waits, or once it is gone.
LeaseExpires ==
    /\ status = "running" /\ leaseLive
    /\ \A w \in Busy : tok[w] = claim => pc[w] = "waiting"
    /\ leaseLive' = FALSE
    /\ UNCHANGED <<status, claim, attempts, failedOnce, runKeys, workerVars,
                   wakeVars, sup, crashes, user, stale>>

\* The artifact pre-check and the first live-wake look.
Check(w) ==
    /\ pc[w] = "claimed"
    /\ heard' = [heard EXCEPT ![w] = "none"]
    /\ IF Satisfied({})
       THEN /\ pc' = [pc EXCEPT ![w] = "ok"]
            /\ UNCHANGED wk
       ELSE IF AttachToLiveWake /\ LiveWakes # {}
       THEN \E k \in LiveWakes :
               /\ pc' = [pc EXCEPT ![w] = "waiting"]
               /\ wk' = [wk EXCEPT ![w] = k]
       ELSE /\ pc' = [pc EXCEPT ![w] = "checked"]
            /\ UNCHANGED wk
    /\ UNCHANGED <<jobVars, tok, wakeVars, sup, crashes, user, stale>>

\* After the remaining reads (the refine's plan check, the agent lookup):
\* look again and enqueue with nothing awaited in between, so the pair is
\* atomic against another attempt that enqueued meanwhile.
Enqueue(w) ==
    /\ pc[w] = "checked"
    /\ UNCHANGED <<heard>>
    /\ IF AttachToLiveWake /\ RecheckBeforeEnqueue /\ LiveWakes # {}
       THEN \E k \in LiveWakes :
               /\ pc' = [pc EXCEPT ![w] = "waiting"]
               /\ wk' = [wk EXCEPT ![w] = k]
               /\ UNCHANGED <<wake, nextWake>>
       \* Past the model's bound an enqueue stands for a wake that fails
       \* at once, which keeps the bound from blocking progress.
       ELSE IF nextWake > MaxWakes
       THEN /\ pc' = [pc EXCEPT ![w] = "fail"]
            /\ UNCHANGED <<wk, wake, nextWake>>
       ELSE /\ wake' = [wake EXCEPT ![nextWake] = "queued"]
            /\ pc' = [pc EXCEPT ![w] = "enqueued"]
            /\ wk' = [wk EXCEPT ![w] = nextWake]
            /\ nextWake' = nextWake + 1
    /\ UNCHANGED <<jobVars, tok, artifact, starts, wasted, sup, crashes,
                   user, stale>>

Record(w) ==
    /\ pc[w] = "enqueued"
    /\ runKeys' = IF status \in Final THEN runKeys ELSE runKeys \cup {wk[w]}
    /\ pc' = [pc EXCEPT ![w] = "waiting"]
    /\ UNCHANGED <<status, claim, leaseLive, attempts, failedOnce, tok, wk,
                   heard, wakeVars, sup, crashes, user, stale>>

Hear(w) ==
    /\ pc[w] = "waiting" /\ heard[w] # "none"
    /\ pc' = [pc EXCEPT ![w] =
                 IF heard[w] = "completed" /\ Satisfied({wk[w]})
                 THEN "ok" ELSE "fail"]
    /\ UNCHANGED <<jobVars, tok, wk, heard, wakeVars, sup, crashes, user,
                   stale>>

Timeout(w) ==
    /\ pc[w] = "waiting" /\ heard[w] = "none"
    /\ pc' = [pc EXCEPT ![w] =
                 IF AttachToLiveWake /\ wake[wk[w]] \in Live
                 THEN "defer" ELSE "fail"]
    /\ UNCHANGED <<jobVars, tok, wk, heard, wakeVars, sup, crashes, user,
                   stale>>

\* _updateClaimed: fenced by status and claim_token.
Report(w) ==
    /\ pc[w] \in {"ok", "fail", "defer"}
    /\ pc' = [pc EXCEPT ![w] = "idle"]
    /\ IF status = "running" /\ claim = tok[w]
       THEN /\ claim' = NoClaim
            /\ leaseLive' = FALSE
            /\ stale' = IF sup[w] THEN stale + 1 ELSE stale
            /\ CASE pc[w] = "ok" ->
                      /\ status' = "succeeded"
                      /\ UNCHANGED <<attempts, failedOnce>>
                 [] pc[w] = "fail" ->
                      /\ attempts' = attempts + 1
                      /\ failedOnce' = TRUE
                      /\ status' = IF attempts + 1 >= MaxAttempts
                                   THEN "failed" ELSE "queued"
                 [] pc[w] = "defer" ->
                      /\ failedOnce' = TRUE
                      /\ status' = "queued"
                      /\ UNCHANGED attempts
       ELSE UNCHANGED <<status, claim, leaseLive, attempts, failedOnce, stale>>
    /\ UNCHANGED <<runKeys, tok, wk, heard, wakeVars, sup, crashes, user>>

----------------------------------------------------------------------------
(* The wake runtime, for this request's wakes. *)

\* Completion events reach the workers subscribed to that run key.
Emit(k, kind) ==
    heard' = [w \in Workers |->
                IF pc[w] \in {"enqueued", "waiting"} /\ wk[w] = k
                THEN kind ELSE heard[w]]

\* Single flight: no other run of the agent is live, aborted ones included.
WakeStart(k) ==
    /\ wake[k] = "queued"
    /\ \A j \in Wakes : wake[j] \notin {"running", "aborted"}
    /\ wake' = [wake EXCEPT ![k] = "running"]
    /\ starts' = starts + 1
    /\ wasted' = IF artifact # {} THEN wasted + 1 ELSE wasted
    /\ UNCHANGED <<jobVars, workerVars, artifact, nextWake, sup, crashes,
                   user, stale>>

\* The run of an enqueuing attempt that has not recorded its run key yet
\* cannot have committed: recordRunKey is one local write, the run is a
\* model call behind the drain's own awaits.
Recorded(k) ==
    ProvenanceRace \/ ~\E w \in Workers : pc[w] = "enqueued" /\ wk[w] = k

\* Nor can a whole model call fit inside another attempt's pre-enqueue
\* reads: a wake does not start and commit while an attempt sits between
\* its pre-check and its enqueue.
NoneChecking == \A w \in Workers : pc[w] # "checked"

WakeCommit(k) ==
    /\ wake[k] = "running" /\ Recorded(k) /\ NoneChecking
    /\ wake' = [wake EXCEPT ![k] = "done"]
    /\ artifact' = artifact \cup {k}
    /\ Emit(k, "completed")
    /\ UNCHANGED <<jobVars, pc, tok, wk, nextWake, starts, wasted, sup,
                   crashes, user, stale>>

WakeFail(k) ==
    /\ wake[k] = "running"
    /\ wake' = [wake EXCEPT ![k] = "done"]
    /\ Emit(k, "failed")
    /\ UNCHANGED <<jobVars, pc, tok, wk, artifact, nextWake, starts, wasted,
                   sup, crashes, user, stale>>

\* The ten-minute cap: the completion says aborted, the executor runs on.
WakeAbort(k) ==
    /\ wake[k] = "running"
    /\ wake' = [wake EXCEPT ![k] = "aborted"]
    /\ Emit(k, "failed")
    /\ UNCHANGED <<jobVars, pc, tok, wk, artifact, nextWake, starts, wasted,
                   sup, crashes, user, stale>>

AbortedSettles(k) ==
    /\ wake[k] = "aborted" /\ Recorded(k) /\ NoneChecking
    /\ wake' = [wake EXCEPT ![k] = "done"]
    /\ \E commits \in BOOLEAN :
          artifact' = IF commits THEN artifact \cup {k} ELSE artifact
    /\ UNCHANGED <<jobVars, workerVars, nextWake, starts, wasted, sup,
                   crashes, user, stale>>

----------------------------------------------------------------------------
(* The user and the process. *)

Cancel ==
    /\ user < MaxUser
    /\ status \notin Final
    /\ status' = "cancelled"
    /\ claim' = NoClaim
    /\ sup' = [v \in Workers |-> Supersede(v)]
    /\ leaseLive' = FALSE
    /\ user' = user + 1
    /\ UNCHANGED <<attempts, failedOnce, runKeys, workerVars, wakeVars,
                   crashes, stale>>

RetryNow ==
    /\ user < MaxUser
    /\ status \notin Final
    /\ status' = "queued"
    /\ claim' = NoClaim
    /\ leaseLive' = FALSE
    /\ sup' = [v \in Workers |-> Supersede(v)]
    /\ user' = user + 1
    /\ UNCHANGED <<attempts, failedOnce, runKeys, workerVars, wakeVars,
                   crashes, stale>>

Crash ==
    /\ crashes < MaxCrashes
    /\ crashes' = crashes + 1
    /\ pc' = [w \in Workers |-> "idle"]
    /\ heard' = [w \in Workers |-> "none"]
    /\ sup' = [w \in Workers |-> FALSE]
    /\ wake' = [k \in Wakes |-> IF wake[k] \in Live THEN "dead" ELSE wake[k]]
    /\ UNCHANGED <<jobVars, tok, wk, artifact, nextWake, starts, wasted,
                   user, stale>>

Next ==
    \/ \E w \in Workers :
          Claim(w) \/ Check(w) \/ Enqueue(w) \/ Record(w) \/ Hear(w) \/ Timeout(w)
          \/ Report(w)
    \/ LeaseExpires
    \/ \E k \in Wakes :
          WakeStart(k) \/ WakeCommit(k) \/ WakeFail(k) \/ WakeAbort(k)
          \/ AbortedSettles(k)
    \/ Cancel \/ RetryNow \/ Crash

\* Workers, wakes and the clock make progress; users and crashes are never
\* forced. A run settles one way or another.
Fairness ==
    /\ \A w \in Workers :
          /\ WF_vars(Check(w)) /\ WF_vars(Enqueue(w))
          /\ WF_vars(Record(w)) /\ WF_vars(Hear(w))
          /\ WF_vars(Timeout(w)) /\ WF_vars(Report(w))
    /\ WF_vars(\E w \in Workers : Claim(w))
    /\ WF_vars(LeaseExpires)
    /\ \A k \in Wakes :
          /\ WF_vars(WakeStart(k))
          /\ WF_vars(WakeCommit(k) \/ WakeFail(k) \/ WakeAbort(k))
          /\ WF_vars(AbortedSettles(k))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ status \in {"queued", "running"} \cup Settled
    /\ runKeys \subseteq Wakes
    /\ artifact \subseteq Wakes
    /\ \A w \in Workers :
          pc[w] \in {"idle", "claimed", "checked", "enqueued", "waiting", "ok", "fail",
                     "defer"}

\* At most one inference of the request is queued or running at a time.
AtMostOneLiveWake == Cardinality(LiveWakes) <= 1

\* No inference starts once the request's artifact exists.
NoInferenceAfterArtifact == wasted = 0

\* A request yields at most one artifact (one plan write, one ChangeSet).
AtMostOneArtifact == Cardinality(artifact) <= 1

\* No fenced write lands under a claim that was revoked.
Fenced == stale = 0

\* Every job reaches a terminal state, or `failed` for the user to retry.
EventuallySettled == <>(status \in Settled)
=============================================================================
