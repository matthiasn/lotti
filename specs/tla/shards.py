#!/usr/bin/env python3
"""Pack the TLC configurations in this directory into a few CI shards.

    python3 specs/tla/shards.py            # JSON matrix for GitHub Actions
    python3 specs/tla/shards.py --table    # the plan, for reading

Every `*.cfg` in this directory is assigned to exactly one shard; SECONDS only
decides the balance, never whether a configuration runs. A configuration that
cannot finish within a CI job lives in `manual/` and is run by hand. A configuration missing from
SECONDS is assumed to take DEFAULT_SECONDS until it is measured and added.
"""

import argparse
import json
import math
from pathlib import Path

# The fewest regular shards a plan uses.
SHARDS = 8

# Estimated seconds a shard may hold. Its job times out at 60
# minutes, and a configuration can take half as long again on another runner
# (see SECONDS), so a shard planned to the minute is planned to time out:
# every regular shard of the nightly runs from 30 Sep to 11 Oct 2026 was
# cancelled at 60 minutes after being packed to about 61, and a first plan
# at 40 minutes still lost four of 13 shards to the limit (run 38173436229),
# its estimates a quarter short on average. Half as long again as this
# budget still fits the hour. The plan adds shards until none is estimated
# past it.
SHARD_BUDGET_SECONDS = 2000

# Seconds TLC spent on each configuration in CI run 38173436229 (13 shards on
# four-core runners at once), keeping the older figure where it was larger.
# A configuration still running when its shard was cancelled is budgeted at
# half as long again as it had run, or eight times its local twenty-worker
# time, whichever is more; one the run never reached keeps its older figure
# with 30% added, the run's average overrun. The same configuration can take
# half as long again on another runner, so refresh when a configuration is
# added or its state space changes by an order of magnitude, not for
# run-to-run noise.
SECONDS = {
    "AgentLinks": 7,
    "AgentLinksLossy": 435,
    "AgentLinksSlot": 10,
    "AgentLinksSlotLossy": 349,
    "AgentMessageLog": 575,
    "AgentMessageLogLiveness": 627,
    "AgentMessageLogStale": 10,
    "AgentReplication": 858,
    "AgentReplicationIntent": 885,
    "AgentReplicationIntentTerminal": 627,
    "AgentReplicationLegacyCounter": 884,
    "AgentReplicationLegacyReceiver": 452,
    "AgentReplicationRemoval": 634,
    "AgentReplicationRemovalLossy": 65,
    "AgentReplicationSeed": 60,
    "AgentReplicationSeedLossy": 11,
    "AgentReplicationTerminal": 409,
    "AgentStateWrites": 1,
    "AgentWakeCoordination": 60,
    "AgentWakeCoordinationCrash": 634,
    "AgentWakeCoordinationFailure": 359,
    "AgentWakeCoordinationLossy": 288,
    "AgentWakeOutcome": 2,
    "AgentWakeOutcomeSkew": 3,
    "AiConfigClocks": 1730,
    "AiConfigReplication": 11,
    "AiConfigReplicationCascade": 13,
    "AiConfigReplicationInterrupted": 20,
    "AiConfigReplicationOwed": 894,
    "AiConfigReplicationUndo": 20,
    "ChangeDispatchRecovery": 2,
    "ChangeSetConfirm": 1,
    "ChangeSetConfirmFaults": 1,
    "ChangeSetDependency": 1,
    "ChangeSetLifecycle": 2,
    "ChangeSetLifecycleConsolidate": 1,
    "ChangeSetLifecycleConsolidateSync": 6,
    "ChangeSetLifecycleRace": 13,
    "ChangeSetLifecycleRaceAdd": 7,
    "ChangeSetLifecycleRaceLink": 1,
    "ChangeSetLifecycleRaceRestore": 25,
    "ChangeSetLifecycleRaceSet": 26,
    "ChangeSetLifecycleRaceUndo": 66,
    "ChangeSetLifecycleReopen": 1,
    "ChangeSetLifecycleSync": 26,
    "ChangeSetLifecycleSyncSplit": 4,
    "ChangeSetLifecycleUndo": 1,
    "ChangeSetLifecycleUndoRetry": 1,
    "ChecklistMembership": 71,
    "ChecklistMembershipCrash": 26,
    "ChecklistMembershipFailure": 10,
    "ChecklistMembershipThree": 13,
    "ChecklistReplication": 1495,
    "ChecklistReplicationAdds": 1257,
    "ChecklistReplicationCrash": 50,
    "ConversationLoop": 10,
    "ConversationLoopConcurrent": 14,
    "DayJobPreparation": 1,
    "DayProcessingJob": 379,
    "DayProcessingJobDraft": 383,
    "DeepBackfill": 612,
    "DeepBackfillBatch": 60,
    "DeepBackfillFaults": 30,
    "DeepBackfillIncremental": 514,
    "DeepBackfillMedia": 300,
    "DeepBackfillMediaFaults": 300,
    "DeepBackfillMediaOneSided": 300,
    "DeepBackfillMediaPaged": 300,
    "DeepBackfillMediaResend": 300,
    "DeepBackfillMediaThree": 300,
    "DeepBackfillMerge": 1421,
    "DeepBackfillOneSided": 6,
    "DeepBackfillPaged": 627,
    "DeepBackfillThree": 60,
    "DefinitionClocks": 2,
    "DefinitionClocksLossy": 300,
    "DefinitionClocksThree": 20,
    "DevicePairing": 150,
    "DigestRecovery": 1,
    "DigestRecoveryCrash": 2,
    "EmbeddingFreshness": 39,
    "EmbeddingFreshnessTwo": 65,
    "EntryLinkIdentity": 10,
    "EntryLinkIdentityEdits": 10,
    "EntryLinkIdentityLegacy": 10,
    "EntryLinkIdentityLegacyReceiver": 5,
    "EnvelopeChain": 3,
    "EnvelopeChainRevocation": 49,
    "EvolutionSession": 6,
    "GitHubAccountSync": 127,
    "GoalChatReply": 513,
    "GoalChatReplyThree": 8,
    "GoalRegister": 3,
    "GoalRegisterCrash": 29,
    "GoalRegisterDeath": 5,
    "GoalRegisterDivergent": 2,
    "HabitDaySettlement": 4,
    "HabitDaySettlementThree": 10,
    "InboundQueue": 523,
    "InboundQueueCipher": 22,
    "InboundQueueCrash": 42,
    "InboundQueueLiveness": 124,
    "InboundQueueSameMs": 300,
    "InboundQueueSlice": 5,
    "JournalReplication": 257,
    "JournalReplicationLabels": 21,
    "JournalReplicationLegacy": 6,
    "JournalReplicationLossy": 20,
    "LogCompaction": 50,
    "NotificationReplication": 16,
    "Outbox": 60,
    "OutboxCausality": 20,
    "OutboxConcurrent": 5,
    "OutboxConcurrentLive": 218,
    "OutboxGhost": 961,
    "OutboxGhostRows": 682,
    "OutboxOperator": 529,
    "OutboxRequeue": 745,
    "OwnCounterSettlement": 1,
    "ProjectWakeGovernor": 6,
    "ProjectWakeGovernorBacklog": 5,
    "ProjectWakeGovernorBudget": 132,
    "ProjectWakeGovernorPause": 26,
    "ProjectWakeGovernorThree": 65,
    "PullRequestAssignment": 3,
    "PullRequestAssignmentSync": 9,
    "PullRequestSnapshot": 9,
    "PullRequestSnapshotCoarse": 37,
    "PullRequestSnapshotLiveness": 31,
    "PullRequestSnapshotNoToken": 5,
    "PullRequestSnapshotSync": 15,
    "RelationshipAgentLifecycle": 3,
    "RelationshipAgentLifecycleConflict": 86,
    "RelationshipAgentLifecycleCrash": 3,
    "RelationshipAgentLifecycleHardDelete": 581,
    "RelationshipAgentLifecyclePause": 16,
    "RelationshipAgentLifecycleStop": 515,
    "RelationshipCadence": 379,
    "RelationshipCadenceEnroll": 5,
    "RunningTimer": 10,
    "SavedTaskFilterSync": 92,
    "SavedTaskFilterSyncThree": 557,
    "ScheduledWakeLease": 58,
    "ScheduledWakeLeaseCrash": 21,
    "ScheduledWakeLeaseCrashRearm": 79,
    "ScheduledWakeLeaseThree": 75,
    "SpeechDictionarySync": 14,
    "SyncPipeline": 721,
    "SyncPipelineAgentEntity": 7,
    "SyncPipelineAgentLink": 1,
    "SyncPipelineBurn": 5,
    "SyncPipelineConsumption": 359,
    "SyncPipelineDefinition": 2,
    "SyncPipelineHeads": 988,
    "SyncPipelineHeadsBurn": 15,
    "SyncPipelineHeadsCrash": 1950,
    "SyncPipelineJournal": 693,
    "SyncPipelineLossy": 371,
    "SyncPipelineMixedPeers": 1863,
    "SyncPipelineNotification": 1593,
    "SyncPreferenceEdits": 5,
    "SyncPreferenceEditsFlags": 2,
    "SyncSequence": 840,
    "SyncSequenceCrash": 639,
    "SyncSequenceCrashFault": 83,
    "SyncSequenceCrashUnnamed": 62,
    "SyncSequenceFaults": 59,
    "SyncSettings": 2,
    "SyncSettingsEqualStamps": 2,
    "SyncSettingsFailure": 2,
    "SyncSettingsFlags": 1,
    "SyncSettingsName": 2,
    "SyncSettingsNameEqualStamps": 2,
    "SyncSettingsNameFailure": 1,
    "TaskAgentAssignment": 60,
    "TaskAgentAssignmentLegacy": 2,
    "TaskAgentAssignmentSkew": 199,
    "TaskCategoryMove": 2,
    "TaskFieldWrites": 33,
    "TaskFieldWritesAgents": 195,
    "TaskFieldWritesResolve": 193,
    "TaskFieldWritesStale": 422,
    "TaskLabels": 2,
    "TaskLinkGraph": 304,
    "TaskLinkGraphProjects": 6,
    "TaskLinkGraphProjectsThree": 25,
    "TranscriptionRun": 12,
    "TranscriptionRunExhaust": 57,
    "TranscriptionRunHeld": 20,
    "VerificationLaunch": 166,
    "VerificationLaunchCrossStart": 15,
    "VerificationLaunchTwoLaunchers": 81,
    "VersionHeadsGoal": 27,
    "VersionHeadsSoul": 277,
    "WakeRuntime": 8,
    "WakeRuntimeCrash": 66,
}

# Pessimistic, so an unmeasured configuration is not piled onto a full shard.
DEFAULT_SECONDS = 300


def shard_count(configurations):
    """The fewest shards that could hold the configurations within
    SHARD_BUDGET_SECONDS each — at least SHARDS, and never more than there are
    configurations. A lower bound: `plan` adds shards until the packing fits."""
    total = sum(SECONDS.get(c, DEFAULT_SECONDS) for c in configurations)
    return min(len(configurations), max(SHARDS, math.ceil(total / SHARD_BUDGET_SECONDS)))


def _pack(configurations, count):
    """Longest-first greedy packing: each configuration goes to the lightest shard."""
    bins = [{"seconds": 0, "configurations": []} for _ in range(count)]
    ordered = sorted(configurations, key=lambda c: (-SECONDS.get(c, DEFAULT_SECONDS), c))
    for configuration in ordered:
        lightest = min(bins, key=lambda b: b["seconds"])
        lightest["configurations"].append(configuration)
        lightest["seconds"] += SECONDS.get(configuration, DEFAULT_SECONDS)
    return bins


def _overflows(bins):
    """A shard of several configurations past the budget. One configuration
    over the budget alone cannot be split, so it does not count."""
    return any(len(b["configurations"]) > 1 and b["seconds"] > SHARD_BUDGET_SECONDS
               for b in bins)


def plan(configurations, shards=None):
    """Packs the configurations into shards. Unless [shards] fixes the count,
    shards are added until every shard of several configurations fits the
    budget: the total over the budget is only a lower bound when weights are
    uneven."""
    if shards is not None:
        bins = _pack(configurations, min(shards, len(configurations)))
    else:
        count = shard_count(configurations)
        bins = _pack(configurations, count)
        while _overflows(bins) and count < len(configurations):
            count += 1
            bins = _pack(configurations, count)
    assigned = sorted(c for b in bins for c in b["configurations"])
    assert assigned == sorted(configurations), "every configuration runs exactly once"
    return [
        {"shard": index + 1, "estimate": b["seconds"],
         "configurations": " ".join(b["configurations"])}
        for index, b in enumerate(bins)
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--table", action="store_true", help="print the plan instead of JSON")
    args = parser.parse_args()

    configurations = sorted(path.stem for path in Path(__file__).parent.glob("*.cfg"))
    if not configurations:
        raise SystemExit("No TLC configurations found")
    shards = plan(configurations)
    if args.table:
        for shard in shards:
            print(f"{shard['shard']}  ~{shard['estimate']:>4}s  {shard['configurations']}")
    else:
        print(json.dumps(shards))


if __name__ == "__main__":
    main()
