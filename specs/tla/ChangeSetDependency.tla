----------------------- MODULE ChangeSetDependency -----------------------
EXTENDS Naturals

(* A follow-up and its migration live in the original set. Consolidation
   may move a pending migration into a newer set, but completion/cascade
   still address the original id. The confirmation service recognizes a
   placeholder only beside its follow-up. KeepDependenciesTogether models
   ChangeSetBuilder excluding unresolved groups from consolidation. *)
CONSTANT KeepDependenciesTogether
VARIABLES parent, owner, target, pending, consolidated, attempted, badDispatch
vars == <<parent, owner, target, pending, consolidated, attempted, badDispatch>>
Init ==
    /\ parent \in {"pending", "claimed", "rejected"}
    /\ owner = "original"
    /\ target = "placeholder"
    /\ pending = TRUE
    /\ consolidated = FALSE
    /\ attempted = FALSE
    /\ badDispatch = FALSE
Claim ==
    /\ parent = "pending"
    /\ parent' = "claimed"
    /\ UNCHANGED <<owner, target, pending, consolidated, attempted, badDispatch>>
Complete ==
    /\ parent = "claimed"
    /\ parent' = "applied"
    /\ target' = IF owner = "original" THEN "realTask" ELSE target
    /\ UNCHANGED <<owner, pending, consolidated, attempted, badDispatch>>
Reject ==
    /\ parent = "pending"
    /\ parent' = "rejected"
    /\ UNCHANGED <<owner, target, pending, consolidated, attempted, badDispatch>>
Cascade ==
    /\ parent = "rejected"
    /\ pending
    /\ owner = "original"
    /\ pending' = FALSE
    /\ UNCHANGED <<parent, owner, target, consolidated, attempted, badDispatch>>
Consolidate ==
    /\ ~consolidated
    /\ consolidated' = TRUE
    /\ owner' = IF pending /\ ~(KeepDependenciesTogether /\ target = "placeholder")
                THEN "newer" ELSE owner
    /\ UNCHANGED <<parent, target, pending, attempted, badDispatch>>
ConfirmMigration ==
    /\ pending /\ ~attempted
    /\ target = "realTask" \/ owner = "newer"
    /\ attempted' = TRUE
    /\ badDispatch' = (target # "realTask")
    /\ UNCHANGED <<parent, owner, target, pending, consolidated>>
Next == Claim \/ Complete \/ Reject \/ Cascade \/ Consolidate \/ ConfirmMigration
Spec == Init /\ [][Next]_vars
MigrationAfterTarget == ~badDispatch
DependencyOwned == pending /\ target = "placeholder" => owner = "original"
CompletionReachesMigration == parent = "applied" => target = "realTask"
=============================================================================
