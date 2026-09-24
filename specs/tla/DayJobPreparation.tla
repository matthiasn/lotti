----------------------- MODULE DayJobPreparation -----------------------
\* Two overlapping executors for one durable request. Preparation may pause
\* long enough for the other executor to finish its wake. The shared registry
\* coalesces the whole attempt, including the artifact read and enqueue.
EXTENDS Naturals
CONSTANT Coalesce
VARIABLES pc, owner, artifact, calls
vars == <<pc, owner, artifact, calls>>
Workers == 1..2
Init == /\ pc = [w \in Workers |-> "idle"]
        /\ owner = 0 /\ artifact = FALSE /\ calls = 0
Begin(w) ==
    /\ pc[w] = "idle"
    /\ IF Coalesce /\ owner # 0
       THEN /\ pc' = [pc EXCEPT ![w] = "waiting"]
            /\ UNCHANGED owner
       ELSE /\ pc' = [pc EXCEPT ![w] = IF artifact THEN "done" ELSE "prepared"]
            /\ owner' = IF artifact THEN owner ELSE w
    /\ UNCHANGED <<artifact, calls>>
\* No live wake remains after this step. A previously prepared attempt
\* therefore cannot detect this inference with a live-wake probe alone.
Run(w) ==
    /\ pc[w] = "prepared"
    /\ pc' = [pc EXCEPT ![w] = "finishing"]
    /\ artifact' = TRUE /\ calls' = calls + 1
    /\ UNCHANGED owner
Finish(w) ==
    /\ pc[w] = "finishing"
    /\ pc' = [v \in Workers |->
          IF v = w \/ (Coalesce /\ pc[v] = "waiting") THEN "done" ELSE pc[v]]
    /\ owner' = 0
    /\ UNCHANGED <<artifact, calls>>
Next == \E w \in Workers : Begin(w) \/ Run(w) \/ Finish(w)
Spec == Init /\ [][Next]_vars
TypeOK == /\ pc \in [Workers -> {"idle", "prepared", "waiting", "finishing", "done"}]
          /\ owner \in 0..2 /\ artifact \in BOOLEAN /\ calls \in 0..2
OneInference == calls <= 1
=============================================================================
