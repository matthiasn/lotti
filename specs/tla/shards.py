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

# Seconds TLC spent on each configuration, averaged over the sharded runs
# 36106366560 and 36109959497 (read from each configuration's log group). The
# same configuration can take half as long again on another runner, so refresh
# when a configuration is added or its state space changes by an order of
# magnitude, not for run-to-run noise.
SECONDS = {
    "AgentReplicationIntent": 646,
    "AgentReplicationLegacyCounter": 642,
    "SyncSequence": 640,
    "AgentMessageLogLiveness": 605,
    "AgentReplication": 594,
    "AgentMessageLog": 574,
    "SyncSequenceCrash": 552,
    "AgentReplicationIntentTerminal": 484,
    "DayProcessingJobDraft": 358,
    "AgentLinksLossy": 323,
    "DayProcessingJob": 316,
    "AgentReplicationTerminal": 308,
    "VersionHeadsSoul": 266,
    "AgentReplicationLegacyReceiver": 223,
    "InboundQueue": 120,
    "SyncSequenceCrashFault": 78,
    "ScheduledWakeLeaseThree": 74,
    "WakeRuntimeCrash": 66,
    "ScheduledWakeLease": 58,
    "SyncSequenceFaults": 56,
    "ScheduledWakeLeaseCrashRearm": 49,
    "SyncSequenceCrashUnnamed": 48,
    "OutboxGhost": 33,
    "LogCompaction": 30,
    "InboundQueueLiveness": 29,
    "VersionHeadsGoal": 26,
    "OutboxOperator": 21,
    "ChangeSetLifecycleRaceSet": 20,
    "OutboxConcurrentLive": 19,
    "ScheduledWakeLeaseCrash": 16,
    "ChangeSetLifecycleSync": 14,
    "ChangeSetLifecycleRace": 13,
    "AgentMessageLogStale": 8,
    "InboundQueueCrash": 8,
    "GoalChatReplyThree": 8,
    "HabitDaySettlementThree": 8,
    "WakeRuntime": 8,
    "AgentLinks": 6,
    "ChangeSetLifecycleConsolidateSync": 6,
    "EvolutionSession": 6,
    "ChangeSetLifecycleSyncSplit": 4,
    "InboundQueueCipher": 4,
    "HabitDaySettlement": 4,
    "Outbox": 4,
    "ChangeSetLifecycle": 2,
    "OutboxConcurrent": 2,
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
    "NotificationReplication": 13,
    "SyncSettings": 1,
    "SyncSettingsName": 1,
    "SyncSettingsFlags": 1,
    "OutboxCausality": 7,
    # Measured locally (20 workers) when added; refresh from CI.
    "JournalReplicationSidecar": 38,
    "JournalReplication": 8,
    "JournalReplicationSidecarRollback": 5,
    "JournalReplicationLabels": 3,
    "JournalReplicationLossy": 3,
    "JournalReplicationLegacy": 2,
}

# Pessimistic, so an unmeasured configuration is not piled onto a full shard.
DEFAULT_SECONDS = 300


def plan(configurations, shards=SHARDS):
    """Longest-first greedy packing: each configuration goes to the lightest shard."""
    bins = [{"seconds": 0, "configurations": []} for _ in range(min(shards, len(configurations)))]
    ordered = sorted(configurations, key=lambda c: (-SECONDS.get(c, DEFAULT_SECONDS), c))
    for configuration in ordered:
        lightest = min(bins, key=lambda b: b["seconds"])
        lightest["configurations"].append(configuration)
        lightest["seconds"] += SECONDS.get(configuration, DEFAULT_SECONDS)
    assigned = sorted(c for b in bins for c in b["configurations"])
    assert assigned == sorted(configurations), "every configuration runs exactly once"
    return [
        {"shard": index + 1, "estimate": b["seconds"], "configurations": " ".join(b["configurations"])}
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
