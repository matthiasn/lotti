# ADR 0032: Hybrid Understanding Evaluation

- Status: Proposed
- Date: 2026-07-18

## Context

Rules can validate identifiers, structured facts, citations, score ranges, and
coverage arithmetic, but cannot reliably determine whether arbitrary prose is
entailed by code, paraphrase, causal explanation, prediction, or trade-off
evidence. A valid citation ID is not proof that the cited item supports a claim.
An unconstrained LLM can perform semantic comparison, but may hallucinate,
follow instructions embedded in evidence, score inconsistently, or conceal
uncertainty.

The evaluation must distinguish learner gaps from evidence and calibration gaps.
It must bind results to the exact question and sanitized response that were
assessed, remain inspectable against human judgments, and avoid treating task
type or answer-bearing scaffolding as stronger understanding.

Support exposure is not confined to one verifier session. A hint, worked
example, corrective answer, or answer-shaped evidence may be seen on another
device or in a prior workflow and may remain causally relevant to a later
attempt. Conversely, accessibility accommodations and non-answer-bearing
process support must not be mistaken for answer assistance. Evaluation therefore
needs typed, replayable exposure provenance rather than an assistance value
asserted by the attempt being rated.

## Decision

Use a hybrid blueprint-admission and response-evaluation pipeline.

1. Before the learner responds, an immutable blueprint freezes the exact
   normalized rendered question, locale/template/variant, objective, concept,
   operation, difficulty, assistance contract, registered evidence requirements,
   target claims, rubric major, and assessable dimensions. All semantic fields
   participate in its digest; wording, locale, concept, operation, or assistance
   changes create another blueprint/session branch. Automatic and promotable
   blueprints contain exactly one primary concept. Only an explicitly requested
   broad manual blueprint may carry ordered secondary concepts; it is always
   `dimensionOnlyEligible`, indexes those concepts for discovery only, and can
   never promote concept history. The assistance contract pins the available
   support inventory or registered-source policy, support-classification policy,
   carryover policy, and their versions; a different classification or carryover
   contract creates another blueprint/session branch.
2. Blueprint construction is tool-less and schema-constrained over evidence
   delimited as untrusted data. `BlueprintValidator` checks only structure,
   registered facts/requirements, known evidence IDs, allowed operations/
   dimensions, bounds, and coverage arithmetic. It never claims deterministic
   semantic entailment or overall item quality. Model-based concept selection
   is a logical stage inside this same deterministic blueprint-build request and
   returns the concept only as part of the atomic final blueprint; it is never a
   separate evidence-consuming inference.
3. The final blueprint digest exists before independent review. Every learner-
   facing blueprint receives a separate tool-less `BlueprintAdmissionAuditor`
   review over the complete frozen blueprint and evidence, without builder
   reasoning and without edit authority. Structured facts may bypass only
   per-claim semantic-entailment inference; they never bypass full-item review.
   The auditor returns per-claim `entailed`, `contradicted`, or `notEstablished`
   citations and also
   judges claim-set sufficiency, exact question-objective alignment, operation/
   difficulty fit, required-dimension elicitation, support classification,
   answer leakage, and assistance fit. A separately content-addressed
   `LearningBlueprintAdmissionEntity` stores
   those findings and an `admissionCeiling` of `aggregateEligible`,
   `dimensionOnlyEligible`, or `blocked`; ADR 0034 owns the mapping from that
   ceiling to rating availability.
4. Unsupported/trivial claim sets, answer-shaped wording, unsafe mismatch,
   material builder/auditor disagreement, or an uncleared admission slice block
   the offer. High-consequence security, privacy, data-loss, migration, or
   public-API claims require registered structured facts or an auditor from a
   separately calibrated model family; an unavailable or unconsented route
   fails closed.
   Concurrent admission results that materially disagree form a disputed group;
   digest order cannot authorize a session. Every selecting explicit review
   records a complete admission frontier, a valid semantic-review frontier, and
   a separate audit frontier containing marked history. It includes every
   current admission and every valid review result as semantic input; marked
   results remain audit-only and create no transitive authorization dependence.
   A subset review is non-selecting. A confirmed
   selection must name an eligible, calibrated, undeleted/uninvalidated input
   admission for the same blueprint/request generation; blocked/further-review
   resolutions have no selected ID. Admission review has a deterministic,
   authorization-pinned request envelope with ordered tagged admission/prior-
   review inputs and explicit generation/cancel/fail/complete events. A stable
   review-lineage ID covers the admission group plus one canonical embedded
   `AdmissionReviewPolicySet`. That set contains schema version, review-lineage
   policy major, material-finding normalization, semantic-agreement, resolution-
   node/dominance, selected-admission eligibility, authority-validator policy,
   authority-artifact schema, and a closed execution-compatibility declaration
   of route/prompt/output-schema/calibration/result-validator majors plus its
   calibrated-equivalence evidence-manifest digest. Every branch, request, node,
   and authority stores the complete set and recomputed digest; unknown or
   uncleared compatibility fails closed. The lineage ID is UUID v5 over the
   admission group and that digest and is shared only by requests with the
   identical set. A preparation generation and candidate/session branch pin the
   same body/digest plus the complete explicit or replayable background-default
   assistance selection; every build/admission/review/evaluation contract must
   byte-match it. Other version lineages are audit-only for that branch and
   migration requires explicit policy reconsideration/new preparation, not
   digest selection. The validator recomputes the
   canonical admission/review groups at the request's causal prefix; only exact
   frontier/digest/input equality is selecting. An incomplete request is
   advisory and cannot vote, settle, or supersede. Every nonempty selecting
   request group derives a resolution node: confirmed, blocked, further-review,
   or disputed. An adjudication node dominates an earlier node only when its
   valid frontier/inputs consume every then-current semantic result and its
   consumed-node state digest matches. Duplicate materially agreeing late
   representations leave node state/dominance unchanged; a material late result
   changes the node digest and reopens authority. Confirmed maximal-node
   agreement creates a group-stable semantic authority
   artifact over lineage, blueprint/group, selected admission, normalized
   resolution, and the complete authority-affecting policy-set body/digest—not request
   or reviewer-result identity.
   Requests and historical authority artifacts are many-to-many: contradictory
   locally settled authorities remain auditable after merge, but projection
   permits at most one effective authority. It removes nodes dominated by a
   complete adjudication, then requires a nonempty remaining maximal set with no
   disputed node and every node confirming the same admission/material findings.
   Blocked or further-review maximal nodes leave no authority; consumed,
   marked, and advisory output does not block forever. Reauthorization pins a
   new authorization/disclosure manifest, excludes marked results from semantic
   inputs, and retains only non-authoritative marker/result audit context.
   Digest order may select an audit-
   display representation but cannot replace that authority. A late material expansion
   of the admission or valid semantic-review node invalidates downstream authority and
   requires expanded adjudication; a late agreeing representation cannot rewrite a
   session pin. A late
   conflict preserves engagement/attempts but suspends evaluator work,
   assessment display, and history promotion. The review route must be
   cleared for the same slice. Every route pins a canonical reviewer-disclosure
   manifest enumerating the blueprint, evidence manifest/payload bytes, and all
   rendered lineage inputs. Human review additionally requires an item-level
   consent subject whose manifest, exact redacted-preview digest, route, and
   ordered content refs match the request byte-for-byte. Expanded disclosure or
   adjudication requires a new consent subject. Model review is tool-less,
   schema-constrained, citation-validated, and treats every input as delimited
   untrusted data.
5. Blueprint admission has a calibration corpus and manifest separate from
   response evaluation. It is sliced by builder/auditor family and version,
   concept-selection mode/selector-policy version,
   prompt/schema/rubric major, operation/difficulty, locale, question-template/
   variant group, assistance contract, evidence/support mode, concept namespace,
   and risk class. Independent domain-competent, locale-fluent humans label
   claim support/sufficiency, citations, alignment, elicitation, leakage, and
   fit. Changes to any slice key return the affected route to shadow admission.
   Release is also fail-closed on confidence-bound pre-adjudication human-human
   agreement for every judgment, false rejection of valid blueprints,
   between-slice false-rejection disadvantage, and preparation-to-offer failure
   burden by locale, template/variant group, assistance contract, and concept
   namespace. Aggregate safety accuracy cannot hide a failed access/equity gate.
   Admission review/adjudication has a separate dispute-set manifest keyed by
   review route/policy/input multiplicity and must clear false-confirm, false-
   block, agreement, input/selection, consent, and schema gates before it can
   settle authority.
6. Secret scanning occurs before persistence or cloud submission. The learner
   approves any sanitized preview, and the evaluator receives exactly the
   immutable `submittedResponseText` stored in the attempt. Optional originals
   are separately consented, device-local, expiring, and never required for
   evaluation, reproduction, appeal, or export.
7. A tool-less response evaluator decomposes the answer into claims and proposes
   anchored levels only for blueprint-elicited dimensions defined by ADR 0034.
   Every material claim, gap, contradiction, proposed level, and optional
   transfer result cites frozen evidence IDs. It receives the validator-derived
   assistance interpretation and privacy-safe support-exposure closure manifest
   defined below, never a learner/session assertion that it may treat as
   authoritative. Raw support content is disclosed only when separately
   authorized and required by the cleared evaluation route. The evaluator has no
   tools,
   network, shell, or write capability and returns named observable signals—not
   an assessment-reliability judgment. Its schema may propose one untimed next
   practice but rejects any recheck/due date, deadline, or reminder; evaluator
   output never becomes scheduling authority.
8. A deterministic validator checks schema/references, applies the ADR 0034
   rating-eligibility/rating rules, and calculates assessment reliability only
   from request-pinned evidence/schema/citation facts, named evaluator signals,
   and a pinned response-calibration manifest. Concurrent-result agreement is
   projection/audit state and never enters or rewrites an immutable assessment.
   Its validator/scorer/
   rating-policy version is pinned in the evaluation request as well as the
   result identity, so deterministic policy drift cannot masquerade as
   stochastic evaluator disagreement. Before applying rating rules, it
   recomputes assistance facts from the complete support-exposure closure in
   decision 9 and rejects an omitted exposure, mismatched classification,
   self-asserted eligibility, or unresolved ordering. Such a result cannot
   authorize aggregate rating, transfer, or concept-history promotion; the
   immutable attempt remains available for appropriately qualified feedback and
   later reevaluation. ADR 0034, not this
   decision, owns dimension semantics, `ratingAvailability`, scores, caps,
   labels, transfer, and independent concept-history promotion and review-
   schedule eligibility.
9. Assistance is derived from learner-visible exposure evidence; it is not an
   authoritative field supplied by a session or attempt. This ADR owns the
   classification and evaluation-input semantics below. ADR 0033 owns the
   persistent artifact envelope, identity, typed links, exposure-event schema,
   authenticated instant, observed-frontier mechanics, invalidation, deletion,
   and cross-device projection. ADR 0031 owns quiet-boundary scheduling, and
   ADR 0034 owns the rating, promotion, and schedule-eligibility consequences.

   The required semantic body is:

   ```text
   LearningSupportExposureEntity(
     schemaVersion,
     scopeRef,
     conceptRef,
     sourceSessionRef,
     questionBlueprintRef,
     source = verifierSupport(supportItemId, supportItemDigest)
            | assessmentFeedback(assessmentRef, feedbackItemId,
                                 feedbackItemDigest)
            | registeredWorkflowSupport(sourceEventRef, contractRef,
                                        supportItemId, supportItemDigest),
     supportKind = answerBearingHint
                 | workedExample
                 | answerBearingFeedback
                 | nonAnswerBearingProcessCue
                 | evidenceView
                 | accessAccommodation,
     cognitiveClass = answerBearing | processOnly | passive | accommodation,
     assistanceCarryoverPolicyRef
   )
   ```

   `conceptRef` is exactly one `ConceptRef`; labels, embeddings, ancestry, and
   model-only similarity cannot broaden it. The source resolves the exact
   rendered support content and digest. A passive surface that reveals an
   answer, worked solution, corrective conclusion, or answer-shaped evidence is
   `answerBearing` (using `answerBearingFeedback` where applicable), never
   `passive`. An accommodation that conveys
   answer content is likewise `answerBearing`; `accommodation` is reserved
   for access transformations that do not change the assessed construct or
   supply an answer. Built-in classification is independently checked during
   blueprint admission. Registered-source classification is accepted only
   through the compatible contract validation below. Unknown or conflicting
   classification fails closed.

   ADR 0033 persists one learner-exposure event for each actual presentation:

   ```text
   learningSupportExposureRecorded(supportExposureArtifactRef)
   ```

   Its owning user event supplies the authenticated learner/scope/author-host
   provenance, causal parents, and authenticated instant. The artifact and its
   atomic source/session/blueprint links prove which exact content was visibly
   exposed, not that the learner read or understood it. Provider result arrival,
   background generation, an unopened notification, an unseen feedback payload,
   sync, projection, or evaluator latency is not exposure and creates no such
   event.

   Every automatic or promotable response-evaluation request pins a
   `SupportExposureClosure`: the scope, exact concept, submission event, complete
   observed support frontier, canonical set of relevant exposure refs,
   classification policy, carryover policy, and derived-assistance digest.
   Canonical byte order is not causal order. The closure covers all valid
   relevant exposures known at the complete frontier across sessions, workflows,
   devices, and registered sources; attempt fields such as `supportUsed` or
   `assistanceCondition` are non-authoritative assertions. A validator refuses a
   closure that omits a known relevant exposure, is not complete under ADR
   0033's frontier rules, or does not reproduce the derived-assistance digest.

   Relevance and ordering are deterministic. Exact `ConceptRef` mismatch
   excludes an exposure. A valid causal ancestor of
   `verificationAttemptSubmitted`, or an otherwise unordered exposure whose
   authenticated latest instant is strictly before the submission's earliest
   instant, is definitely pre-submission. A valid causal descendant, or an
   unordered exposure whose authenticated earliest instant is strictly after
   the submission's latest instant, is definitely post-submission. Overlapping
   intervals, concurrent events, unresolved causal/time provenance, and exact-
   time equality without causal order are ambiguous. Ambiguity cannot be broken
   by digest order, client receipt order, or a model; it blocks aggregate,
   transfer, and promotion authority until resolved while preserving the
   attempt and permitting only policy-cleared qualified feedback.

   Every definitely pre-submission `answerBearing` exposure contributes to the
   assistance derivation unless its calibrated carryover quiet boundary has
   fully elapsed. The boundary is an ADR 0033 `AuthenticatedDeadlineRef` derived
   from the exposure event's latest authenticated instant plus the duration in
   the pinned `assistanceCarryoverPolicyRef`. Carryover clearance is proven only when the
   submission event's earliest authenticated instant is at or after that
   boundary; equality counts as elapsed, while any overlap or invalid time
   support fails closed. A cleared boundary merely allows ADR 0034 to consider
   the attempt under a calibrated fresh-question/blueprint slice; it does not
   itself grant aggregate eligibility. Each later answer-bearing exposure adds
   its own boundary; the effective carryover boundary is the maximum of all
   applicable boundaries, so a shorter later interval cannot erase a longer
   earlier one. `processOnly`, `passive`, and `accommodation`
   exposures neither contaminate assistance nor add/reset a boundary. Explicit
   open-book work remains a separately named and calibrated assistance mode
   under ADR 0034; answer-bearing content encountered during it retains
   `answerBearing` precedence.

   A definitely post-submission exposure never reclassifies that immutable
   attempt. It applies to a later revision or other same-concept attempt, even
   in a fresh session or on another device. If a late-synced event is proved
   definitely pre-submission, the attempt is preserved but any evaluation that
   omitted the event becomes audit-only: its aggregate, transfer, promotion,
   and assistance-dependent downstream authority are invalidated and must be
   rebuilt from the expanded closure. A definitely post-submission late event
   leaves the current attempt unchanged. An ambiguous late event fails closed as
   above until additional authenticated causality/time evidence resolves it.

   No support exposure of any class is an active learning completion, rated
   evidence, transfer evidence, or concept-history promotion. An actively
   submitted response may separately create the
   `LearningActivityCompletionEntity` owned by ADRs 0031 and 0033. For recovery,
   that active completion remains mandatory. A later same-concept
   `answerBearing` exposure is a postponement-only timing input: before protected
   engagement, ADR 0031's fold moves the effective recovery quiet boundary to
   the later of the qualifying completion boundary and the maximum applicable
   answer-bearing carryover boundary. After protected engagement, ADR 0031
   preserves the learner's work and reports the unsatisfied boundary rather than
   replacing it automatically. The exposure cannot satisfy
   `waitingForLearningActivity`, change the completion instant, or promote
   understanding. Process-only support, passive non-answer content,
   accommodations, and system/result latency do not move that boundary.

   A registered workflow completion or support exposure is usable only after a
   deterministic compatibility check of the complete, content-addressed
   `LearningRegisteredActivityContractEntity` owned by ADRs 0031 and 0033. Evaluation
   pins and verifies its body/digest/version, exact source-event schema and
   completion predicate, allowed activity kind, actor and clock authority,
   exact concept extraction or explicit learner-confirmation rule, completion
   evidence requirements, assistance/support-exposure provenance and
   classification policy, completion/relevance policies, and declared
   evaluation/rating compatibility. A missing body, unknown field or major,
   unsupported source schema, digest mismatch, incomplete dependency, or
   incompatible classification/carryover policy fails closed. The source event
   and proposed completion remain audit history but cannot be used as a
   dependency to satisfy recovery, authorize evaluation/rating/promotion, or
   affect scheduling; the projection remains `waitingForLearningActivity` where
   active completion is required. No LLM or embedding may substitute semantic
   matching for this contract check.
10. Response calibration is separately fail-closed per rubric major, evaluator
    model family, assessment-validator/scorer/rating-policy version,
    operation/difficulty, locale or translation route, question-
    template/variant equivalence group, concept namespace, evidence/support
    mode, risk class, assistance interpretation, support-exposure classification
    policy, exposure-source contract class, carryover-policy/quiet-boundary
    class, prior-exposure state, and response/input-mode equivalence group.
    Domain-competent, locale-fluent raters and bilingual
    adjudicators for translation routes must clear preregistered confidence-
    bound agreement, severe-misconception, false-low/false-high, equity, and
    sample-adequacy gates. Pooling any key requires preregistered invariance;
    every untested value fails closed. An uncleared slice appends
    `evaluationUnavailable` with a non-assessment artifact and creates no
    learner assessment; static preauthored self-check guidance is UI content,
    not a rating or history artifact.
    Assessment audit/adjudication is also separately cleared on appeal/sample/
    dispute sets, including severe-error selection, human agreement, complete-
    frontier, input/nullability/promotion/schedule-selection, and item-consent gates. Every
    selecting audit source records and covers the complete current assessment-
    result frontier, not only concurrent-disagreement requests. An uncleared
    audit route cannot select display, qualifying, or schedule IDs.
11. Blueprint build (including concept selection), blueprint admission,
    admission review, response evaluation,
    and assessment audit use deterministic request envelopes whose IDs cover
    every canonical execution-semantic field, including authorization, route,
    calibration, generation, and deadline policy. Stochastic results are
    immutable and content-distinct. A response-evaluation request additionally
    pins the complete support-exposure frontier/ref set and digest, derived
    assistance facts, classification/carryover policy refs, any registered-
    activity contract compatibility result on which it depends, and the
    authenticated submission/boundary inputs. Expanding that closure after late
    sync invalidates the old request's governing and promotion authority without
    rewriting its attempt or historical result. Each operation permits one local in-flight
    call per request and uses provider idempotency when available, but assumes no
    cross-device lease. Restart resumes the same unterminated request;
    cancellation/failure/result are causal events. Concurrent results are
    preserved and settle only through a versioned semantic-agreement predicate
    or later adjudication. For assessments, that predicate compares outcome,
    nullable rating availability, every tagged dimension state/reason and
    numeric level, material claims/contradictions, transfer, immutable promotion-
    eligibility factors, and request-local reliability codes—not numeric levels
    alone.
    Per-execution token/latency/provider observations have separate
    unique artifacts, so equal result output remains byte-identical. Each model
    operation's sole schema-repair request is keyed by parent request, ordinal
    one, and repair policy. Every model route, including review/adjudication,
    runs without tools, network, shell, or write authority; consumes only the
    exact authorization/disclosure-manifest bytes as delimited untrusted data;
    and returns schema-constrained, inventory-validated output. Review/audit
    disclosure manifests enumerate evidence, response, appeal, and prior-
    finding content actually exposed, separately from dispute-lineage inputs.
    Response evaluation additionally creates one canonical generation artifact
    before any pre-call check. Its content-addressed identity owns the attempt/
    route/authorization, required-capability contracts, request generation,
    deadline value plus authenticated derivation-instant interval/time policy,
    and evaluation/capability/unavailability/active-peer policy versions plus
    heartbeat window. Every capability observation,
    base/repair request, active-peer snapshot, and unavailability artifact pins
    and byte-validates this contract. Peer membership comes from an independent
    immutable sync-peer enrollment roster; separate peer-author-key and
    capability logs contain the verified key epoch and canonical unknown
    bootstrap or advertisement for each enrolled host. At the
    deadline, the ADR 0033 transition table makes enrollment/restoration
    establish liveness, takes the maximum authenticated instant interval across concurrent valid
    positive revisions, latches retirement across later heartbeats/enrollments
    until a restoration causally covers every retirement, and treats unknown or
    divergent capability advertisements as incompatible. A valid authenticated
    self-advertisement supersedes a concurrent neutral unknown bootstrap;
    canonical ID is only a representation tie-break for equivalent states.
    Advertisements and observations require persisted signed-attestation author host equality;
    enrollment requires authoritative roster provenance; retirement/restoration
    requires explicit user authority.
    Every deadline, liveness, observation, snapshot, and closure comparison uses
    ADR 0033 authenticated instant intervals. Actor-invalid input is quarantined;
    authenticated but unresolved/skewed/regressing time remains audit-only and
    blocks closure rather than being omitted. A snapshot/closure event also
    proves trusted current-time lower bound reached the generation deadline.
    A deadline-eligible capability observation must byte-match the generation-
    owned fields and the effective peer-state digest/revision set recorded for
    that host by the snapshot. A mismatch, post-deadline, boundary-ambiguous,
    or time-invalid observation is stale.
    Among concurrent maximal observations, `eligible` conservatively prevents
    exhaustion; disagreeing noneligible states remain ambiguous/pending.
12. Invalid model output appends `evaluationFailed`, not an assessment. A
    host-local evidence/route gap remains pending/local UI and never creates
    synced unavailability. Provider/evidence exhaustion requires a complete
    content-addressed deadline snapshot over one complete immutable observed
    frontier of the global peer-policy log and its filtered key/enrollment/
    capability sets, with one privacy-safe generation-specific capability
    observation per snapshotted active peer; a missing, stale, or ambiguous
    observation keeps work pending. A generation may retain multiple immutable
    historical snapshots. A late pre-deadline peer revision permanently
    invalidates the incomplete snapshot and dependent closure; a joined-frontier
    replacement is the only effective snapshot, even if incomparable old
    snapshots happened to derive equal peer sets. Snapshot identity contains no
    locally known superseded-history list; equal joined frontiers/folds always
    produce equal bytes. Its scoped artifact carries a
    validated `ObservedLogFrontierRef` to the global peer-policy-log prefix plus
    filtered roster/capability set digests;
    this is a cross-log dependency commitment, never cross-agent DAG causality.
    The generation becomes
    `closureRebuildPending`, permits no post-deadline model call, and requires a
    fresh closure against that replacement or an explicit retry/new generation
    when the historical frontier is incomplete. If the single repair fails across every
    active eligible execution branch, the system may append a typed non-
    assessment `evaluationUnavailable(repairExhausted)` artifact with exactly
    two tagged request links, the complete linked failure set, and canonical
    execution/capability terminal frontiers. Neither path emits
    `assessmentProduced` or requires a model-execution observation on an
    assessment. Closure precedence is group-based: first invalidate stale-
    snapshot closures and every closure causally after a valid result; then mark
    a result audit-only if it descends from any member of the complete remaining
    valid closure set, including nonmaximal ancestor closures; only a non-audit
    result concurrent with every member may govern. Reduce to the maximal
    antichain only afterward for presentation. Preceding one closure therefore
    cannot let a result override a different closure from which it descends or
    be resurrected by dropping an ancestor closure. Without a governing
    valid assessment, replicas retain the complete maximal
    closure antichain: semantic agreement chooses display representation only,
    while differing reasons/remedies remain an ordered union with no scalar
    primary. A later retry is a new generation. **Not assessed** is reserved for a
    schema-valid evaluator output from an actual model execution on a cleared
    route when deterministic post-inference evidence/reliability is inadequate
    for every numeric dimension judgment. It has no numeric dimension levels:
    elicited dimensions are `notRateable(reasonCode)` and unelicited dimensions
    remain `notObserved`. An uncleared route likewise creates no assessment.
13. Persist only concise claim/evidence rationale and explicit provenance; never
    request or store hidden chain-of-thought. Content—not grammar, accent, exact
    jargon, verbosity, typing speed, or access modality—is assessed.
14. Normative conformance fixtures cover assistance and registered-source
    boundaries exactly:

    - a same-session hint, worked example, or corrective answer definitely
      before submission derives answer-bearing practice-only eligibility, while
      a process cue does not;
    - revealing an answer after assessment leaves the submitted attempt and its
      evaluation unchanged, but an immediate revised response is a new
      answer-bearing attempt;
    - starting a fresh session or using another device for the same concept
      before the carryover boundary cannot evade practice-only treatment or
      authorize promotion;
    - a fresh-question attempt one instant before the boundary remains
      contaminated, one whose earliest authenticated instant equals the boundary
      counts as elapsed, and one after it may regain eligible assistance only in
      a cleared fresh-question/calibration slice;
    - an exposure for a different exact `ConceptRef` is excluded, including when
      its label or embedding appears similar;
    - a late cross-device exposure proved pre-submission makes the prior
      aggregate/transfer/promotion authority audit-only, a proved post-submission
      exposure leaves the current attempt unchanged, an ambiguous event blocks
      those authorities, and frontier merge/rebuild converges independent of
      arrival order;
    - a same-concept answer-bearing exposure after an active recovery completion
      postpones the recovery quiet boundary without satisfying or replacing the
      completion; without a valid active completion the state remains
      `waitingForLearningActivity`;
    - process-only support, passive non-answer evidence/feedback shells, and
      accessibility accommodations neither contaminate assistance nor postpone
      the boundary, while answer content passively shown on such a surface is
      classified `answerBearing`;
    - provider result arrival, unopened feedback, sync, and evaluator latency
      create no exposure or timing anchor; and
    - missing, unknown-major, digest-mismatched, incomplete, and classification-
      incompatible registered learning-activity contracts remain audit-only and
      fail closed for evaluation, recovery, rating, promotion, and scheduling.

## Consequences

- Semantic flexibility is available without giving a model authority over
  evidence inventory, arithmetic, rating eligibility, or reliability.
- The architecture no longer labels citation validity as proof of semantic
  support; uncertain target claims fail closed.
- Exact question and response identity make historical assessment reproducible.
- More checks will be dimension-only, practice-only, or Not assessed, and some
  routes will create no learner assessment, but incomplete tasks and scaffolding
  cannot masquerade as stronger understanding.
- The pipeline requires separate builder, admission auditor, evaluator, validator,
  calibration, and audit governance and may consume duplicate inference across
  devices.
- Typed exposure provenance and complete cross-device closure rebuilds add
  projection and calibration cost. Conservative ordering may temporarily
  withhold aggregate or promotion authority, but it cannot erase learner work
  or let a fresh session evade answer-bearing carryover.
- Accessibility accommodations and non-answer-bearing process support remain
  available without a rating penalty; content that supplies an answer is
  classified by what it reveals rather than by the UI surface that revealed it.
- Non-equated blueprint, evidence, rubric, assistance, or calibration slices
  cannot be score-trended.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0011: Feedback Classification Strategy](./0011-feedback-classification-strategy.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
