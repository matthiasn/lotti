# ADR 0031: Learning Verification Checkpoint Policy

- Status: Proposed
- Date: 2026-07-18

## Context

Learning verification is useful only at meaningful checkpoints. Prompting after
every AI action would create fatigue, while model-selected timing would be
non-deterministic, difficult to test, and vulnerable to instructions embedded in
source content.

The decision also spans two privacy states. A user may allow automatic
invitations without allowing evidence access or inference in the background. In
addition, evidence quality and concept spacing are unavailable until after
evidence and an admitted question blueprint exist, so they cannot be inputs to a
pre-evidence priority score.

Lotti currently has no cross-device lease coordinator. Correctness must follow
ADR 0018's convergent/idempotent path even when multiple devices prepare the same
candidate. Verification is an interactive lifecycle that remains separate from
`WakeOrchestrator` background scheduling.

Burden limits are user-global even though candidates live in separate scoped
verifier logs. A delivery rule therefore needs an explicit cross-agent
projection and must not let disconnected devices independently present
automatic prompts.

Review timing has the same convergence requirement. A later clock-validation
observation, audit selection, learning exposure, or schedule-policy generation
must not create a second automatic opportunity for the same learner act. At the
same time, authority-bearing deadlines cannot depend on a receiver's local
clock, and scheduling eligibility must remain independent of whether an
assessment may promote concept history.

## Decision

Use a separate `LearningCheckpointCoordinator` with a versioned, staged,
deterministic policy.

1. Source workflows emit normalized, evidence-free signals only after meaningful
   durable events: completed work, a resolved consequential decision, terminal
   task transition, pre-finalization boundary, due spaced review, or explicit
   manual request.
2. Consent is checked before source-derived metadata is copied. The coordinator
   atomically appends a host-invariant candidate, host-specific observation,
   required links, and causal observation event. Candidate identity covers
   verifier scope, owning workflow and workflow ID, source run/signal, and
   checkpoint type; it excludes policy and host authority.
   `automaticInvitations` permits only opaque external event/frontier IDs,
   checkpoint type plus a registered authenticated source-instant reference,
   coarse allow-listed risk/novelty flags, capability IDs, and
   a projection digest computed solely over those neutral fields. External paths,
   symbols, exact revisions, detail-committing digests, labels, concept text,
   and source metadata remain local
   unless `syncExternalEvidenceManifest` separately authorizes a sanitized
   observation. External candidate key IDs are opaque connector identifiers.
   Policy revisions create separate decision artifacts and cannot replay old
   candidates without an explicit reconsideration event.
   A deterministic candidate action epoch is `initial` or derived from the exact
   closed-source artifact on reopen; decisions/offers/actions pin it. Reopen and
   action validity is evaluated against each event's causal prefix. A causally
   later reopen dominates; concurrent unengaged epochs converge on the lowest
   epoch ID, while every protected engaged epoch remains a parallel branch, the
   lowest engaged epoch is the presentation epoch, and no further offer is made.
3. Preflight guards use only durable signal, consent, activity, burden, and
   history facts. Disabled or unauthorized scopes are suppressed. Busy/quiet
   windows, another active check, or temporarily unavailable provider setup
   create a replayable temporary defer, never an authority-bearing bare
   timestamp. The owning event stores a complete `DeadlineDerivationSpecV1`:

   ```text
   DeadlineDerivationSpecV1 =
       relative(durationMicros, baseEdge = latest)
     | explicitUtc(targetUtcMicros)
     | explicitLocal(localDateTime, timeZoneId, tzdbVersion, overlapChoice)
   ```

   After the event is durably appended, ADR 0033 derives an
   `AuthenticatedDeadlineRef` from the owning event's source-only
   `AuthenticatedCausalInstantRef` and that specification. The specification,
   not the derived reference, is embedded in a same-event defer artifact, which
   avoids a signature/hash cycle. Automatic eligibility uses conservative
   interval comparison: trusted current time's earliest value must reach the
   canonical deadline boundary. Missing clock authority, unresolved DST semantics,
   excessive skew, or an unavailable registered source-clock bridge projects a
   typed time-unavailable state; receipt time and device-local wall time are
   display-only and never become fallback authority.
4. Preflight invitation priority uses checkpoint importance, source-declared
   novelty, consequence/risk, an explicit due-review boost when the signal
   already carries a durable concept, and fatigue. Evidence quality and a
   model-inferred prior gap are not preflight inputs. The previous threshold is
   retired; Phase 0 must rebaseline and version the new range before prompting.
5. A preflight-eligible automatic candidate follows one of two paths:
   - with separate background-preparation consent, evidence preparation may
     start; or
   - without it, the coordinator may offer only a generic candidate invitation.
     That invitation contains no inferred concept, question, evidence claim, or
     changed-subject detail and performs no adapter/model work. **Explain now**
     or **Open-book** appends `candidatePreparationAuthorized` with an
     `invitationAcceptance` source. Background preparation uses the same event
     with a `backgroundConsent` source and a replayable
     `backgroundDefault(choice, contributing preference refs, observed
     preference frontier, fold policy)` assistance selection; invitation and
     manual sources use `explicit(choice)`. Invitation acceptance is not a second
     event. Every preparation event pins a deterministic preparation generation,
     complete assistance selection, and complete canonical admission-review
     policy-set body/digest. A missing/ambiguous default blocks background
     preparation; a preference change creates a new unengaged generation rather
     than reinterpreting one already pinned.
   An explicit manual candidate instead appends the user-kind event with
   `manualInvocation(manualRequestId, authorizationSnapshotId)` plus an explicit
   assistance selection after the observation. It requires
   `manualEvidence` authority, pins the same preparation/policy contract, and
   creates no generic invitation.
6. After evidence capture and an independently admitted blueprint, every
   automatic or history-promotable check has exactly one concept. An explicitly
   requested broad manual check may add ordered secondary concepts but is always
   dimension-only and non-promotable under ADRs 0032/0034. Then
   a deterministic offer-quality gate checks registered coverage/directness,
   missing/truncated sources, full-item admission status, concept spacing, and
   engaged sibling branches. Admission includes claim support/sufficiency,
   question-objective/operation/difficulty alignment, required-dimension
   elicitation, answer leakage, and assistance fit. Post-preparation facts may
   suppress an offer but may never promote a candidate that failed preflight.
7. Correctness is idempotency-first. Deterministic candidate/request IDs,
   immutable content-addressed branches, and distinct IDs for byte-distinct stochastic results allow
   connected or offline duplicate execution to converge without overwrite. A
   future soft coordinator may reduce cost but is not required. Reconciliation
   may supersede only unopened branches; invitation-authorized preparation,
   explicit manual invocation, session engagement, drafts, support use,
   attempts, and assessments are protected.

   For spaced review, protection is keyed by the outer
   `ReviewDueOpportunityKey`, not one due artifact, anchor, selection, or policy
   branch. Valid protected engagement in any descendant branch suppresses every
   automatic sibling for the opportunity, including siblings produced by
   anchor replacement, a newer learning exposure, direct-group/audit selection,
   admission change, support invalidation, or schedule-policy replacement. The
   exact historical due, candidate, question, session, draft, response, and
   assessment remain visible. If their governing facts later become ineligible,
   projection marks them `protectedHistorical` with the applicable provenance or
   timing warning and stops any further automatic evaluation, rating display,
   spacing advancement, or concept promotion that the invalid facts would have
   authorized. It does not silently reinterpret or delete learner work.

   Before protection, the normative fold may suppress an obsolete branch and
   cancel its system-owned work. Concurrent protected branches remain grouped
   history; digest order never discards either, and no further automatic prompt
   is made. An explicit learner-requested retry remains a new disclosed learner
   action under the retry policy rather than an automatic replacement.
8. Immediate self-explanation and delayed retrieval/transfer are distinct.
   Accessibility accommodations do not change spacing. Answer-bearing hints and
   worked examples are practice-only and never lengthen an interval. Open-book
   results are separately qualified/calibrated; their automatic recheck is no
   sooner than one day and no later than the three-day initial Developing
   boundary. Longer intervals require qualifying delayed retrieval or transfer
   evidence. Every delivery still requires meaningful context, current consent,
   and available burden.

   Scheduling and concept-history promotion are independent deterministic
   decisions over the same immutable assessment facts:

   ```text
   ScheduleEligibilityDecision =
       ineligible(conceptRef, orderedReasonCodes,
                  scheduleQualificationPolicyRef, factorDigest)
     | attemptAnchored(conceptRef, intervalClass,
                       scheduleQualificationPolicyRef, factorDigest)
     | activityRecoveryRequired(conceptRef, quietIntervalClass,
                                scheduleQualificationPolicyRef, factorDigest)
   ```

   No schedule decision reads a promotion decision, and no promotion decision
   reads a schedule decision. Developing/demonstrated/transfer/open-book results
   may be `attemptAnchored`; Core-needs-review and practice-only results may be
   `activityRecoveryRequired`; dimension-only and Not assessed are
   `ineligible`. Audit selects `scheduleAssessmentId` independently of its
   promotion-qualifying selection. ADR 0034 owns this exact closed union and its
   qualification semantics. The block above is its normative byte-for-byte copy;
   any divergence fails schema review. This ADR owns only the scheduling fold
   that consumes the decision.

   A recovery exposure must be a typed active learner completion:

   ```text
   LearningActivityCompletionEntity(
     schemaVersion,
     scopeRef,
     conceptRef,
     activityKind,
     source = verifierPractice(attemptRef, originatingAssessmentRef,
                               feedbackActivityId)
            | registeredWorkflow(sourceWorkflow, sourceEventRef, contractRef),
     completionEvidenceDigest,
     assistanceCondition,
     orderedSupportEventRefs,
     accessAccommodationRefs,
     completionPolicyRef,
     relevancePolicyRef
   )

   ActivityContractLineageId = UUIDv5(
     "lotti.learning.activity-contract-lineage.v1",
     globalScopeRef,
     sourceWorkflow,
     contractKey,
     compatibilityMajor
   )

   LearningRegisteredActivityContractEntity(
     schemaVersion,
     activityContractLineageId,
     generationNumber,
     sourceWorkflow,
     exactSourceEventSchema,
     completionPredicate = closedDeterministicPredicate(...)
                         | signedNativeValidator(validatorId,
                                                 releaseManifestDigest),
     conceptExtractionOrLearnerConfirmationRule,
     actorAndClockAuthorityContract,
     allowedActivityKinds,
     requiredCompletionEvidenceAndAssistanceProvenance,
     compatibilityMajor,
     policyRef,
     orderedPredecessorMaximalContractRefs,
     signedActivationRef
   )

   ActivityContractActivatedBodyV1(
     schemaVersion,
     activityContractLineageId,
     generationNumber,
     sourceWorkflow,
     exactSourceEventSchema,
     completionPredicate,
     conceptExtractionOrLearnerConfirmationRule,
     actorAndClockAuthorityContract,
     allowedActivityKinds,
     requiredCompletionEvidenceAndAssistanceProvenance,
     compatibilityMajor,
     policyRef,
     predecessorSetDigest = D(
       "lotti.learning.activity-contract-predecessor-set.v1",
       orderedPredecessorMaximalContractRefs)
   )

   activityContractActivatedBodyDigest = D(
     "lotti.learning.activity-contract-activated-body.v1",
     ActivityContractActivatedBodyV1)

   LearningActivityRecoveryBindingEntity(
     schemaVersion,
     learningActivityCompletionRef,
     scheduleSourceLineageKey,
     conceptRef,
     recoveryBindingPolicyRef
   )
   ```

   Initial activity kinds are `revisedExplanationSubmitted`,
   `predictionPracticeSubmitted`, `debugPracticeSubmitted`,
   `applicationPracticeCompleted`, `evidenceInspectionResponseSubmitted`, and
   `registeredSourcePracticeCompleted`. A `registeredWorkflow` source is valid
   only when `contractRef` resolves to an active
   `LearningRegisteredActivityContractEntity`, its source event matches the
   exact schema and recorder-message discriminant, and every predicate and
   authority check succeeds. The contract is immutable, belongs to its stable
   global lineage/generation, and is activated in the global learning-policy
   scope through the trusted control-key authority described below. Its signed
   activation uses purpose `activityContract`, commits exactly
   `activityContractActivatedBodyDigest` and the predecessor-set digest, and
   requires `activityContractActivation` capability. The closed predicate AST
   permits only `all`, `any`, `not`, `fieldPresent`, `fieldEquals`,
   `fieldInClosedSet`, `setContains`, `digestEquals`, and
   `learnerActionKindIn`, with schema-compiled paths and canonical literals; it
   forbids dynamic code, model/network calls, recursion, and nondeterministic
   inputs. A native validator must be named with its executable digest by the
   signed release manifest. Relevance requires exact
   `ConceptRef` identity; labels, embeddings, and model-only semantic matching
   cannot establish it. Passive opening, reading feedback, revealing a hint,
   clicking “done,” partial work, unrelated work, or model output alone never
   qualifies. The completion artifact does not embed its own authenticated
   instant; its owning causal event supplies that instant after append. ADR 0033
   persists the event, typed links, and a later recovery binding between the
   completion and schedule source lineage. The atomic completion append requires
   `verificationLearningActivityCompletionContract` exactly for a
   `registeredWorkflow` source and forbids it for `verifierPractice`. Its exact
   registered source event remains mandatory typed provenance;
   `verificationLearningActivityCompletionSource` is additionally required only
   when that source is an actual agent-domain link endpoint. The binding append
   requires
   `verificationLearningActivityRecoveryBindingCompletion` and
   `verificationLearningActivityRecoveryBindingLineage`. The latter targets the
   immutable lineage entity below, never a synthetic key with no entity.

   Every source attempt has one policy-invariant outer lineage:

   ```text
   ScheduleSourceLineageKey = UUIDv5(
     "lotti.learning.schedule-source-lineage.v1",
     scopeRef,
     conceptRef.namespace,
     conceptRef.key,
     conceptRef.version,
     sourceAttemptRef
   )

   LearningScheduleSourceLineageEntity(
     id = ScheduleSourceLineageKey,
     schemaVersion,
     scopeRef,
     conceptRef,
     sourceAttemptRef,
     identityAlgorithm = lotti.learning.schedule-source-lineage.v1
   )

   LearningScheduleLineageMigrationEntity(
     schemaVersion,
     priorLineageRef,
     successorLineageRef,
     preservedReviewDueOpportunityKey,
     identityMigrationPolicyRef,
     signedActivationRef
   )

   ReviewDueOpportunityKey = UUIDv5(
     "lotti.learning.review-due-opportunity.v1",
     ScheduleSourceLineageKey
   )

   scheduleSourceLineageRecorded(
     scheduleSourceLineageArtifactRef,
     scopeRef,
     sourceAttemptRef
   )
   ```

   The entity ID is exactly `ScheduleSourceLineageKey`, and its body must match
   the schema version, fixed identity algorithm, three identity inputs, and
   derived key above. The first
   assessment for the attempt/concept pair atomically appends the system event,
   owns the immutable entity, and adds exactly one
   `verificationScheduleSourceLineageScope` and one
   `verificationScheduleSourceLineageAttempt` link. Replays insert-or-verify the
   same bytes; a same-key/different-body artifact fails closed. No rubric,
   assessment group, assessment representation, audit/admission revision,
   timing anchor, recovery binding, selection, or schedule-policy generation can
   mint another outer key. A genuinely new learner attempt or different exact
   concept creates a new lineage. Every competing child remains inside the same
   opportunity, and deletion or invalidation suppresses children rather than
   reminting the lineage. A future identity algorithm requires a control-key-
   activated `LearningScheduleLineageMigrationEntity` that maps both immutable
   lineage records to the already existing `ReviewDueOpportunityKey`; migration
   may not create a parallel protected opportunity.

   Attempt-anchored outcomes use the exact submission event and its ADR 0033
   authenticated instant. Activity recovery waits for a qualifying completion
   whose interval's earliest value is strictly after the source submission's
   latest value. Define `recoveryBindingDigest` as
   `D("lotti.learning.activity-recovery-binding.v1", complete canonical
   LearningActivityRecoveryBindingEntity body)`. The fold first selects the
   latest valid active-completion binding under this exact total comparator:

   ```text
   completionAuthenticatedInstant.latestUtcMicros   DESC
   completionAuthenticatedInstant.earliestUtcMicros DESC
   recoveryBindingDigest                            DESC
   ```

   `completionAuthenticatedInstant` is resolved through the binding's exact
   completion and that completion's owning event; binding creation, receipt, or
   projection time is never substituted.

   ADR 0032's `LearningSupportExposureEntity` and
   `learningSupportExposureRecorded` event
   distinguish actual learner-visible answer-bearing exposure from generation,
   sync, or an unopened surface. Define
   `supportExposureOccurrenceDigest =
   D("lotti.learning.support-exposure-occurrence.v1",
   SupportExposureOccurrenceDigestBodyV1(supportExposureArtifactRef,
   learningSupportExposureRecordedEventRef, authenticatedInstantRef))`. The quiet-
   boundary fold then selects the latest
   eligible active binding or same-concept answer-bearing support occurrence by:

   ```text
   selectedExposure.instant.latestUtcMicros          DESC
   selectedExposure.instant.earliestUtcMicros        DESC
   recoveryBindingOrSupportExposureDigest            DESC
   ```

   The third field is the selected binding's `recoveryBindingDigest` or the
   selected occurrence's `supportExposureOccurrenceDigest`. Digest order is only
   a final representation tie-break after authenticated-time equality; it never
   resolves material eligibility, concept, classification, or authority
   conflict. Process-only cues, passive non-answer content, accommodations,
   background generation, result arrival, and unopened surfaces are not quiet-
   boundary exposures. Ambiguous concept/classification or causal/time ordering
   fails closed rather than being ordered by digest.

   For `activityRecoveryRequired`, no valid active binding projects
   `waitingForLearningActivity`; answer-bearing exposure alone cannot satisfy
   that prerequisite. Once a binding exists, the quiet boundary is the later of
   its completion boundary and every definitely later valid same-concept answer-
   bearing exposure boundary. For `attemptAnchored`, the baseline is submission
   latest plus its interval; any valid post-attempt active binding or answer-
   bearing exposure may move the effective deadline to the later of the baseline
   and that exposure's pinned quiet boundary. With no valid later exposure, it
   falls back to the original attempt deadline and never projects
   `waitingForLearningActivity`.

   If the selected binding or exposure becomes invalid, the fold selects the
   next valid item under the corresponding comparator and then applies the same
   branch-specific fallback. Evaluation,
   repair, closure rebuild, result arrival, audit, and retry times never become
   timing anchors. A qualifying exposure arriving after protected engagement
   does not replace the question or create an automatic sibling: preserve the
   work, show a timing notice, and do not claim that the quiet interval was
   satisfied. A submitted response is a new learner act; any updated automatic
   check waits for its own valid quiet boundary. Explicit user-requested checks
   do not rewrite an existing automatic opportunity. An actively submitted
   completion with frozen `assistanceCondition = answerBearing` remains
   practice-only: it may satisfy the missing activity prerequisite and restart
   the quiet interval. Merely revealing answer-bearing help cannot satisfy the
   activity prerequisite, but its exposure occurrence postpones the quiet
   boundary. Neither fact can promote concept history, change the source
   interval class, or become unaided/transfer evidence. The same pre-/post-
   protected-engagement replacement rule applies to both.

   Each boundary is an `AuthenticatedDeadlineRef` derived from the selected
   source-event instant and pinned relative-duration specification. Automatic
   presentation waits until trusted current time's earliest value reaches the
   canonical deadline boundary. `waitingForLearningActivity`,
   `waitingForQuietInterval`, `scheduleTimeUnavailable`,
   `scheduleSelectionConflict`, `schedulePolicyConflict`, and
   `protectedHistorical` are distinct projected states, not overloaded
   timestamps or generic suppression reasons.
9. Generic-invitation and prepared-session dispositions are candidate-scoped
   where necessary, so an offline sibling cannot immediately prompt again.
   Before effort begins, a dimension-only prepared item discloses that it offers
   focused feedback but no aggregate label/score, demonstrated result, or
   spacing/history promotion, and offers regenerate, switch operation, or skip.
   Its automatic preview does not consume the aggregate-check burden allowance;
   only an explicit, versioned dimension-only acceptance consumes the separate
   focused-feedback allowance.
   Prompts are non-modal, advisory, and never gate finalization. Learners retain
   Later, Skip, Already know, Not relevant, quiet-window, disable, assistance,
   concept/operation, and manual-invocation controls.
10. A canonical global scope owns global enablement, delivery-device choice,
    cooldown/burden ceilings, and display defaults. Scope preferences may only
    tighten a global value. A rebuildable global burden projection folds offer,
    engagement, and disposition events across every scoped verifier log by a
    deterministic `BurdenEventKey`, never the fresh causal-message append ID.
    Every input is persisted: global scope, normalized burden kind, candidate,
    candidate action epoch, immutable invitation/session surface, and disclosure,
    engagement, disposition, or authenticated-deadline discriminator derived
    from the pinned defer specification. Every disposition kind is mapped.
    Duplicate appends use the earliest ADR 0033 authenticated causal instant;
    reopening creates a new epoch, so a genuine later action cannot collapse
    into the prior one.
11. Automatic presentation is allowed only on the selected delivery device
    while sync reports a fresh global frontier. Other, disconnected, or
    partitioned devices expose pending checks only after explicit user action.
    The selected device counts its not-yet-uploaded local events before another
    offer, so scoped coordinators on that host share one window.
12. Schedule authority is durable and separate from exact assessment bytes.
    ADR 0033 persists this content-addressed contract and its typed support
    links:

    ```text
    ScheduleAdmissionAuthority =
        directAdmission(ArtifactRef)
      | settledAdmissionReviewAuthority(ArtifactRef)

    AssessmentGroupKey = UUIDv5(
      "lotti.learning.schedule-assessment-group.v1",
      scopeRef,
      sourceAttemptRef,
      evaluationRequestRef,
      rubricMajor,
      assessmentValidatorPolicyRef,
      assessmentSemanticAgreementPolicyRef
    )

    ScheduleAssessmentSemanticBodyV1(
      schemaVersion,
      assessmentGroupKey,
      sourceAttemptRef,
      conceptRef,
      rubricMajor,
      assessmentOutcome,
      ratingAvailability,
      scheduleEligibilityDecision,
      assistanceCondition,
      admissionAuthority = ScheduleAdmissionAuthority,
      assessmentValidatorPolicyRef,
      scheduleQualificationPolicyRef
    )

    sourceAssessmentSemanticDigest = D(
      "lotti.learning.schedule-assessment-semantics.v1",
      ScheduleAssessmentSemanticBodyV1)

    NormalizedScheduleSemanticBodyV1(
      schemaVersion,
      scheduleSourceLineageKey,
      assessmentGroupKey,
      rubricMajor,
      sourceAttemptRef,
      conceptRef,
      scheduleEligibilityDecision,
      assistanceCondition,
      assessmentOutcome,
      ratingAvailability,
      sourceAssessmentSemanticDigest,
      admissionAuthority = ScheduleAdmissionAuthority,
      scheduleSelectionPolicyRef
    )

    normalizedScheduleSemanticDigest = D(
      "lotti.learning.schedule-semantic.v1",
      NormalizedScheduleSemanticBodyV1)

    groupStableSemanticAuthorityDigest = D(
      "lotti.learning.schedule-direct-authority.v1",
      (assessmentGroupKey, normalizedScheduleSemanticDigest))

    settledAuditNodeStateDigest = D(
      "lotti.learning.schedule-audit-node-state.v1",
      (assessmentAuditRequestRef, resolution,
       displayAssessmentSemanticDigest?,
       qualifyingAssessmentSemanticDigest?,
       selectedScheduleAssessmentSemanticDigest?, materialFindingsDigest,
       observedResultGroupFrontierDigest,
       observedAuditLineageFrontierDigest))

    ScheduleAuditAuthorityBodyV1(
      schemaVersion,
      assessmentAuditRequestRef,
      settledAuditNodeStateDigest,
      selectedScheduleAssessmentSemanticDigest,
      normalizedScheduleSemanticDigest,
      materialFindingsDigest,
      orderedDominatedAuditNodeSemanticDigests,
      admissionReviewPolicySetDigest,
      assessmentAuditPolicySetDigest
    )

    groupStableAuditNodeSemanticDigest = D(
      "lotti.learning.schedule-audit-authority.v1",
      ScheduleAuditAuthorityBodyV1)

    ScheduleSelectionKey = UUIDv5(
      "lotti.learning.schedule-selection.v1",
      scheduleSourceLineageKey,
      normalizedScheduleSemanticDigest
    )

    LearningScheduleSelectionAuthorityEntity(
      schemaVersion,
      scheduleSourceLineageKey,
      scheduleSelectionKey,
      assessmentGroupKey,
      conceptRef,
      sourceAttemptRef,
      scheduleEligibilityDecision,
      normalizedScheduleSemanticBody = NormalizedScheduleSemanticBodyV1,
      normalizedScheduleSemanticDigest,
      authority = directAgreement(groupStableSemanticAuthorityDigest)
                | auditSettlement(groupStableAuditNodeSemanticDigest),
      admissionAuthority = ScheduleAdmissionAuthority,
      scheduleSelectionPolicyRef,
      orderedPredecessorMaximalSelectionAuthorityRefs
    )
    ```

    The tagged `ScheduleAdmissionAuthority` must resolve either the direct
    content-addressed admission artifact or ADR 0032's currently effective,
    group-stable settled-admission-review authority for the exact source attempt.
    Its canonical ref commits the complete authority body/digest. The resolved
    digest, exact blueprint/question/evidence lineage, admitted `ConceptRef`, and
    authorization-pinned policy set must all agree. A stale, disputed, blocked,
    missing, or digest-mismatched authority admits no schedule selection.
    Canonical encoding and `D` are exactly ADR 0033's version-pinned primitives;
    implementations may not hash a display projection or stochastic result ID.
    Every field repeated outside `NormalizedScheduleSemanticBodyV1` must
    byte-match its value inside that body, and the stored digest and
    `ScheduleSelectionKey` must recompute exactly; mismatch fails closed.

    Exact assessment, audit-result, and agreeing-representation refs are linked
    support, not authority identity. A disputed group has no schedule authority
    until an audit explicitly and independently selects `scheduleAssessmentId`.
    A later agreeing representation may add support without changing existing
    semantics. A material audit, eligibility, admission, or semantic-selection
    change creates a child authority in the same source lineage. Its UUID v5
    authority ID covers the complete body under
    `lotti.learning.schedule-selection-authority.v1`; a non-genesis child must
    name every valid maximal predecessor at its complete causal prefix, and the
    predecessor graph must be acyclic. Recorder frontiers and support lists are
    not identity. The effective authority is the unique valid maximal semantic
    descendant. Materially incomparable maxima project
    `scheduleSelectionConflict` and emit no automatic due. Canonical ID order
    may choose among byte-distinct representations of identical semantics but
    never resolve a material choice. The atomic authority append requires
    `verificationScheduleSelectionLineage`,
    every exact `verificationScheduleSelectionSupportAssessment`, and every
    declared predecessor link. The lineage link targets the immutable source-
    lineage entity from decision 8; the typed admission authority in the body
    must resolve to a retained registered artifact even when it is not an
    `AgentLink` endpoint.

    Schedule-policy generations are global configuration authority, not local
    constants or due-artifact fields invented by each recorder:

    ```text
    SchedulePolicyLineageId = UUIDv5(
      "lotti.learning.schedule-policy-lineage.v1",
      globalScopeRef,
      compatibilityMajor
    )

    SignedPolicyActivationUnsignedBodyV1(
      schemaVersion,
      purpose = schedulePolicy(schedulePolicyLineageId)
              | activityContract(activityContractLineageId)
              | deletionCollectionPolicy(collectionPolicyLineageId),
      generationNumber,
      activatedBodyDigest,
      predecessorSetDigest,
      activationGlobalFrontierRef,
      controlKeyRevisionRef,
      authoritySequence,
      activationPolicyRef
    )

    LearningSignedPolicyActivationEntity(
      unsignedBody = SignedPolicyActivationUnsignedBodyV1,
      signature = Ed25519.Sign(
        controlPrivateKey,
        D("lotti.learning.policy-activation-signature.v1", unsignedBody))
    )

    LearningSchedulePolicyGenerationEntity(
      schemaVersion,
      schedulePolicyLineageId,
      generationNumber,
      completePolicyBody(intervals, timingBasisPolicy, authenticatedTimePolicy,
                         activityCompletionAndRelevancePolicies,
                         compatibilityContract),
      policySemanticDigest,
      signedActivationRef,
      orderedPredecessorMaximalGenerationRefs,
      activationGlobalFrontierRef
    )

    policySemanticDigest = D(
      "lotti.learning.schedule-policy-semantics.v1",
      completePolicyBody)

    SchedulePolicySemanticKey = UUIDv5(
      "lotti.learning.schedule-policy-semantic-key.v1",
      schedulePolicyLineageId,
      policySemanticDigest)

    SchedulePolicyActivatedBodyV1(
      schemaVersion,
      schedulePolicyLineageId,
      generationNumber,
      completePolicyBody,
      policySemanticDigest,
      predecessorSetDigest = D(
        "lotti.learning.schedule-policy-predecessor-set.v1",
        orderedPredecessorMaximalGenerationRefs),
      activationGlobalFrontierRef
    )

    schedulePolicyActivatedBodyDigest = D(
      "lotti.learning.schedule-policy-activated-body.v1",
      SchedulePolicyActivatedBodyV1)
    ```

    `policySemanticDigest` is exactly
    `D("lotti.learning.schedule-policy-semantics.v1", completePolicyBody)`.
    For `purpose = schedulePolicy`, `activatedBodyDigest` must equal
    `schedulePolicyActivatedBodyDigest`; other purposes use their owning ADR's
    complete activated-body digest.
    `SchedulePolicySemanticKey` is the exact UUID v5 above; no generation artifact ID
    or recorder frontier is part of that semantic key.
    `signedActivationRef` must resolve to the complete signed entity above; its
    `activatedBodyDigest`, lineage, generation, predecessor-set digest, and
    frontier must recompute from the generation. It is valid only when
    `controlKeyRevisionRef` is the trusted global learning-configuration key
    effective at `activationGlobalFrontierRef`, carries
    `schedulePolicyActivation`, and authorizes the exact `authoritySequence`.
    An ordinary event-author key, administrator role string, bundled app
    constant, or locally trusted device is not activation authority. Unknown,
    revoked, compromised, future, sequence-invalid, or frontier-inapplicable
    control keys fail closed. Genesis is accepted only through the installed
    trusted control root; key bootstrap, rotation, revocation, compromise, and
    recovery use ADR 0033's signed global control-key lifecycle.
    `schedulePolicyGenerationRecorded` may be a system event, but its event-
    author attestation never substitutes for this activation signature.
    Registered learning-activity contracts use the same signed activation
    entity with `purpose = activityContract` and the corresponding capability.

    A generation is otherwise valid only when its predecessor set covers every
    maximal generation at the activation frontier, its lineage is acyclic, and
    `generationNumber == max(predecessor generationNumber) + 1` (or the
    registered genesis value). Concurrent semantically identical maxima merge
    by semantic digest; materially different incomparable maxima project
    `schedulePolicyConflict`. Unknown or incompatible policy generations fail
    closed. Downstream timing uses the semantic policy digest, while exact
    generation refs remain audit support. Policy records remain retained while
    any historical due, protected branch, or assessment references them. The
    atomic append requires `verificationSchedulePolicyScope`,
    `verificationSchedulePolicyActivation`, and one
    `verificationSchedulePolicySupersedes` link per declared predecessor; no
    unlinked activation or predecessor ref participates in the fold.
    `learningActivityContractRecorded` uses the same global scope and requires
    `verificationRegisteredActivityContractScope`,
    `verificationRegisteredActivityContractActivation`, and one
    `verificationRegisteredActivityContractSupersedes` per predecessor; its
    contract body and compatibility policy are covered by the control-key-signed
    activation before any completion may reference it.

    The selected timing and due bodies are likewise exact:

    ```text
    LearningReviewTimingBasisEntity(
      schemaVersion,
      scheduleSourceLineageKey,
      scheduleSelectionAuthorityRef,
      schedulePolicySemanticKey,
      sourceAttemptSubmissionInstantRef,
      selectedActiveRecoveryBindingRef?,
      selectedQuietBoundaryExposureRef = activeCompletionBinding(ref)
                                       | answerBearingSupportExposure(ref)
                                       | none,
      basis = attemptAnchored(originalAttemptDeadlineRef,
                              minimumPostExposureQuietInterval)
            | activityRecoveryRequired(quietInterval),
      effectiveDueDeadlineRef
    )

    LearningSpacedReviewDueEntity(
      schemaVersion,
      reviewDueOpportunityKey,
      scheduleSourceLineageKey,
      scopeRef,
      conceptRef,
      scheduleSelectionAuthorityRef,
      normalizedScheduleSemanticDigest,
      reviewTimingBasisRef,
      reviewTimingBasisDigest,
      schedulePolicySemanticKey,
      authenticatedDeadlineRef,
      recomputedDeadlineBoundary
    )
    ```

    `selectedActiveRecoveryBindingRef`, when present, must identify the active-
    binding comparator's winner. `selectedQuietBoundaryExposureRef` must identify
    the quiet-boundary comparator's winner. `activityRecoveryRequired` requires
    both; without an active binding it has no timing basis or due and projects
    `waitingForLearningActivity`. `attemptAnchored` permits no active binding and
    `none`; then it pins `effectiveDueDeadlineRef` to the original attempt
    deadline. An active binding or answer-bearing support exposure pins the later
    of that deadline and the selected exposure's quiet boundary.
    `reviewTimingBasisDigest` is
    `D("lotti.learning.review-timing-basis.v1", complete canonical
    LearningReviewTimingBasisEntity body)`. The due ID is UUID v5 under
    `lotti.learning.spaced-review-due.v1` over its complete body above. Exact
    assessment representations, recorder frontiers, and policy-generation
    representation refs are excluded from that body.
    The timing-basis append has exact lineage, selection-authority, source-
    attempt, deadline, and tagged active-binding/support-exposure links. It also
    has one-or-more
    `verificationReviewTimingBasisSchedulePolicyGenerationSupport` links to
    every observed effective generation reproducing its
    `SchedulePolicySemanticKey`; equivalent supports may accrue without changing
    timing-basis identity. The `none`/active-binding-only tags forbid a support-
    exposure link, and a selected exposure requires exactly one.

    `LearningEligibilityScheduler` re-evaluates on projection commits, app
    foreground/resume, the nearest authenticated candidate/defer deadline, a
    learning-activity completion, a relevant support-exposure event, and
    effective review-deadline changes. It
    never treats a bare `nextEligibleAt`, `nextReviewAt`, or receiver-local clock
    value as authority. A due opportunity waits for a related meaningful durable
    work context, then appends a host-invariant spaced-review artifact and one or
    more host-specific qualification observations. The due artifact is keyed by
    `ReviewDueOpportunityKey` and the selected child variant: complete
    selection authority, concept identity, review timing basis, semantic
    schedule-policy key, and recomputed
    `AuthenticatedDeadlineRef`. It contains no exact assessment representation
    or recorder frontier.

    The due append is atomic with exactly one owning
    `verificationSpacedReviewDue` scope link, exactly one
    `verificationSpacedReviewDueSelectionAuthority`, exactly one
    `verificationSpacedReviewDueTimingBasis`, and one-or-more
    `verificationSpacedReviewDuePolicyGenerationSupport` links to every observed
    effective generation with the exact `SchedulePolicySemanticKey`. Each linked entity must resolve
    to the keys/digests in the due body and be the fold's effective valid
    semantic key at that causal prefix. A later semantically equivalent
    generation adds another support link and does not rewrite the due;
    material replacement creates an unengaged child variant or, after protected
    engagement, only historical provenance.

    Each due observation pins one exact supporting assessment, selection-
    authority representation, current admission authority, qualification
    frontier, host, and meaningful context. Typed links are
    `verificationSpacedReviewObservationSourceAssessment`,
    `verificationSpacedReviewObservationDue`,
    `verificationScheduleSelectionSupportAssessment`, and
    `verificationSpacedReviewCandidate`; the observation body pins the current
    admission authority, which must byte-match the due-linked selection
    authority's tagged admission authority. Multiple support
    observations remain normalized rather than being collapsed to one scalar
    assessment. Only the unique effective selection/policy/timing variant inside
    the outer opportunity may emit a signal or candidate.

    Before protected engagement, loss or replacement of the selected assessment
    support, activity completion, recovery binding, support exposure, registered
    activity contract, timing basis, admission authority, selection authority,
    or policy generation suppresses obsolete descendants and
    recomputes the one effective child. After protected engagement, the
    opportunity-wide rule in decision 7 preserves learner work and suppresses
    every automatic sibling. `WakeOrchestrator` continues to own content-free
    background wakes, which may append due/policy facts or prepare
    already-authorized work but never present a prompt. Newly eligible
    interactions appear on the next foreground.

## Consequences

- Prompt decisions are replayable, testable, explainable, and resistant to
  prompt injection.
- No evidence or inference is used merely because invitations are enabled.
- Candidate invitations and prepared prompts require distinct persistence,
  projection, UI, and disposition contracts.
- Global burden is reproducible across scoped logs, while disabling automatic
  presentation on stale/partitioned devices favors user agency over prompt
  availability.
- The staged policy prevents unavailable evidence/model facts from entering the
  preflight score and forces threshold recalibration.
- Duplicate cross-device work may consume extra inference until an optional
  coordinator exists, but it cannot overwrite user engagement or corrupt state.
- Schedule and promotion eligibility may legitimately diverge, so projections,
  audit UI, export, and tests must preserve two independent decisions rather
  than exposing one generic “qualifying” flag.
- Typed completion contracts avoid treating passive activity as learning, while
  independently recorded answer-bearing exposure conservatively postpones an
  unengaged quiet boundary without satisfying the active-learning prerequisite.
- Globally governed schedule-policy generations and retained historical
  authority add configuration and migration cost in exchange for replayable,
  cross-device scheduling.
- Deterministic signals may miss useful moments; manual verification remains the
  fallback.
- No cadence or threshold is treated as pedagogically valid until delayed
  outcomes, equity slices, and burden support it.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0002: Wake Scheduling and Throttling Policy](./0002-wake-scheduling-and-throttling-policy.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0018: Convergent Multi-Device Execution](./0018-convergent-multi-device-execution.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
