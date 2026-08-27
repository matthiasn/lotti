

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
