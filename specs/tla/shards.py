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

# Wall-clock seconds of each configuration's own CI job (checkout and Java
# setup included) in run 36100346527, main at b1bd9ae11. Refresh when a
# configuration's state space changes by an order of magnitude.
SECONDS = {
    "AgentReplicationIntent": 604,
    "AgentMessageLog": 584,
    "SyncSequenceCrash": 514,
    "AgentReplication": 472,
    "SyncSequence": 467,
    "AgentMessageLogLiveness": 367,
    "DayProcessingJob": 348,
    "DayProcessingJobDraft": 337,
    "AgentReplicationIntentTerminal": 295,
    "AgentReplicationTerminal": 291,
    "VersionHeadsSoul": 242,
    "SyncSequenceCrashFault": 95,
    "ScheduledWakeLeaseThree": 91,
    "ScheduledWakeLeaseCrashRearm": 87,
    "ScheduledWakeLease": 75,
    "SyncSequenceCrashUnnamed": 67,
    "SyncSequenceFaults": 59,
    "WakeRuntimeCrash": 57,
    "LogCompaction": 41,
    "VersionHeadsGoal": 36,
    "ChangeSetLifecycleRaceSet": 30,
    "ScheduledWakeLeaseCrash": 28,
    "ChangeSetLifecycleSync": 24,
    "ChangeSetLifecycleRace": 22,
    "AgentMessageLogStale": 21,
    "GoalChatReplyThree": 19,
    "ChangeSetConfirmFaults": 19,
    "ChangeSetConfirm": 18,
    "GoalChatReply": 17,
    "ChangeSetLifecycle": 17,
    "WakeRuntime": 15,
    "DigestRecoveryCrash": 15,
    "ChangeSetLifecycleReopen": 14,
    "OwnCounterSettlement": 13,
    "DigestRecovery": 12,
    "ChangeSetLifecycleSyncSplit": 12,
    "ChangeSetLifecycleConsolidate": 11,
    "ChangeSetLifecycleConsolidateSync": 10,
    "ChangeSetDependency": 10,
    "AgentStateWrites": 10,
    "DayJobPreparation": 8,
    "ChangeSetLifecycleRaceLink": 8,
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
