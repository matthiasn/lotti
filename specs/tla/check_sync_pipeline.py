#!/usr/bin/env python3
"""Require targeted counterexamples and document the pipeline's liveness limits.

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


def check(name, constants, assertion, *, temporal=False, extension="", fails=True):
    config = (HERE / "SyncPipeline.cfg").read_text()
    for key, value in constants.items():
        config, count = re.subn(
            rf"(?m)^    {key} = .*$", f"    {key} = {value}", config
        )
        if count != 1:
            raise ValueError(f"{name}: unknown/duplicate constant {key}")
    config = re.sub(r"(?m)^(INVARIANTS|PROPERTIES) .*\n?", "", config)
    config += f"{'PROPERTY' if temporal else 'INVARIANT'} {assertion}\n"
    spec = (HERE / "SyncPipeline.tla").read_text()
    separator = "\n" + "=" * 77
    spec = spec.replace(separator, extension + separator)
    with tempfile.TemporaryDirectory(prefix=f"sync-pipeline-{name}-") as directory:
        work = Path(directory)
        shutil.copy2(HERE / "tlc.sh", work / "tlc.sh")
        (work / "SyncPipeline.tla").write_text(spec)
        (work / "SyncPipeline.cfg").write_text(config)
        result = subprocess.run(
            ["bash", str(work / "tlc.sh"), "SyncPipeline"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            timeout=300, check=False,
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
    check("lost-unobserved-tail", {"MaxCounter": "1", "MaxFaults": "1",
          "FaultKinds": '{"receive"}'}, "CommittedReachesPeer", temporal=True)
    check("lost-tail-receipt", {"MaxCounter": "1", "MaxFaults": "1",
          "FaultKinds": '{"receipt"}'}, "EveryCommitReceipted", temporal=True,
          extension='\nEveryCommitReceipted == \\A p \\in Peers, c \\in Counters :\n'
                    '    c \\in s.committed ~> c \\in s.received[p]\n')
    # The conditional gap claim must exercise the repair channel; forbidding
    # successful request/answer/hint receipt must have a reachable violation.
    check("repair-is-reachable", {"SeparateEntities": "TRUE"}, "NoRepairWitness",
          extension='\nNoRepairWitness == \\A p \\in Peers, c \\in Counters :\n'
                    '    ~(s.out[Request(p,c)] = "sent" /\\\n'
                    '      s.inbox[Origin(c)][Request(p,c)] = "done" /\\\n'
                    '      c \\in s.hints[p] /\\ c \\in s.received[p])\n')


if __name__ == "__main__":
    main()
