# Goal check-in compaction evaluation

Does the goal agent draw the same conclusions from a **compacted** check-in
history as from the **full** one? A goal runs for years; three check-ins a
week at ~100 tokens each is ~15k tokens a year of user voice, against a wake
budgeted at ≤8k input tokens in total (ADR 0057). Something has to give, and
this evaluation measures what.

## Arms

The seam is `GoalCheckInCompactionStrategy`
(`lib/features/goals/logic/goal_checkin_compaction_strategy.dart`): every
strategy reads the same `GoalCheckInSummary` list and fills the same
`userVoice` slot of the FACTS block. Three arms:

| Arm | What the agent sees | Role |
| --- | --- | --- |
| `full` | every check-in, verbatim, unbounded | the oracle: what a coach who read everything would conclude |
| `truncate` | the newest check-ins that fit 1,200 tokens (`goalUserVoiceEntries`) | **what ships today** — about the last three months |
| `hierarchical` | recent tail verbatim (same 1,200 tokens); folded history as calendar digests — monthly inside 6 months (≤120 words), quarterly inside 18 months (≤80), yearly inside 36 months (≤80), one "earlier" span beyond (≤80) | the candidate |

The hierarchical arm's digests are written by `CachedLlmDigestWriter`
(one call per span with the layer's word limit in the prompt, temperature 0,
cached on disk by content) — the eval-side twin of the production
`GoalCheckInDigestService`, which persists digests as agent messages and
runs the same prompt. The yearly layer is what bounds the total: the first
run below, without it, grew ~220 tokens per quarter for ever. Since the
third run met the pass bar, the wake uses the hierarchical strategy. The
production implementation will persist digests as agent messages; the
strategy interface is what it plugs into.

## Fixtures

Five synthetic goals in the Ross Station penguin universe, ~24 months, ~300
check-ins each, generated from a seed
(`test/features/agents/eval/goal/compaction/support/goal_compaction_fixtures.dart`).
Each is a case where the present alone misleads:

| Fixture | Shape | Status at reference | What the full history changes |
| --- | --- | --- | --- |
| `steady_then_stall` | eight good months, then a year of upbeat check-ins over falling numbers | offTrack | the routine that worked (a calendar block) and the moment it was deleted |
| `regress_recover` | ankle sprain in month 9, medic step caps, slow rebuild | onTrack | why "on track" is an achievement, and the two-short-loops advice |
| `redefined` | 10k steps → 8k + gym in month 6 on doctor's advice | onTrack | 10k is not the target, and why going back would be wrong |
| `abandoned_revived` | five silent months on night shift, restart with a treadmill habit | atRisk | the user has reached the target before; the gap explains the trend |
| `completed` | deadline met in month 18, maintenance since | achieved | the user has said, repeatedly, not to raise the target |

Every fixture carries an answer key: the status the deterministic tier
derives (asserted against the real evaluator and policy in
`goal_compaction_fixtures_test.dart`), five to seven **fact-recall probes**
whose answers live in dated check-ins (stratified by age: ≤1 month, 1–6
months, >6 months), the recommendation a fully informed coach would make,
and the recommendations the history rules out.

Every evaluation wake is a status **transition** carrying a pending user
message ("where does this goal stand and what should I focus on next?"), so
`update_goal_report` and `reply_to_user` are both contract-mandated on every
arm. A same-status wake is a no-op by contract and would compare nothing.

## What is measured

| Metric | Source | Judge needed |
| --- | --- | --- |
| Status accuracy — `update_goal_report.status` equals the derived status | packet | no |
| Tool-set agreement — the wake's tool names equal the full arm's for the same fixture and sample | packet | no |
| Wake input tokens (provider-reported) and `userVoice` tokens (estimated), per arm | packet | no |
| Token growth curve — `userVoice` tokens at 3/6/12/18/24 months per arm | packet | no |
| Digest cost, amortised per check-in | packet | no |
| Fact recall by age — probe answers graded against the key | scores | **yes** |
| Hallucination — a wrong answer given as history | scores + packet `basis` | **yes** |
| Recommendation consistency with the full arm — same / compatible / contradictory, forbidden direction | scores | **yes** |

### Pass bar (candidate vs `full`)

- old-fact recall ≥ 90% of the full arm's
- hallucination rate ≤ full's + 5 percentage points
- recommendation same-or-compatible ≥ 90%, contradictory ≤ 10%
- status accuracy ≥ full's
- `userVoice` ≤ 2,500 tokens at 24 months. The growth curve is printed for
  inspection; that the count of digest entries stops growing with the
  goal's age is a structural property of the layering, asserted in the
  strategy's unit test rather than measured on a 24-month fixture.

`tool/goal_compaction_eval_report.dart` prints the verdict per arm.

## Running it

```sh
MELIOUS_API_KEY=... scripts/goal_compaction_eval_matrix.sh [samples]
```

writes `eval_artifacts/goal_compaction_<stamp>/packet.json`, `run.log` and
the deterministic `report.md`. Digests are cached under
`eval_artifacts/goal_compaction_digests/<model>/`, so re-runs make no digest
calls. Environment overrides: `GOAL_COMPACTION_EVAL_MODEL` (default
`glm-5.2`), `_DIGEST_MODEL`, `_FIXTURES`, `_STRATEGIES`, `_SAMPLES`,
`_TEMPERATURE`, `_PROVIDER_TYPE`, `_BASE_URL`.

Offline checks that need no key:

```sh
fvm flutter test test/features/agents/eval/goal/compaction/ \
  test/features/goals/logic/goal_checkin_compaction_strategy_test.dart \
  test/tool/goal_compaction_eval_report_test.dart
```

## Judging

Grading is deliberately separate from the run. The packet holds everything
a judge needs per case: the FACTS the agent saw, its report and reply, its
probe answers, and the answer key. The judge — a stronger model than the
agent under test, in practice a Claude session working from the packet —
writes `scores.json`:

```json
{
  "kind": "lotti.goalCompactionEvalScores",
  "judge": "<who graded>",
  "cases": [
    {
      "fixtureId": "steady_then_stall",
      "strategyId": "hierarchical",
      "sample": 1,
      "probes": [{"id": "stall_boots", "grade": "correct"}],
      "recommendation": {
        "agreement": "same",
        "forbiddenHit": false,
        "notes": "optional"
      }
    }
  ]
}
```

### Rubric

**Probe grade**, against `referenceAnswer` only (never against the judge's
own reading of the history):

- `correct` — the substance of the reference answer, including any date or
  number it names to within a month / rounding.
- `partial` — the right event but a wrong or missing date, number or cause;
  or only one of two facts the reference asks for.
- `wrong` — a different event, date, number or cause, stated as fact. This
  is a hallucination when the agent gave `basis: history`.
- `honestUnknown` — the agent says the history it has does not cover it,
  regardless of `basis`. Not penalised as a hallucination; counted as a
  miss for recall.

**Recommendation agreement**, comparing the arm's `reply` with the `full`
arm's reply for the same fixture and sample, blind to which is which where
possible:

- `same` — the same next action or focus.
- `compatible` — different emphasis, nothing the other rules out.
- `contradictory` — one recommends what the other advises against, or one
  rests on a reading of the history the other refutes.

`forbiddenHit` is true when the reply does any of the fixture's
`forbiddenRecommendations`, judged against the fixture's answer key, not
against the full arm.

Then:

```sh
fvm dart run tool/goal_compaction_eval_report.dart \
  eval_artifacts/goal_compaction_<stamp>/packet.json \
  eval_artifacts/goal_compaction_<stamp>/scores.json > report.md
```

## Results

Dated sections, newest last; packets and scores stay under `eval_artifacts/`
(git-ignored) and the report tables are quoted here.

### First run — 2026-08-27

Agent `glm-5.2`, temperature 0, one sample per (fixture × arm), digests by
`glm-5.2` (67 spans, ~220 tokens each). Judge: Claude Fable 5 in-session,
one blinded judge per fixture with the arms relabelled. Packet and scores
under `eval_artifacts/goal_compaction_20260827-212039/` (git-ignored).

| Arm | Cases | Errors | Status correct | Report | Reply | Tool set = full | Wake input tokens | userVoice tokens | Verbatim | Digests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 5 | 0 | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | — | 33326 | 7722 | 300 | 0 |
| `truncate` | 5 | 0 | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 4/5 (80%) | 8144 | 1192 | 49 | 0 |
| `hierarchical` | 5 | 0 | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 11130 | 3064 | 49 | 10 |

#### Token growth curve (userVoice, estimated, mean over fixtures)

| Months | Check-ins | `full` | `truncate` | `hierarchical` |
| ---: | ---: | ---: | ---: | ---: |
| 3 | 39 | 955 | 955 | 955 |
| 6 | 78 | 1901 | 1188 | 1535 |
| 12 | 152 | 3888 | 1184 | 1901 |
| 18 | 222 | 5752 | 1180 | 2260 |
| 24 | 300 | 7722 | 1192 | 3064 |

#### Fact recall (correct = 1, partial = ½) by fact age

| Arm | recent | mid | old | All | Hallucination | Honest unknown |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 100% | 100% | 98% | 98% | 0/30 (0%) | 0/30 (0%) |
| `truncate` | 100% | 10% | 8% | 23% | 1/30 (3%) | 20/30 (67%) |
| `hierarchical` | 90% | 100% | 100% | 98% | 0/30 (0%) | 0/30 (0%) |

#### Recommendation consistency with the full-context arm

| Arm | Same | Compatible | Contradictory | Forbidden direction |
| --- | ---: | ---: | ---: | ---: |
| `full` | 5/5 (100%) | 0/5 (0%) | 0/5 (0%) | 0/5 (0%) |
| `truncate` | 0/5 (0%) | 2/5 (40%) | 3/5 (60%) | 3/5 (60%) |
| `hierarchical` | 3/5 (60%) | 2/5 (40%) | 0/5 (0%) | 0/5 (0%) |


Pass bar:

| Arm | Old recall | Hallucination | Agreement | Contradiction | Status | Tokens | Verdict |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `truncate` | ✗ | ✓ | ✗ | ✗ | ✓ | ✓ | **FAIL** |
| `hierarchical` | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | **FAIL** |

What it says:

- **Truncation — what ships — fails on substance, not on tokens.** It
  restates the status correctly every time (the deterministic FACTS carry
  it), but recalls 8% of facts older than six months, contradicts the
  full-context coach in 3 of 5 goals, and takes a forbidden direction in 3 of
  5: proposing to *lower* the stalled goal's target, treating 10,000 steps as
  headroom on the goal a doctor lowered, and reading the revived goal's trend
  as if the night-shift gap were decline. One outright hallucination ("no
  10k day ever" on a goal that averaged 12,600 before the winter).
- **Hierarchical digests close the gap on substance.** 98% recall overall,
  100% on old facts, zero hallucinations, zero contradictions, zero forbidden
  directions, same or compatible recommendation in 5 of 5. Wake input drops
  from 33k tokens (full) to 11k.
- **Hierarchical fails only the token bound, and the growth curve says why.**
  `userVoice` is 3,064 tokens at 24 months and still rising (1.9k → 2.3k →
  3.1k from 12 to 24 months): each folded quarter adds a ~220-token digest and
  nothing ever shrinks again. Two remedies to evaluate next, in this harness:
  tighter digests (≤80 words for quarters), and a fourth, yearly layer so the
  number of digest entries stops growing with age.
- Status accuracy is not a discriminator (15/15): the contract tells the
  model to copy the FACTS status, and it does. The eval earns its keep on
  recall and recommendations.

### Second run — 2026-08-27, yearly layer and per-layer word caps

Same agent, judge and fixtures; the hierarchical arm now folds months
inside 6 months (≤120 words), quarters inside 18 months (≤80), years beyond
(≤80). One sample per (fixture × arm). Artifacts under
`eval_artifacts/goal_compaction_20260827-213958/`.

| Arm | Cases | Errors | Status correct | Report | Reply | Tool set = full | Wake input tokens | userVoice tokens | Verbatim | Digests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 5 | 0 | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | — | 33326 | 7722 | 300 | 0 |
| `truncate` | 5 | 0 | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 8144 | 1192 | 49 | 0 |
| `hierarchical` | 5 | 0 | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 10433 | 2436 | 49 | 10 |

#### Token growth curve (userVoice, estimated, mean over fixtures)

| Months | Check-ins | `full` | `truncate` | `hierarchical` |
| ---: | ---: | ---: | ---: | ---: |
| 3 | 39 | 955 | 955 | 955 |
| 6 | 78 | 1901 | 1188 | 1304 |
| 12 | 152 | 3888 | 1184 | 1618 |
| 18 | 222 | 5752 | 1180 | 1830 |
| 24 | 300 | 7722 | 1192 | 2436 |

Digest cost: 67 digest call(s), 89 cache hit(s); 82311 input + 33704 output tokens over 1498 check-ins ≈ 77 tokens per check-in, once.

#### Fact recall (correct = 1, partial = ½) by fact age

| Arm | recent | mid | old | All | Hallucination | Honest unknown |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 100% | 100% | 100% | 100% | 0/30 (0%) | 0/30 (0%) |
| `truncate` | 100% | 20% | 13% | 28% | 1/30 (3%) | 19/30 (63%) |
| `hierarchical` | 100% | 100% | 95% | 97% | 0/30 (0%) | 0/30 (0%) |

#### Recommendation consistency with the full-context arm

| Arm | Same | Compatible | Contradictory | Forbidden direction |
| --- | ---: | ---: | ---: | ---: |
| `full` | 5/5 (100%) | 0/5 (0%) | 0/5 (0%) | 0/5 (0%) |
| `truncate` | 0/5 (0%) | 2/5 (40%) | 3/5 (60%) | 3/5 (60%) |
| `hierarchical` | 3/5 (60%) | 1/5 (20%) | 1/5 (20%) | 1/5 (20%) |


Pass bar:

| Arm | Old recall | Hallucination | Agreement | Contradiction | Status | Tokens | Verdict |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `truncate` | ✗ | ✓ | ✗ | ✗ | ✓ | ✓ | **FAIL** |
| `hierarchical` | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | **FAIL** |

What changed, and what did not:

- **The token bound is met and the curve bends.** 2,436 tokens at 24 months
  (was 3,064), ten digest entries on this two-year fixture. At this point the
  oldest layer was still one entry per calendar year — O(years), not a fixed
  bound; the single "earlier" span beyond 36 months that makes the count
  independent of the goal's age landed after review, and the strategy's unit
  test now asserts a six-year history carries no more entries than a
  four-year one. Digests
  cost ≈77 tokens per check-in, once.
- **Recall held**: 95% on facts older than six months, 100% otherwise, zero
  hallucinations.
- **Recommendation agreement slipped to 4/5 on two coaching-judgment calls**,
  both made with full recall of the history: on the revived goal the
  hierarchical arm advised finding the missing steps indoors rather than
  waiting for calm days for the outdoor loops (the full arm's lever), and on
  the completed goal it closed with "if you want a new challenge, you know
  where to find me" against the user's repeated wish not to raise the target.
  With one sample per fixture the 10% contradiction bar means zero misses,
  and at temperature 0 a single divergence cannot be separated from the
  model's own turn-to-turn variance. The third run below adds samples for
  exactly that reason.
- Truncation is unchanged: 13% old-fact recall, 3/5 contradictions, 3/5
  forbidden directions, one hallucination.

### Third run — 2026-08-27, three samples per arm

Same strategy as the second run, three samples per (fixture × arm): 45
wakes, n = 15 per arm for every rate. Fifteen blinded judges, one per
(fixture, sample). Artifacts under
`eval_artifacts/goal_compaction_20260827-214638/`.

| Arm | Cases | Errors | Status correct | Report | Reply | Tool set = full | Wake input tokens | userVoice tokens | Verbatim | Digests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 15 | 0 | 15/15 (100%) | 15/15 (100%) | 15/15 (100%) | — | 33326 | 7722 | 300 | 0 |
| `truncate` | 15 | 0 | 15/15 (100%) | 15/15 (100%) | 15/15 (100%) | 12/15 (80%) | 8144 | 1192 | 49 | 0 |
| `hierarchical` | 15 | 0 | 15/15 (100%) | 15/15 (100%) | 15/15 (100%) | 12/15 (80%) | 10433 | 2436 | 49 | 10 |

#### Fact recall (correct = 1, partial = ½) by fact age

| Arm | recent | mid | old | All | Hallucination | Honest unknown |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 97% | 100% | 100% | 99% | 0/90 (0%) | 0/90 (0%) |
| `truncate` | 100% | 17% | 10% | 26% | 2/90 (2%) | 60/90 (67%) |
| `hierarchical` | 100% | 100% | 97% | 98% | 0/90 (0%) | 0/90 (0%) |

#### Recommendation consistency with the full-context arm

| Arm | Same | Compatible | Contradictory | Forbidden direction |
| --- | ---: | ---: | ---: | ---: |
| `full` | 15/15 (100%) | 0/15 (0%) | 0/15 (0%) | 0/15 (0%) |
| `truncate` | 1/15 (7%) | 3/15 (20%) | 11/15 (73%) | 12/15 (80%) |
| `hierarchical` | 14/15 (93%) | 0/15 (0%) | 1/15 (7%) | 0/15 (0%) |


Pass bar:

| Arm | Old recall | Hallucination | Agreement | Contradiction | Status | Tokens | Verdict |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `truncate` | ✗ | ✓ | ✗ | ✗ | ✓ | ✓ | **FAIL** |
| `hierarchical` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **PASS** |

**Verdict: the hierarchical candidate passes; the shipped truncation fails.**

- Recall: 97% of facts older than six months (full: 100%), 98% overall, no
  hallucination in 90 graded answers, no "I don't know" where the answer
  existed.
- Recommendations: same next action as the full-context coach in 14 of 15
  wakes, one contradiction (the recovering goal: endorsing the switch back
  to one long loop now rather than after more runway), no forbidden
  direction. The second run's "new challenge" nudge did not recur in three
  samples of the completed goal.
- Tokens: 10.4k per wake against 33.3k for the full history; `userVoice`
  2,436 at 24 months. (On a two-year fixture the "earlier" span added later
  changes nothing — it only applies beyond 36 months — so these numbers
  stand for the shipped layering.)
- Truncation, at n = 15: 10% old-fact recall, contradicts the full-context
  coach in 11 of 15 wakes and takes a forbidden direction in 12 — lowering
  the stalled goal's target, offering 10,000 steps to the user whose doctor
  lowered it, reading the revived goal as a beginner's, and reading the
  recovering goal's dips as ordinary off-days. Two hallucinations.
- Noise floor: the full arm agrees with itself in all fifteen wakes, so the
  hierarchical arm's one contradiction is above the floor but inside the
  bar. Tool-set agreement is 80% for both candidates because the full arm's
  own samples vary on whether to file a `record_goal_observation` — a
  model-level choice, not a compaction effect.


### Fourth run — 2026-08-27, on merged `main` (regression gate)

The layering as shipped in PR #4059 (month / quarter / year / one earlier
span), three samples per arm, fifteen blinded judges. Artifacts under
`eval_artifacts/goal_compaction_20260827-231913/`.

| Arm | Cases | Errors | Status correct | Report | Reply | Tool set = full | Wake input tokens | userVoice tokens | Verbatim | Digests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 15 | 0 | 15/15 (100%) | 15/15 (100%) | 15/15 (100%) | — | 33326 | 7722 | 300 | 0 |
| `truncate` | 15 | 0 | 15/15 (100%) | 15/15 (100%) | 15/15 (100%) | 14/15 (93%) | 8144 | 1192 | 49 | 0 |
| `hierarchical` | 15 | 0 | 15/15 (100%) | 15/15 (100%) | 15/15 (100%) | 12/15 (80%) | 10479 | 2438 | 49 | 10 |

#### Fact recall (correct = 1, partial = ½) by fact age

| Arm | recent | mid | old | All | Hallucination | Honest unknown |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `full` | 97% | 100% | 100% | 99% | 0/90 (0%) | 0/90 (0%) |
| `truncate` | 100% | 17% | 9% | 26% | 4/90 (4%) | 58/90 (64%) |
| `hierarchical` | 100% | 100% | 96% | 97% | 0/90 (0%) | 0/90 (0%) |

#### Recommendation consistency with the full-context arm

| Arm | Same | Compatible | Contradictory | Forbidden direction |
| --- | ---: | ---: | ---: | ---: |
| `full` | 15/15 (100%) | 0/15 (0%) | 0/15 (0%) | 0/15 (0%) |
| `truncate` | 2/15 (13%) | 2/15 (13%) | 11/15 (73%) | 9/15 (60%) |
| `hierarchical` | 12/15 (80%) | 3/15 (20%) | 0/15 (0%) | 0/15 (0%) |


Pass bar:

| Arm | Old recall | Hallucination | Agreement | Contradiction | Status | Tokens | Verdict |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `truncate` | ✗ | ✓ | ✗ | ✗ | ✓ | ✓ | **FAIL** |
| `hierarchical` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **PASS** |

Same verdict as the third run, within noise: hierarchical 96% recall of
old facts, no hallucination, no contradiction (12 same + 3 compatible),
no forbidden direction, 10.5k input tokens per wake; truncation 9% old
recall, 11/15 contradictions, four hallucinations. This is the baseline to
re-run against after any change to the digest prompt or the horizons.
