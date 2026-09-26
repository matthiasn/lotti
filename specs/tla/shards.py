#!/usr/bin/env python3
"""Pack the TLC configurations in this directory into a few CI shards.

    python3 specs/tla/shards.py            # JSON matrix for GitHub Actions
    python3 specs/tla/shards.py --table    # the plan, for reading

Every checked-in `*.cfg` is assigned to exactly one shard; SECONDS only decides
the balance, never whether a configuration runs. A configuration missing from
SECONDS is assumed to take DEFAULT_SECONDS until it is measured and added.
"""

import argparse
import json
from pathlib import Path

SHARDS = 8

# Keep measured multi-hour profiles out of the one-hour regular shards. They
# still run on every applicable push and feed the same required TLC check.
EXTENDED_CONFIGURATIONS = {"SyncPipelineForkSuccessor"}

# Seconds TLC spent on each configuration in CI runs 36198815983 and
# 36217391296, retaining
# larger historic budgets from runs 36106366560 and 36109959497. The
# same configuration can take half as long again on another runner, so refresh
# when a configuration is added or its state space changes by an order of
# magnitude, not for run-to-run noise.
SECONDS = {
    # Pipeline profiles measured in CI run 36198815983. HeadsCrash uses the
    # slower 36198563598 measurement: the old 300s estimate overloaded a shard
    # past its 45-minute deadline even though the profile itself passed.
    "SyncPipeline": 685,
    # Local exhaustive runs with six workers; refresh from CI measurements.
    "SyncPipelineForkSuccessor": 9860,
    "SyncPipelineMixedPeers": 1078,
    "SyncPipelineJournal": 646,
    "SyncPipelineAgentEntity": 6,
    "SyncPipelineAgentLink": 1,
    "SyncPipelineNotification": 1515,
    "SyncPipelineConsumption": 339,
    "SyncPipelineLossy": 369,
    "SyncPipelineBurn": 5,
    "SyncPipelineHeads": 988,
    "SyncPipelineHeadsBurn": 15,
    "SyncPipelineHeadsCrash": 1750,
    "AgentReplicationIntent": 847,
    "AgentReplicationLegacyCounter": 841,
    "SyncSequence": 831,
    "AgentMessageLogLiveness": 627,
    "AgentReplication": 594,
    "AgentMessageLog": 574,
    "SyncSequenceCrash": 552,
    "AgentReplicationIntentTerminal": 627,
    "DayProcessingJobDraft": 358,
    "AgentLinksLossy": 323,
    "DayProcessingJob": 379,
    "AgentReplicationTerminal": 409,
    "VersionHeadsSoul": 277,
    "AgentReplicationLegacyReceiver": 452,
    "InboundQueue": 523,
    "SyncSequenceCrashFault": 78,
    "ScheduledWakeLeaseThree": 74,
    "WakeRuntimeCrash": 66,
    "ScheduledWakeLease": 58,
    "SyncSequenceFaults": 58,
    "ScheduledWakeLeaseCrashRearm": 61,
    "SyncSequenceCrashUnnamed": 48,
    "OutboxGhost": 178,
    "LogCompaction": 30,
    "InboundQueueLiveness": 124,
    "VersionHeadsGoal": 26,
    "OutboxOperator": 223,
    "ChangeSetLifecycleRaceSet": 20,
    "OutboxConcurrentLive": 119,
    "ScheduledWakeLeaseCrash": 16,
    "ChangeSetLifecycleSync": 18,
    "ChangeSetLifecycleRace": 13,
    "AgentMessageLogStale": 8,
    "InboundQueueCrash": 42,
    "GoalChatReplyThree": 8,
    "HabitDaySettlementThree": 8,
    "WakeRuntime": 8,
    "AgentLinks": 6,
    "ChangeSetLifecycleConsolidateSync": 6,
    "EvolutionSession": 6,
    "ChangeSetLifecycleSyncSplit": 4,
    "InboundQueueCipher": 17,
    "HabitDaySettlement": 4,
    # Local measurements; refresh from CI.
    "ChecklistMembership": 60,
    "ChecklistMembershipCrash": 20,
    "ChecklistMembershipThree": 10,
    "Outbox": 12,
    "ChangeSetLifecycle": 2,
    "OutboxConcurrent": 3,
    "AgentStateWrites": 1,
    "ChangeSetConfirm": 1,
    "ChangeSetConfirmFaults": 1,
    "ChangeSetDependency": 1,
    "ChangeSetLifecycleConsolidate": 1,
    "ChangeSetLifecycleRaceLink": 1,
    "ChangeSetLifecycleReopen": 1,
    "DayJobPreparation": 1,
    "DigestRecovery": 1,
    "DigestRecoveryCrash": 1,
    "GoalChatReply": 1,
    "OwnCounterSettlement": 1,
    "NotificationReplication": 15,
    "SyncPreferenceEdits": 2,
    "SyncSettings": 1,
    "SyncSettingsEqualStamps": 1,
    "SyncSettingsNameEqualStamps": 1,
    "SyncSettingsName": 1,
    "SyncSettingsFlags": 1,
    "SavedTaskFilterSyncThree": 200,
    "SavedTaskFilterSync": 35,
    "SyncSettingsFailure": 1,
    "SyncSettingsNameFailure": 1,
    "OutboxCausality": 20,
    # Measured locally (20 workers) when added; refresh from CI.
    "JournalReplication": 33,
    "JournalReplicationLabels": 6,
    "JournalReplicationLossy": 3,
    "JournalReplicationLegacy": 2,
    # Measured locally when added; refresh from CI.
    "EnvelopeChain": 2,
    "EnvelopeChainRevocation": 15,
    "AgentReplicationRemoval": 596,
    "AgentReplicationRemovalLossy": 61,
    "GoalRegister": 3,
    "GoalRegisterCrash": 23,
    "GoalRegisterDeath": 4,
    "GoalRegisterDivergent": 1,
}

# Pessimistic, so an unmeasured configuration is not piled onto a full shard.
DEFAULT_SECONDS = 300


def plan(configurations, shards=SHARDS):
    """Longest-first greedy packing: each configuration goes to the lightest shard."""
    regular = [c for c in configurations if c not in EXTENDED_CONFIGURATIONS]
    bins = [{"seconds": 0, "configurations": []} for _ in range(min(shards, len(regular)))]
    ordered = sorted(regular, key=lambda c: (-SECONDS.get(c, DEFAULT_SECONDS), c))
    for configuration in ordered:
        lightest = min(bins, key=lambda b: b["seconds"])
        lightest["configurations"].append(configuration)
        lightest["seconds"] += SECONDS.get(configuration, DEFAULT_SECONDS)
    for configuration in sorted(set(configurations) & EXTENDED_CONFIGURATIONS):
        bins.append({"seconds": SECONDS[configuration], "configurations": [configuration]})
    assigned = sorted(c for b in bins for c in b["configurations"])
    assert assigned == sorted(configurations), "every configuration runs exactly once"
    return [
        {"shard": index + 1, "estimate": b["seconds"],
         "configurations": " ".join(b["configurations"]),
         "timeout_minutes": 360 if b["configurations"][0] in EXTENDED_CONFIGURATIONS else 60,
         "java_options": "-Xmx12g" if b["configurations"][0] in EXTENDED_CONFIGURATIONS else ""}
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
            print(f"{shard['shard']}  ~{shard['estimate']:>4}s  "
                  f"limit={shard['timeout_minutes']}m  {shard['configurations']}")
    else:
        print(json.dumps(shards))


if __name__ == "__main__":
    main()
