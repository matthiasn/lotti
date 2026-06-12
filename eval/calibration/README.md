# Judge Calibration Sets

Human calibration labels live outside trace artifacts. They identify a trace
cell, bind that label to the scenario/profile/prompt-variant digests that were
reviewed, and record the expected human judgment. They must not copy prompt
text, model output, transcripts, tool arguments, or secret values.

Use a JSON file with this shape:

```json
{
  "version": "human-gold-v1",
  "judgeCalibrationSetVersion": "uncalibrated",
  "labels": [
    {
      "key": {
        "scenarioId": "task_release_notes",
        "profileName": "frontier-fast",
        "agentDirectiveVariantName": "default",
        "trialIndex": 0
      },
      "scenarioDigest": "sha256:<digest from trace.provenance.scenarioDigest>",
      "profileDigest": "sha256:<digest from trace.provenance.profileDigest>",
      "agentDirectiveVariantDigest": "sha256:<digest from trace.provenance.agentDirectiveVariantDigest>",
      "traceDigest": "sha256:<digest copied from JudgeVerdict.traceDigest>",
      "verdictDigest": "sha256:<digest of parsed JudgeVerdict JSON>",
      "expectedPass": true,
      "goalAttainmentMin": 4,
      "goalAttainmentMax": 5,
      "qualityMin": 4,
      "qualityMax": 4,
      "efficiencyMin": 3,
      "efficiencyMax": 4,
      "labeler": "reviewer-a",
      "labelerCount": 2,
      "adjudicationStatus": "adjudicated",
      "independentReviews": [
        {
          "reviewer": "reviewer-a",
          "expectedPass": true,
          "goalAttainment": 4,
          "quality": 4,
          "efficiency": 3,
          "blindToJudgeVerdict": true,
          "blindToModelIdentity": true,
          "blindToPeerVotes": true
        },
        {
          "reviewer": "reviewer-b",
          "expectedPass": true,
          "goalAttainment": 5,
          "quality": 4,
          "efficiency": 4,
          "blindToJudgeVerdict": true,
          "blindToModelIdentity": true,
          "blindToPeerVotes": true
        }
      ],
      "rationale": "Short non-secret note explaining the human label."
    }
  ]
}
```

Then run:

```bash
EVAL_CALIBRATION=eval/calibration/judge_gold_v1.json \
  eval/run_level2.sh calibrate <runId>
```

To create a review queue from a judged run, generate a template first:

```bash
EVAL_CALIBRATION_TEMPLATE=/private/tmp/judge_gold_v1.template.json \
  eval/run_level2.sh template <runId>
```

`template` requires an explicit `<runId>`, a verified trace/verdict matrix, and
an output path. It refuses to overwrite an existing template unless
`EVAL_CALIBRATION_TEMPLATE_OVERWRITE=1` is set. For protected external
catalogs, write the template and completed calibration file outside the repo or
acknowledge the scenario-id exposure with `LOTTI_EVAL_PROTECTED_TRACE_ACK=1`.
Template paths must end with `.template.json`; this keeps template generation
from overwriting a completed gold-label file.

By default, template generation includes every judged trace. For a smaller but
coverage-aware human queue, set `EVAL_CALIBRATION_TEMPLATE_MAX_ROWS=<n>`.
Sampling is deterministic and validates the full judged run before selecting
rows. The `stratified-v2` selector covers agent kinds, model classes, prompt
variants, judge pass/fail outcomes, protected vs. non-protected traces, and
primary capabilities before topping up by stable trace key. If `<n>` is too
small to cover those strata, template generation fails instead of writing a
misleading review queue. The template records aggregate selection counts,
cross-cell counts, and digests; it does not
store raw prompt text, model output, protected catalog ids, or protected
scenario-id lists in selection metadata. A bounded template is only a review
queue. The completed labels must still pass calibration coverage/agreement and
tuning-readiness gates.

Template files use a separate schema:

```json
{
  "calibrationTemplateSchemaVersion": 2,
  "version": "human-gold-v1",
  "judgeCalibrationSetVersion": "uncalibrated",
  "sourceRun": {
    "runId": "20260610-120000",
    "manifestDigest": "sha256:<manifest digest>",
    "scenarioSetDigest": "sha256:<scenario-set digest>",
    "profileSetDigest": "sha256:<profile-set digest>",
    "agentDirectiveVariantSetDigest": "sha256:<prompt-variant-set digest>",
    "scenarioCatalogEvidence": {
      "scenarioSetDigest": "sha256:<scenario-set digest>",
      "publicScenarioCount": 0,
      "externalScenarioCount": 20,
      "protectedHoldout": true,
      "protectedScenarioCount": 20,
      "protectedHoldoutScenarioCount": 20
    }
  },
  "labelTemplates": [
    {
      "key": {
        "scenarioId": "task_release_notes",
        "profileName": "frontier-fast",
        "agentDirectiveVariantName": "default",
        "trialIndex": 0
      },
      "scenarioDigest": "sha256:<trace.provenance.scenarioDigest>",
      "profileDigest": "sha256:<trace.provenance.profileDigest>",
      "agentDirectiveVariantDigest": "sha256:<trace.provenance.agentDirectiveVariantDigest>",
      "traceDigest": "sha256:<JudgeVerdict.traceDigest>",
      "verdictDigest": "sha256:<digest of JudgeVerdict JSON>",
      "expectedPass": null,
      "goalAttainmentMin": null,
      "goalAttainmentMax": null,
      "qualityMin": null,
      "qualityMax": null,
      "efficiencyMin": null,
      "efficiencyMax": null,
      "adjudicationStatus": "needs_review",
      "rationale": ""
    }
  ]
}
```

A template is intentionally not accepted by `calibrate`. Humans must review the
trace, fill the pass decision and inclusive score bands, then move entries from
`labelTemplates` into a completed `labels` array. Do not copy judge scores as
human labels; the template includes `traceDigest` and `verdictDigest` only to
make stale reviewed artifacts detectable. Preserve the template's
`judgeCalibrationSetVersion` in the completed calibration file: it records the
judge calibration provenance used to produce the verdicts being audited, while
`version` names the human gold-label set. This is especially important for the
first calibration pass, where the judge verdicts should have
`judge.calibrationSetVersion: "uncalibrated"` but the human label set can still
be named `human-gold-v1`.

Completed labels must carry human-review provenance: non-empty `labeler`,
non-empty `rationale`, `labelerCount >= 1`, and `adjudicationStatus` must be
`reviewed` or `adjudicated`. The parser rejects rows left as `needs_review`.
For multi-review rows, keep exactly one final gold label per trace and put the
pre-adjudication votes in `independentReviews`. Each independent review stores
only a pseudonymous reviewer id, expected pass, the three rubric scores, and
booleans declaring whether that reviewer was blind to the judge verdict, exact
model identity, and peer votes. Do not store per-review rationale or copied
trace text in these vote records; keep one final non-secret adjudication
rationale on the completed gold label.
Duplicate completed labels for the same trace remain invalid. When
`independentReviews` is present it must contain at least two unique reviewers
and `labelerCount` must match that review count. If reviewers disagree with the
final gold label and `adjudicationStatus` is still `reviewed`, the report marks
the row as unresolved human disagreement. Use `adjudicated` only after a human
has intentionally resolved that disagreement.

The score bands are inclusive. Use a wider band when human reviewers agree the
rubric permits more than one reasonable score; keep `expectedPass` strict.

Completed calibration files must include `traceDigest`, `verdictDigest`, and
`agentDirectiveVariantDigest` for every label, and each key must include
`agentDirectiveVariantName`. `traceDigest` binds the label to the trace
reviewed by the judge; `verdictDigest` binds the human label to the parsed
`JudgeVerdict` JSON that was reviewed; `agentDirectiveVariantDigest` binds the
label to the exact prompt/directive arm. A label whose scenario/profile/prompt
variant digest, trace digest, or verdict digest no longer matches the run is
reported as `staleGoldLabel` and is not counted as judge disagreement.
Every digest field must use the full `sha256:` plus 64 lowercase hex shape.
Passing labels must allow a passing score in every dimension.

The report compares `JudgeVerdict` scores against the labels, prints gold-label
coverage, pass and score agreement, Wilson intervals, false-pass/false-fail
counts, human-human pair counts, human pass/score agreement, unresolved human
disagreement, and slices agreement by primary capability, model class, and
prompt variant, plus model-class/prompt-variant pairs. It also surfaces
duplicate labels, missing traces, missing verdicts, stale labels, judged traces
without labels, verdicts graded under a different
`judge.calibrationSetVersion`, and verdicts where the judge saw exact
provider/model identity. A calibration-version mismatch is a provenance failure,
not judge agreement data. The default model-class tuning policy requires enough
independent human-review pairs, high human pass/score agreement with Wilson
lower-bound checks, and zero unresolved human disagreement before the human
gold set can support tuning claims. It also requires independent human reviews
to be blinded to judge verdicts, model identity, and peer votes.

For backwards compatibility, the parser still accepts legacy
`goalAttainment`/`quality`/`efficiency` plus `scoreTolerance` fields, but new
calibration files should use explicit min/max bands.
