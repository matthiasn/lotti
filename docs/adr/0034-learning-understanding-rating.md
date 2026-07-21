# ADR 0034: Learning Understanding Rating

- Status: Proposed
- Date: 2026-07-18

## Context

A single opaque score encourages false precision and gives the learner no path
to improve. Pure prose feedback is harder to inspect, but normalizing a narrow
one-dimension check to 0–100 also overstates what was observed. Validation and
novel transfer are different constructs, and answer-bearing hints can measure
immediate reproduction rather than independently retrievable understanding.

Lotti's journal rating catalog stores subjective user ratings. A verifier
assessment is evidence-based, model-produced, citation-bearing, and conditional
on one question, evidence snapshot, assistance interpretation, and calibration
slice, so it requires separate semantics and storage.

Some rating outcomes appropriately lead to later practice or verification, but
an assessment must not manufacture its own recheck date. Review timing must be
derived independently from authenticated learner activity, and recording that
activity must never be mistaken for new evidence of rated understanding.

## Decision

Use a versioned multidimensional assessment with explicit rating availability.

1. A pre-response blueprint marks which of five core 0–4 dimensions it elicits:
   correctness, causal/mechanistic understanding, completeness/relevance,
   boundaries/trade-offs, and validation. Unelicited dimensions are
   `notObserved`, not zero. An elicited dimension that cannot be judged reliably
   is `notRateable(reasonCode)`, never `notObserved`, zero, or a learner gap. A
   genuinely novel prediction/application may produce
   a separate unweighted transfer result; transfer does not reserve or contribute
   to a numeric score band. Versioned anchors assess the scoped construct:
   mechanistic level 4 does not require a separate prediction, completeness does
   not reward concision, and transfer does not absorb validation.
2. Initial core weights are 30/25/20/15/10. Each operation has a versioned
   minimum-information profile: Explain requires correctness/mechanism/
   completeness; Predict and Apply require correctness/mechanism/boundaries;
   Debug requires correctness/mechanism/validation; Compare requires
   correctness/completeness/boundaries.
3. A `LearningAssessmentEntity` has outcome `assessed` or `notAssessed`. Only an
   `assessed` artifact has `ratingAvailability`: `aggregate`, `dimensionOnly`,
   or `practiceOnly`. Aggregate requires every operation-required dimension, a
   blueprint `admissionCeiling == aggregateEligible`, an eligible assistance
   interpretation, and a cleared response-calibration slice keyed in part by
   the pinned assessment-validator/scorer/rating-policy version. Dimension-only
   shows valid observed levels and feedback but no aggregate or formative label.
   Practice-only follows answer-bearing support before submission and cannot
   produce aggregate, demonstrated label, transfer result, concept-history
   promotion, or spacing extension. **Not assessed** is the separate outcome
   only after a schema-valid evaluator output and actual model execution when
   deterministic request-local post-inference evidence or evaluator reliability
   is inadequate even for a numeric dimension judgment. It contains no numeric dimension
   levels: elicited dimensions are `notRateable` and unelicited dimensions
   remain `notObserved`.
   An assessed dimension-only result may mix numeric levels with `notRateable`,
   but any required `notRateable` dimension prevents aggregate availability.
   Neither nonnumeric state is scored, labeled, displayed as performance, or
   promoted. Pre-call evidence loss, invalid schema, exhausted repair, or an
   uncleared calibration route creates no learner assessment; static self-check
   guidance is not rating availability or history. `LearningAssessmentEntity`,
   the evaluator-response schema, and assessment-validation schema contain no
   `recheckAt`, recheck-date, due-date, or reminder field. They may contain an
   actionable but untimed next-practice suggestion. A model response that
   supplies review timing is schema-invalid; only a permitted bounded repair
   that omits the field may proceed, and no evaluator value becomes scheduling
   authority.
4. Deterministic code—not the evaluator—calculates optional 0–100 core detail
   across observed weights only after aggregate eligibility. Perfect
   non-transfer performance may receive the full supported score; no band is
   withheld for transfer.
5. **Objective demonstrated in this check** requires score at least 75,
   correctness at least 3, every operation-required dimension at least 3, and no
   material contradiction. **Core mechanism demonstrated in this check** adds
   causal/mechanistic understanding at least 3 for a mechanism-eliciting item.
   **Developing explanation/Objective partly demonstrated** applies at 50–74 or
   when a required dimension remains level 2. **Core idea needs review/Objective
   needs review** applies below 50, when correctness or another required
   dimension is at most 1, or when a material core contradiction remains.
6. **Transfer demonstrated in this check** is a separate result requiring an
   administered genuinely novel item, transfer level 4, correctness and causal/
   mechanistic understanding at least 3, no material contradiction, and an
   eligible assistance condition. Level 4 requires correct mechanism-based
   adaptation to changed constraints; validation remains a separate core
   dimension when the question elicits it. Transfer is not proof of durable
   general transfer.
7. Accessibility accommodations do not reduce eligibility. Unaided-first and a
   separately calibrated open-book slice may receive aggregate ratings; every
   open-book label is explicitly qualified. Assistance is frozen from support
   events causally preceding submission. Answer-bearing hints/worked examples
   before submission are practice-only; revealing a worked comparison after an
   assessment never reclassifies that immutable attempt, and a later revision is
   a new practice-only attempt. An actively submitted revision may separately
   satisfy the typed learning-activity completion contract in decision 11, but
   the reveal itself cannot. A future non-answer-bearing process cue needs its
   own named and calibrated condition.
8. The default result order is evidence scope, assistance condition,
   validator-calculated assessment reliability, specific strength, most
   consequential gap, and next practice. Rating availability and dimension
   profile follow; eligible label/numeric detail, transfer result, reliability
   factors/version, and citations sit under disclosure. The absence of an
   aggregate is explained without presenting it as learner failure. A Not
   assessed result replaces strength/gap/rating content with `notRateable`
   system/evidence reasons and a repair option; it makes no performance claim.
   Users may hide labels and numbers through synced preferences.
9. Every result is described as applying to one sanitized response, exact
   question/blueprint, evidence snapshot, assistance interpretation, rubric, and
   calibration slice. It is not a trait, credential, mastery claim, or proof no
   outside help was used.
10. Do not compare users, publish leaderboards, gate work, retain a “best score,”
    or trend scores across non-equated operation/difficulty, blueprint/evidence,
    rubric major, assistance, rating availability, model family, or calibration
    slice. Immutable per-check history remains separate from current concept
    state; only qualifying, undisputed, one-concept aggregate assessments may
    advance state. Promotion eligibility and schedule eligibility are
    independently validated decisions; their audit selection IDs are
    independently nullable, and neither decision implies the other.

    This ADR owns the exact closed scheduling decision contract. Other plans,
    ADRs, schemas, prompts, projections, and exports must reproduce this tagged
    union byte-for-byte rather than defining a local variant:

    ```text
    ScheduleEligibilityDecision =
        ineligible(conceptRef, orderedReasonCodes,
                   scheduleQualificationPolicyRef, factorDigest)
      | attemptAnchored(conceptRef, intervalClass,
                        scheduleQualificationPolicyRef, factorDigest)
      | activityRecoveryRequired(conceptRef, quietIntervalClass,
                                 scheduleQualificationPolicyRef, factorDigest)
    ```

    `conceptRef` is exact namespace/key/version identity. `orderedReasonCodes` is
    a non-empty canonical list from the versioned qualification policy;
    `factorDigest` commits the complete normalized decision inputs. No variant
    contains a date, deadline, completion, recovery binding, promotion decision,
    or receiver-local clock value. Scheduling is non-promotional:
    Developing/demonstrated/transfer/open-book may use the attempt anchor, while
    Core-needs-review or practice-only may schedule only after a later qualifying
    learning activity. Dimension-only and Not assessed never schedule. A
    schedule-eligible attempt that is not promotion-eligible remains
    non-promotable, and a promotion-eligible assessment receives no schedule
    unless it independently satisfies a schedule class. A broad manual
    multi-concept assessment is always `dimensionOnly`; its concepts are
    discoverable in history but never promotable.
11. Represent a qualifying recovery activity as an immutable
    `LearningActivityCompletionEntity`. It carries `scopeRef`, exactly one
    `ConceptRef`, a typed `activityKind`, a typed verifier-practice or
    registered-workflow source reference, active-completion evidence digest,
    frozen assistance condition, ordered causally preceding support-event
    references, separate accessibility-accommodation references, and versioned
    completion/relevance policy references. Its owning causal event supplies the
    authenticated completion instant.
    A registered-workflow `contractRef` must resolve through
    `verificationLearningActivityCompletionContract` to the exact active
    `LearningRegisteredActivityContractEntity`. Registered workflows must
    provide an exact versioned source contract,
    completion predicate, actor/time authority, and concept extraction or
    learner confirmation; labels, embeddings, or model inference alone cannot
    establish relevance. Multi-concept activity produces separate completion
    artifacts only when each concept has independently sufficient evidence.
    Passive opening, clicking “done,” viewing evidence or feedback, an
    irrelevant or partial response, and model-only work are not completions.

    An immutable `LearningActivityRecoveryBindingEntity` binds one valid
    completion and its owning causal-event/instant reference to its exact
    concept, originating attempt/assessment when applicable, stable
    `ScheduleSourceLineageKey`, and versioned recovery policy. A built-in revised
    explanation, prediction, debug response, application, or evidence-inspection
    response can bind only after the learner actively submits it. Answer-bearing
    support or feedback remains practice-only and is retained as assistance
    provenance; it may precede an active completion but cannot itself satisfy the
    missing completion prerequisite or move the completion instant.
    Accessibility accommodations and non-answer-bearing process support likewise
    do not alter that instant. ADR 0032's separately recorded, learner-visible
    answer-bearing support exposure can postpone a quiet boundary, but remains a
    postponement-only timing input rather than a completion. Conversely, an
    answer-bearing-assisted revised
    explanation or other allowed activity is a qualifying scheduling exposure
    when the learner actively submits it and the registered completion and
    relevance contracts validate it. It remains `practiceOnly`: it can satisfy
    `activityRecoveryRequired` or restart the post-exposure quiet interval for
    `attemptAnchored`, but cannot promote concept history, lengthen the source
    assessment's interval class, or become an unaided or transfer result.

    ADRs 0031 and 0033 own identities, persistence, and projection mechanics.
    Their recovery fold first selects the latest valid active-completion binding
    for the exact concept and schedule-source lineage, then selects the latest
    quiet-boundary exposure from that binding and eligible later same-concept
    answer-bearing support occurrences using ADR 0031's exact binding/exposure
    comparator. A later valid occurrence postpones unengaged work; evaluator,
    repair, retry, audit, sync, and projection latency never advances or resets
    the interval. Invalidation falls back to the next-latest valid item. With no
    active binding, `activityRecoveryRequired` is
    `waitingForLearningActivity` even if answer-bearing support was exposed. The
    distinct `attemptAnchored` branch uses the later of its original attempt
    deadline and any valid post-attempt answer-bearing exposure boundary; with
    neither active binding nor valid support exposure, it falls back to the
    original deadline rather than entering the recovery state.

    Protected engagement on any audit-selection, due-policy, recovery-binding,
    candidate, session, or device branch of the same
    `ScheduleSourceLineageKey` protects the entire automatic opportunity. A late
    exposure found before engagement suppresses stale unengaged descendants and
    recomputes the due instant. If found after protected engagement, preserve the
    learner's work, disclose that the earlier quiet interval was not satisfied,
    and suppress every automatic sibling or migrated-policy replacement across
    the lineage; only an explicit learner-requested retry may start a later check
    after the effective quiet boundary. Policy migration replaces only
    unengaged work; protected work stays pinned and suppresses duplicates across
    every branch. A completion, recovery binding, or support exposure can affect
    scheduling only: it never creates or changes a dimension, score, label, transfer result,
    `qualifyingAssessmentId`, or concept-history promotion. Only a later
    independently evaluated assessment can do so.
12. A learner-chosen dated reminder is a separate, user-authored
    `LearningReviewReminderEntity`, displayed as the learner's reminder. It is
    not part of evaluator or assessment output and cannot supply an automatic
    checkpoint anchor/due instant, recovery binding, rating, transfer result,
    promotion decision, or concept-history evidence. Editing or deleting a
    reminder therefore does not rewrite assessment or automatic-schedule
    history.
13. Preserve attempts and assessments through supported practice and appeal.
    Materially disagreeing concurrent results have no primary display result and
    remain a canonically ordered disputed set with `needsReview`. The versioned
    assessment-agreement predicate requires the same outcome, nullable rating
    availability, every tagged dimension state and exact nonnumeric reason,
    numeric levels within explicit tolerance, material claims/contradictions,
    transfer presence/result, immutable promotion-eligibility factors, and
    request-local reliability codes. Assessed/Not
    assessed, availability, or numeric/nonnumeric mismatch is always material;
    digest order never chooses between them. Result-group state never rewrites
    an assessment's reliability or dimension tags. Audit resolution explicitly
    selects three independent nullable values: `displayAssessmentId`,
    `qualifyingAssessmentId`, and `scheduleAssessmentId`. A schedule result must
    be an input and independently satisfy the schedule class above; selection as
    `qualifyingAssessmentId` does not make it schedule-eligible, and selection as
    `scheduleAssessmentId` does not make it promotion-eligible. `confirmed` may
    set `scheduleAssessmentId` only to its independently schedule-eligible
    confirmed `displayAssessmentId` input.
    `replacementSelected` may select a different independently schedule-eligible
    input only with an explicit scheduling reason and UI disclosure.
    `noQualifyingAssessment` may schedule an explicitly reasoned Core-needs-
    review/practice-only input even when it is not the optional display input;
    `furtherReviewRequired` schedules nothing.
    Audit execution uses the authorization-pinned, generated request lifecycle
    from ADR 0033. Concurrent audit results must agree on material findings and
    all three selected IDs before canonical digest may
    choose representation; otherwise a later adjudication includes every prior
    result. Settlement covers both a recorded complete assessment-result
    frontier and the complete prior-audit-result lineage. A late material
    assessment or prior-audit disagreement clears display/promotion/scheduling
    and requires expanded adjudication; downstream protected learner work is
    preserved under decision 11 even when its upstream selection can no longer
    drive future automation. A late agreeing representation neither replaces
    settled IDs nor invalidates an existing schedule-source lineage, selection
    key, or due opportunity by digest order alone. ADRs 0031/0033 own stable
    schedule keys and lineages, exact support observations, anchor selection,
    and policy concurrency. Export/deletion follows ADR 0033 and never overwrites
    history in place. A late blueprint-admission dispute also sets `needsReview`
    and suspends assessment display/promotion until admission review confirms
    the exact authority.
14. Keep optional learner confidence separate from assessed performance and use
    it only for private self-calibration.

## Consequences

- Feedback remains actionable and inspectable without forcing every valid
  dimension-level judgment into a misleading score.
- Question opportunity, novel-transfer administration, and answer-bearing
  scaffolding no longer inflate the core aggregate or spacing schedule.
- Recovery checks wait for a complete quiet interval after the latest qualifying
  exposure, while late sync or evaluator work cannot shorten that interval.
- Answer-bearing support exposure may postpone that boundary but cannot satisfy
  the active-completion prerequisite or create rating/promotion evidence.
- Typed learning-activity and recovery-binding records make relevance,
  completion, assistance, invalidation, and cross-branch protection auditable,
  but add policy-versioning and projection complexity.
- Assessments remain free of model-selected recheck dates. User-authored
  reminders require separate persistence and UI semantics and never alter
  automatic scheduling or ratings.
- More results will be dimension-only or practice-only, and open-book results
  require explicit qualification and separate calibration.
- Weighted dimensions, operation profiles, labels, and assistance rules require
  rubric versioning, human calibration, and careful UI explanation.
- Separate storage avoids corrupting subjective journal-rating semantics but
  requires dedicated history, concept-state, preference, and deletion paths.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [Flexible rating system plan](../implementation_plans/2026-02-09_flexible_rating_system.md)
