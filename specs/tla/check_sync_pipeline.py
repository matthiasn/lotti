#!/usr/bin/env python3
"""Require targeted counterexamples and passing recovery controls.

Run after/instead of tlc.sh: a temporary copy uses its pinned, checksummed TLC.
No intentionally failing configuration is left in the positive CI shard set.
"""

import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def check(name, constants, assertion, *, temporal=False, extension="", fails=True,
          module="SyncPipeline", profile=None):
    config = (HERE / f"{profile or module}.cfg").read_text()
    for key, value in constants.items():
        config, count = re.subn(
            rf"(?m)^    {key} = .*$", f"    {key} = {value}", config
        )
        if count != 1:
            raise ValueError(f"{name}: unknown/duplicate constant {key}")
    config = re.sub(r"(?m)^(INVARIANTS?|PROPERT(?:Y|IES)) .*\n?", "", config)
    config += f"{'PROPERTY' if temporal else 'INVARIANT'} {assertion}\n"
    spec = (HERE / f"{module}.tla").read_text()
    separator = "\n" + "=" * 77
    spec = spec.replace(separator, extension + separator)
    with tempfile.TemporaryDirectory(prefix=f"sync-pipeline-{name}-") as directory:
        work = Path(directory)
        shutil.copy2(HERE / "tlc.sh", work / "tlc.sh")
        (work / f"{module}.tla").write_text(spec)
        (work / f"{module}.cfg").write_text(config)
        result = subprocess.run(
            ["bash", str(work / "tlc.sh"), module],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            timeout=600 if constants.get("AnnounceHeads") == "TRUE" else 300,
            check=False,
            env={**os.environ, "JAVA_TOOL_OPTIONS": "-Xmx2g"},
        )
    expected = (
        "Temporal properties were violated"
        if temporal else f"Invariant {assertion} is violated"
    )
    if fails:
        passed = result.returncode != 0 and expected in result.stdout
    else:
        passed = result.returncode == 0 and "No error has been found" in result.stdout
    if not passed:
        raise AssertionError(f"{name}: unexpected TLC result\n{result.stdout}")
    outcome = "expected counterexample" if fails else "guarded control passes"
    print(f"{name}: {outcome}", flush=True)


def main():
    for guarded, fails in (("TRUE", False), ("FALSE", True)):
        check("response-admission-" + guarded, {"AdmitResponses": guarded},
              "NoSilentLoss", module="InboundQueue",
              profile="InboundQueueSlice", fails=fails)
    for guarded, fails in (("TRUE", False), ("FALSE", True)):
        check("mixed-family-namespace-" + guarded,
              {"MixedFamilies": "TRUE", "MaxCounter": "2",
               "ConcurrentWriters": "TRUE", "NamespacePayloads": guarded},
              "PayloadFamilySafe", fails=fails)
    check("mixed-peers-fully-acknowledged", {"MaxFaults": "0", "MaxCrashes": "0"},
          "NoSettledMixedWitness", profile="SyncPipelineMixedPeers",
          extension='\nNoSettledMixedWitness == ~(Counters \\subseteq s.committed /\\\n'
                    '    (\\A p \\in Peers : Counters \\subseteq s.received[p]))\n')
    mutations = [
        ("burn", "DurableBurn", {"MaxCounter": "1", "AbortCounters": "{1}",
         "MaxFaults": "1", "FaultKinds": '{"burnStage"}'}, "BurnHasDurableMarker"),
        ("bind", "BindAfterEnqueue", {"MaxCounter": "1", "MaxFaults": "1",
         "FaultKinds": '{"stage"}'}, "BoundHasDurablePayload"),
        ("receipt", "ReceiptAfterApply", {"MaxCounter": "1"}, "NoFalseReceipt"),
        ("hint", "VerifyHints", {"SeparateEntities": "TRUE"}, "NoFalseReceipt"),
        ("descriptor", "PrepareExactPayload", {"Family": '"journal"'}, "CausalCoverage"),
    ]
    for name, switch, constants, assertion in mutations:
        # Passing controls prevent a pre-existing violation from being mistaken
        # for sensitivity to the switch. Only the one guard changes.
        check(name + "-guarded", constants, assertion, fails=False)
        check(name + "-mutated", {**constants, switch: "FALSE"}, assertion)
    for heads, fails in (("FALSE", True), ("TRUE", False)):
        check("lost-tail-announcements-" + heads, {
            "MaxCounter": "1", "MaxFaults": "1",
            "FaultKinds": '{"receive"}', "AnnounceHeads": heads,
        }, "CommittedReachesPeer", temporal=True, fails=fails)
    for retry, fails in (("TRUE", False), ("FALSE", True)):
        check("tail-receipt-retry-" + retry, {
            "MaxCounter": "1", "MaxFaults": "1",
            "FaultKinds": '{"receipt"}', "RetryReceipts": retry,
        }, "EveryCommitReceipted", temporal=True, fails=fails,
            extension='\nEveryCommitReceipted == \\A p \\in Peers, c \\in Counters :\n'
                      '    c \\in s.committed ~> c \\in s.received[p]\n')
    # The conditional gap claim must exercise the repair channel; forbidding
    # successful request/answer/hint receipt must have a reachable violation.
    check("repair-is-reachable", {"SeparateEntities": "TRUE"}, "NoRepairWitness",
          extension='\nNoRepairWitness == \\A p \\in Peers, c \\in Counters :\n'
                    '    ~(s.out[Request(p,c)] = "sent" /\\\n'
                    '      s.inbox[Origin(c)][Request(p,c)] = "done" /\\\n'
                    '      c \\in s.hints[p] /\\ c \\in s.received[p])\n')


def check_settings():
    # The guarded profile includes one failure, below the inbound retry cap.
    for switch, assertion in (("AtomicGroups", "CompletedCoherent"),
                              ("RetryFailures", "LatestWins")):
        constants = {"FailureBudget": "1"}
        check("settings-" + switch + "-guarded", constants, assertion,
              module="SyncSettings", fails=False)
        check("settings-" + switch + "-mutated",
              {**constants, switch: "FALSE"}, assertion, module="SyncSettings")
    for guarded, fails in (("TRUE", False), ("FALSE", True)):
        check("settings-equal-stamps-" + guarded,
              {"EqualStamps": "TRUE", "DeterministicTies": guarded}, "Converged",
              module="SyncSettings", fails=fails)
    for versioned, fails in (("TRUE", False), ("FALSE", True)):
        check("settings-flag-versions-" + versioned,
              {"Timestamped": versioned}, "Converged",
              module="SyncSettings", profile="SyncSettingsFlags", fails=fails)


def check_preference_edits():
    for profile in ("SyncPreferenceEdits", "SyncPreferenceEditsFlags"):
        for switch, assertion in (("MonotoneLocalStamps", "LocalVersionsAdvance"),
                                  ("PublishCommittedSnapshot", "OnlyCommittedSnapshots")):
            for guarded, fails in (("TRUE", False), ("FALSE", True)):
                check(profile + "-" + switch + "-" + guarded,
                      {switch: guarded}, assertion, profile=profile,
                      module="SyncPreferenceEdits", fails=fails)
    # With at most two edits per peer, a stamp above two requires a local
    # edit after learning another peer's version, not only isolated edits.
    check("preference-causal-edit-reachable", {}, "NoCausalEditWitness",
          module="SyncPreferenceEdits",
          extension='\nNoCausalEditWitness == \\A v \\in committed : v[1] <= MaxEdits\n')


if __name__ == "__main__":
    main()
    check_settings()
    check_preference_edits()
