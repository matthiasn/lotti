# ADR 0033: Learning Verification Session Persistence

- Status: Proposed
- Date: 2026-07-18

## Context

Verification spans devices and time: a checkpoint is observed, a privacy-neutral
invitation may precede evidence access, evidence and a question are frozen, the
learner may defer or answer, evaluation may retry, and an assessment may be
appealed or deleted. Mutable status rows would create last-write-wins conflicts,
while live evidence or mutable question text would make history irreproducible.

The current agent message shape has no verification-event discriminator, and an
agent UUID does not make its scope recoverable. External workspace evidence,
unfinished drafts, and optional original responses also have different sync and
retention boundaries from privacy-approved learning history. Finally, current
Lotti releases have no cross-device lease and cannot assume old clients preserve
unknown entity bodies.

## Decision

Persist verification as typed causal messages plus immutable referenced
artifacts, with explicit synced and device-local boundaries.

1. The verifier's `AgentMessageEntity`/`AgentLink.messagePrev` DAG is the sole
   ordering authority, as required by ADR 0016. Add a typed, versioned
   `LearningVerificationEventEnvelope(schemaVersion, scopeRef,
   claimedCausalInstant, authorAttestation, event)` to
   `AgentMessageMetadata`; each discriminated payload carries its required
   fields. Do not use a generic nullable ID bag or `operationId`. Message
   links provide causal order; any wall-clock comparison uses only a versioned
   `AuthenticatedCausalInstantRefV2` derived from the signed claim, never bare
   `createdAt` or receipt time. The persisted `LearningEventAuthorAttestation`
   binds message/event, author host/key epoch, vector counter, instant/prior
   clock attestation, parents, and owned artifact/link refs. It survives relay/
   backfill; nullable transport `originatingHostId` is not authentication. Free
   text remains in referenced artifacts. A validated `ObservedLogFrontierRef` may commit one
   scoped artifact to a resolved prefix of another agent log for completeness
   checks; it is explicitly not a `messagePrev` edge and creates no cross-agent
   causal precedence.

   Any frontier embedded by an artifact or event into the **same** agent/scope
   log as its owning message obeys the strict-parent-prefix rule. Let `P(M)` be
   the complete ancestor closure of owning message `M`'s declared causal
   parents, excluding `M`. Every tip and ancestor in the embedded frontier must
   be a member of `P(M)`; the frontier may contain neither `M`, another artifact
   owned by `M`, nor a concurrent/later message. When a schema calls the
   frontier complete for a record class, its ordered tips must equal the
   recomputed maxima of that class inside `P(M)`, not merely a caller-selected
   subset. Ownership links identify `M`, so this rule is validated without
   adding the owner digest to an artifact's identity. A same-log frontier that
   violates the rule is quarantined rather than truncated. Cross-log
   `ObservedLogFrontierRef` values remain dependency commitments and are checked
   against the referenced log's resolved ancestor closure; they do not create
   causal order.

   Signing and hashing are non-circular and byte-exact. Let `C_v1(value)` be the
   version-pinned canonical payload encoder: duplicate or unknown fields are
   rejected, integers are lossless, null is explicit, strings retain their exact
   UTF-8 bytes, and every set/ref collection is sorted by its normative key. Let
   `D(tag, value) = SHA-256(UTF8(tag) || 0x00 || C_v1(value))`. The message
   commitment is:

   ```text
   MessageCommitmentBodyV1(
     envelopeSchemaVersion, messageId, agentId, threadId, messageKind,
     createdAt, scopeRef, claimedCausalInstant, canonicalVectorClock,
     orderedCausalParentMessageRefs, completeDiscriminatedEventPayload,
     orderedNewlyOwnedArtifactRefs, orderedNewlyOwnedLinkRefs
   )

   messageCommitmentDigest =
     D("lotti.learning.message-commitment.v1", MessageCommitmentBodyV1)
   ```

   `createdAt` is signed for audit/display but never trusted as time authority.
   The author then signs every attestation field, not merely the message digest:

   ```text
   AuthorAttestationUnsignedBodyV1(
     schemaVersion, signatureAlgorithm = ed25519, hostId,
     authorKeyRevisionRef, keyEpoch, authorVectorCounter,
     authorTimeChain = continue(priorAuthorAttestationRef)
                     | authorizedReset,
     priorTrustedClockAnchorRef, messageCommitmentDigest
   )

   signatureInput =
     D("lotti.learning.author-attestation-signature.v1",
       AuthorAttestationUnsignedBodyV1)
   signature = Ed25519.Sign(authorPrivateKey, signatureInput)
   authorAttestationDigest =
     D("lotti.learning.author-attestation-record.v1",
       (AuthorAttestationUnsignedBodyV1, signature))
   sourceEventPayloadDigest =
     D("lotti.learning.source-event-payload.v1",
       (envelopeSchemaVersion, scopeRef, claimedCausalInstant,
        completeDiscriminatedEventPayload))
   ```

   `authorizedReset` is a bare discriminant. The enclosing
   `authorKeyRevisionRef` and `priorTrustedClockAnchorRef` are the sole signed key
   and baseline references for both chain variants; a nested duplicate or a
   second baseline is noncanonical and rejected. Reset validation additionally
   requires that the outer key revision is the exact independently authorized
   genesis/recovery revision and that the outer anchor is its fresh trusted
   baseline.

   Validation recomputes every value, requires
   `vectorClock[hostId] == authorVectorCounter`, and rejects mutation of any
   message, attestation, parent, artifact, or link field. The independently
   signed clock-anchor record uses the same construction:

   ```text
   TrustedClockAnchorUnsignedBodyV1(
     schemaVersion, clockDomainId, authorityId, authorityKeyRevisionRef,
     authorityKeyEpoch, anchorSequence, priorAnchorRef?, anchorEventId,
     coveredEventFrontierRef, physicalUtcMicros, uncertaintyMicros,
     timeAuthorityPolicyRef
   )

   clockAnchorSignature = Ed25519.Sign(
     authorityPrivateKey,
     D("lotti.learning.clock-anchor-signature.v1",
       TrustedClockAnchorUnsignedBodyV1))
   trustedClockAnchorDigest =
     D("lotti.learning.clock-anchor-record.v1",
       (TrustedClockAnchorUnsignedBodyV1, clockAnchorSignature))
   ```

   `anchorEventId` is preallocated and is not a message/attestation digest; an
   anchor body may not point to the digest of the event that owns it. Likewise,
   no artifact may embed an `AuthenticatedCausalInstantRefV2` or deadline derived
   from its own owning event. Such derived refs exist only after the atomic
   append and may be used by projections or later artifacts.
   Clock anchors, sequence fences, schedule-policy activations, registered-
   activity-contract activations, and deletion-collection-policy activations use
   one independently bootstrapped global trusted-control-key registry. It is
   distinct from peer-author keys and may never sign an ordinary learning event.
   Capabilities are explicit and fail-closed:

   ```text
   TrustedControlCapability = clockAnchor | sequenceFence
                            | schedulePolicyActivation
                            | activityContractActivation
                            | deletionCollectionPolicyActivation

   TrustedControlKeyChangeAuthorizationBodyV1(
     schemaVersion, owningEventId, authorityId, keyLineageId, keyEpoch,
     orderedCapabilities,
     observedControlRegistryFrontier, policyRef,
     change =
         genesis(publicKey, keyId, effectiveFromAuthoritySequence,
                 independentUserConfigurationAuthorityRef,
                 deploymentTrustRootRef)
       | rotation(priorKeyRevisionRef, newPublicKey, newKeyId,
                  effectiveAfterAuthoritySequence)
       | recovery(orderedResolvedMaximalKeyRevisionRefs,
                  newPublicKey, newKeyId, effectiveFromAuthoritySequence,
                  independentUserConfigurationAuthorityRef)
       | revocation(targetKeyRevisionRef, revokedAfterAuthoritySequence,
                    independentUserConfigurationAuthorityRef)
   )

   LearningTrustedControlKeyRevisionEntity(
     id = UUIDv4,
     authorizationBody,
     newKeyProofOfPossession?,
     previousOrTargetKeyAuthorization?
   )

   LearningTrustedControlKeyCompromiseInvalidationEntity(
     schemaVersion, authorityId, targetKeyRevisionRef,
     capability,
     invalidFromAuthoritySequenceInclusive,
     invalidThroughAuthoritySequenceExclusive?,
     observedTargetRecordFrontier,
     independentUserConfigurationAuthorityRef,
     authorizingUnaffectedControlKeyRevisionRef?, policyRef
   )
   ```

   Proof of possession and previous/target-key authorization use domains
   `lotti.learning.trusted-control-key-pop.v1` and
   `lotti.learning.trusted-control-key-change-authorization.v1` over the complete
   body. Genesis/recovery additionally require independent configuration
   authority; a compromised target key cannot authorize its own invalidation.
   Epoch advancement, exact-maxima recovery, ambiguity, range invalidation, and
   revocation boundaries follow the peer-key fold, partitioned by authority
   lineage and capability. Each signed control record names the exact key
   revision, epoch, capability, and monotonically increasing authority sequence.
   It is valid only in one unambiguous interval with that capability and outside
   every applicable compromise range. Changing capabilities requires a new
   validated revision; mutable flags are forbidden.

   A gap-free fence has one exact signed representation:

   ```text
   SignedSequenceFenceUnsignedBodyV1(
     schemaVersion,
     fenceDomain = peerRegistry | deletionClosure,
     fenceId,
     issuerAuthorityId,
     controlKeyRevisionRef,
     keyEpoch,
     authoritySequence,
     orderedCoveredLogPrefixes(
       logRef(agentId, scopeRef, streamEpoch),
       contiguousFromSequenceInclusive,
       contiguousThroughSequenceInclusive,
       prefixMerkleRoot,
       orderedHeadMessageRefs,
       resolvedAncestorClosureDigest,
       gapSetDigest = CANONICAL_EMPTY),
     priorFenceRef?,
     fencePolicyRef
   )

   fenceSignature = Ed25519.Sign(
     controlPrivateKey,
     D("lotti.learning.sequence-fence-signature.v1",
       SignedSequenceFenceUnsignedBodyV1))
   signedSequenceFenceDigest = D(
     "lotti.learning.sequence-fence-record.v1",
     (SignedSequenceFenceUnsignedBodyV1, fenceSignature))
   ```

   `fenceId` is a preallocated UUID, not a content-derived owner/message digest.
   Validation requires one unambiguous trusted-control-key interval with
   `sequenceFence` capability, exact domain and authority sequence, valid
   signature, and no applicable compromise invalidation. Every covered prefix
   obeys the strict-parent-prefix rule for a same-log owner or the resolved
   cross-log dependency rule otherwise. Its start/end sequence is contiguous,
   its heads and ancestor-closure/Merkle digests recompute, and its gap set is
   canonically empty. A successor must preserve prior covered bytes and advance
   the issuer sequence exactly. A missing/duplicate record, unresolved head,
   gap, regression, wrong domain/capability, or incomparable fence maximum fails
   closed; digest order never selects a fence. Anchor validation applies the
   same registry rules with `clockAnchor` capability and requires continuous
   anchor sequence or an independently authorized reset. Learning events cannot
   bootstrap this authority. The roster, peer-author roots, trusted-control
   roots, deployment trust root, and independent configuration bridge are
   installed atomically before durable verification is enabled.
2. The event union covers schedule-source-lineage recording, schedule-policy
   generation/selection authority, deletion-collection-policy generation,
   learning-activity completion/recovery binding, learner support exposure, user
   review reminder,
   spaced-review due opportunities/observations, candidate observation/policy/
   reconsideration, invitation offer, preparation authorization, evidence
   capture, blueprint build/admission and admission-review request/cancellation/
   failure/result/semantic-authority settlement, session offer/engagement/
   attempt/disposition, peer-author-key and trusted-control-key revision/
   compromise invalidation,
   sync-peer enrollment, peer-capability revisions, and authenticated-time
   validation support,
   evaluation retry/generation/
   active-peer snapshot/capability observation/unavailability and evaluation/
   assessment-audit request/cancellation/failure/result, authorization snapshot/
   invalidation root/application, appeal/audit-sample, consent/preference
   revision, candidate reopen/session supersession, and deletion request/GC-
   membership snapshot/activation observation/required-host authority/membership
   cutoff/reopen authorization/barrier/signed sequence fence/closure manifest/
   closure generation/acknowledgment
   observation/acknowledgment authority/reachability proof/retention observation/
   retention authority, GC completion certificate, collection intent, physical-
   collection receipt, and marker.
   `candidatePreparationAuthorized` uses a tagged
   `backgroundConsent`, `invitationAcceptance`, or user-kind `manualInvocation`
   source and pins `PreparationGenerationId` plus the complete canonical
   `AdmissionReviewPolicySet` body/digest and complete `AssistanceSelection`.
   Background uses `backgroundDefault(choice, contributing preference refs,
   observed frontier, fold policy)`; invitation/manual sources use `explicit`.
   Invitation acceptance is not another event. Manual invocation pins
   its durable UI request, explicit assistance choice, action epoch, and `manualEvidence`
   authorization without creating an invitation. Defer/decline/skip/dismiss uses
   `promptDispositionRecorded` with an invitation-or-session surface. Policy
   artifacts carry suppressed/evidence-blocked outcomes. There are no duplicate
   state-named or semantic blocked-admission events.
   `questionBlueprintAdmissionFailed` represents request execution/schema
   failure; a validated blocked admission uses
   `questionBlueprintAdmissionRecorded` followed by the final policy decision.
   `scheduleSourceLineageRecorded` owns one immutable
   `LearningScheduleSourceLineageEntity` and names its scope and source attempt.
   `learningActivityCompletionRecorded` owns one completion and names its exact
   source event/concept; the completion cannot embed this owning event's instant.
   A later `learningActivityRecoveryBindingRecorded` owns one binding and names
   the completion plus `ScheduleSourceLineageKey`.
   `learningSupportExposureRecorded` is a signed user event that owns one
   `LearningSupportExposureEntity` for support actually presented to the
   learner. The event supplies the authenticated occurrence instant after
   append; the artifact cannot embed that instant or its owning event. Provider
   result arrival, background generation, an unopened notification, sync, and
   projection never create this event.
   `learningReviewReminderRecorded` owns a user-authored reminder whose deadline
   spec is resolved from that event only after append. Schedule-policy generation,
   schedule-selection authority, and spaced-review-due events name their complete
   authority/timing refs and exact support observations.
   `learningTrustedControlKeyChanged` and
   `learningTrustedControlKeyCompromiseInvalidated` own exactly one corresponding
   control-key artifact and its required authority/PoP links. Genesis/rotation
   may use a system message only with the embedded independent/signature proofs;
   recovery/revocation and compromise invalidation require a user or independently
   authenticated configuration-authority message.
   `deletionCollectionPolicyGenerationRecorded` is system-kind in the global
   scope and owns one `LearningDeletionCollectionPolicyEntity`, its signed
   activation, and the complete predecessor-maxima set. Its activation key must
   carry `deletionCollectionPolicyActivation`. For deletion GC,
   `verificationDeletionGcMembershipReopenAuthorized` is a user/configuration-
   authority event that owns one reopen authorization;
   `verificationDeletionGcMembershipCutoffRecorded` is system-kind and owns one
   initial or reopened cutoff plus its peer-registry sequence fence;
   `verificationDeletionGcClosureFenced` owns one `deletionClosure` sequence
   fence, closure manifest, and closure generation;
   `verificationDeletionAcknowledged` owns one host observation and, when first
   needed, its stable acknowledgment authority;
   `verificationDeletionGcCompletionAuthorized` owns one completion certificate;
   `verificationDeletionGcCollectionCommitted` owns one collection intent;
   and `verificationDeletionGcCollected` owns one true
   post-collection receipt. Every owned artifact has its event-artifact link in
   the same transaction. Required typed links connect control-key change to its
   predecessor/authority, fence to key revision/prior fence/covered prefixes,
   reopen authorization to predecessor cutoff/request/user authority, cutoff to
   reopen authorization/fence/deadline,
   closure manifest to barrier/fence/roots/edges/targets/markers/shared payloads,
   acknowledgment to host authority/manifest, collection policy to global
   scope/activation/predecessors, intent to completion/manifest/collection
   policy, and receipt to intent/manifest/registered collection-domain authority.
   Missing, extra, or wrong-endpoint links invalidate the whole owning
   transition.
3. Add immutable `LearningVerifierScopeEntity` anchors for ordinary verifier
   scopes and one canonical non-interactive global policy scope. A
   `LearningScopeRef(schemaVersion, scopeType, opaqueScopeId)` excludes labels
   and absolute roots. The global scope owns global preferences/burden
   projection identity, the authoritative opaque sync-peer enrollment roster,
   peer-author-key registry, trusted-control-key registry and signed sequence-
   fence chains, signed deletion-collection-policy lineage, and separate peer-
   capability advertisement registry, never evidence or sessions.
4. Add immutable synced artifacts for semantic candidate, host-specific
   candidate observation, schedule-source lineage, typed learning-activity
   completion/recovery binding, learner support exposure, independent user
   reminder, normalized schedule-selection authority, spaced-review due
   opportunity/one-to-many qualification observations,
   staged policy decision,
   generic invitation,
   consent/preference revision, authorization snapshot/invalidation/marker,
   privacy-safe evidence manifest, exact-question blueprint, independent
   blueprint build/admission requests/results, admission-review request/result/
   group-stable authority, global peer-author-key and trusted-control-key/
   compromise invalidation, signed deletion-collection-policy generations,
   sync-peer enrollment, peer-capability revisions, authenticated-time validation
   support, and authenticated deadlines,
   session, sanitized attempt, canonical evaluation generation/active-peer
   snapshot, evaluation capability observation/unavailability/request, assessment,
   assessment-audit sample/request/result, operation failure/execution observation,
   disposition, appeal,
   deletion request/GC-membership snapshot/activation observation/required-host
   authority/membership cutoff/reopen authorization/barrier/signed sequence
   fence/closure manifest/closure generation/
   acknowledgment observation/acknowledgment authority/reachability proof/
   retention observation/retention authority, GC completion certificate,
   collection intent, physical-collection receipt, and marker. Typed links
   enforce endpoint/cardinality and the
   complete ownership/digest chain.
   The schedule/activity graph uses the exact link variants
   `verificationScheduleSourceLineageScope`,
   `verificationScheduleSourceLineageAttempt`,
   `verificationScheduleSelectionLineage`,
   `verificationScheduleSelectionSupportAssessment`,
   `verificationSpacedReviewDue`,
   `verificationSpacedReviewDueSelectionAuthority`,
   `verificationSpacedReviewDueTimingBasis`,
   `verificationSpacedReviewDuePolicyGeneration`,
   `verificationSpacedReviewObservationDue`,
   `verificationSpacedReviewObservationSourceAssessment`, and
   `verificationSpacedReviewCandidate`. Each lineage links exactly one scope and
   one source attempt; each selection authority links exactly one lineage and
   its complete exact-support assessment set; each due links exactly one owning
   scope, selection authority, timing basis, and signed policy generation; and
   each observation links exactly one due and one exact supporting assessment.
   A candidate link is valid only from the fold's effective due. The graph also
   includes exactly one direct session → underlying-admission link plus an
   optional session → group-stable admission-review-authority link. These
   relationships are written and validated in the same atomic transition as
   their owning artifacts/events.
   Each `LearningActivityCompletionEntity` has UUID v5 identity over scope,
   exactly one `ConceptRef`, closed activity kind, tagged verifier-practice or
   registered-workflow source, completion-evidence digest, assistance condition,
   ordered support events, separate accommodation refs, and completion/relevance
   policies. A registered source contract pins exact event schema, completion
   predicate, concept rule, actor/clock authority, allowed kinds, and evidence/
   assistance requirements. A content-addressed
   `LearningActivityRecoveryBindingEntity` names exactly one completion, source
   lineage, concept, and binding policy. Its graph uses
   `verificationLearningActivityCompletionScope`,
   `verificationLearningActivityCompletionSource`,
   `verificationLearningActivityCompletionAttempt`,
   `verificationLearningActivityCompletionContract`,
   `verificationLearningActivityRecoveryBindingCompletion`, and
   `verificationLearningActivityRecoveryBindingLineage`. Scope → completion,
   completion → exact source event when that event is an agent-domain link
   endpoint, optional completion → attempt/originating assessment, binding →
   completion, and binding → the immutable lineage entity are mandatory. The
   contract link occurs exactly once for `registeredWorkflow` and is forbidden
   for `verifierPractice`. Deletion and authorization invalidation traverse the
   complete typed graph.

   The persistent support-exposure body is exactly:

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

   Its ID is UUID v5 under `lotti.learning.support-exposure.v1` over the complete
   canonical body; ID, artifact digest, owning event, authenticated instant, and
   sync envelope are excluded. The atomic owning transition adds exactly one
   `verificationSupportExposureScope`,
   `verificationSupportExposureSession`,
   `verificationSupportExposureBlueprint`, and
   `verificationSupportExposureSourceArtifact` link. It adds exactly one
   `verificationSupportExposureContract` only for
   `registeredWorkflowSupport` and forbids that link for the other source tags.
   Every endpoint and digest must resolve the tagged source bytes. A same-ID/
   different-body artifact, missing or extra source/contract link, concept
   mismatch, unknown classification, or event that does not represent actual
   learner-visible presentation fails closed.
   `LearningReviewReminderEntity` is a UUID v4 user action containing scope,
   optional exact concept, deadline spec, and optional user label. It has only a
   reminder → scope/concept relationship and never links into automatic schedule
   authority. Its derived deadline is projection/later-artifact state, not a
   same-event field.
   A privacy-safe evaluation-capability observation links exactly one attempt
   and authorization snapshot and contains only generation/host/contract/route
   digests, the effective peer-state digest and contributing roster/capability
   refs, plus categorical eligibility—never roots, paths, or content.
   Evaluation unavailability always links its attempt. Policy-gate forms have no
   capability/request/failure links; capability exhaustion links exactly the
   selected observation for every active peer and no request/failure. Terminal-
   repair form adds exactly two ordered parent/repair request links and the
   complete one-or-more-per-request terminal failure links at its canonical
   execution/capability frontiers. Endpoint, ordinal, frontier, and deletion
   validators treat those links as one atomic contract.
   The generation owns the deadline/derivation anchor, route/authorization,
   required-capability contracts, and evaluation/capability/unavailability/
   membership/snapshot/fold/authenticated-time policy versions plus exact
   heartbeat window. Its source is an `AuthenticatedCausalInstantRefV2`; its
   `AuthenticatedDeadlineRef` uses that interval's latest instant plus the
   pinned duration. Every
   observation/request/unavailability validates its generation-owned fields
   against it. The active-peer snapshot references one complete immutable
   `ObservedLogFrontierRef` to the global peer-policy log, filtered key/
   enrollment/capability set digests, contributing facts/actions/instant refs,
   and folded state for
   every enrolled host, making both an unknown legacy peer and historical
   membership replayable.
   `LearningPeerAuthorKeyRevisionEntity` is an append-only tagged host/key-epoch
   registry. Its canonical `KeyChangeAuthorizationBodyV1` contains
   `schemaVersion`, preallocated `owningEventId`, `hostId`, `keyLineageId`,
   `keyEpoch`, complete `observedKeyRegistryFrontier`, `policyRef`, and exactly
   one variant carrying its counter boundary:

   - `genesis(publicKey, keyId, effectiveFromCounter, authoritativeRosterRef,
     independentUserEnrollmentAuthorityRef)`;
   - `rotation(priorKeyRevisionRef, newPublicKey, newKeyId,
     effectiveAfterCounter)`;
   - `recovery(orderedResolvedMaximalKeyRevisionRefs, newPublicKey, newKeyId,
     effectiveFromCounter, independentUserConfigurationAuthorityRef)`; or
   - `revocation(targetKeyRevisionRef, revokedAfterCounter,
     independentUserConfigurationAuthorityRef)`.

   Genesis, rotation, and recovery carry a new-key proof of possession over the
   complete authorization body using domain
   `lotti.learning.key-proof-of-possession.v1`; rotation additionally carries the
   prior key's signature over that body using
   `lotti.learning.key-change-authorization.v1`. Normal revocation is signed by
   the target key at its boundary and independently user-authorized. Suspected
   compromise instead creates a separate
   `LearningPeerAuthorKeyCompromiseInvalidationEntity` naming host, target key,
   half-open invalid counter range, complete observed target-event frontier,
   independent user authority, unaffected authorizing key when present, and
   policy. A compromised key cannot authorize its own compromise action.

   Bootstrap self-authentication is a narrow atomic exception. Only a genesis or
   recovery `learningPeerAuthorKeyChanged` event may attest with the newly owned
   key revision. Validation first resolves the independent roster/user authority,
   canonical revision body, and proof of possession, then verifies that one
   event's signature. Its attestation key ref, payload ref, owned artifact ref,
   host, epoch, counter boundary, and preallocated owning event ID must match.
   The exception grants no sibling event or extra key artifact. An ordinary
   unbound self-signed event is quarantined. Genesis may reset the author-time
   chain; recovery may do so only with its independent authority and fresh prior
   trusted-clock baseline.

   The fold validates authorities before representation. Genesis has no accepted
   predecessor and pins its initial epoch through the independent authority;
   rotation/recovery use one plus the maximum predecessor epoch, while revocation
   retains its target epoch. Overflow is invalid. Rotation extends the unique
   current maximum and is signed by the old key, with the new key valid only
   after the boundary. Recovery must name
   exactly every current maximal revision at its complete frontier; partial
   coverage remains conflicted. Revocation preserves signatures through its
   boundary and admits no later ordinary event under that key. Compromise
   invalidation rejects every event in its counter range, including late
   arrivals, and removes dependent authority without deleting history.
   Incomparable genesis/rotation/recovery maxima project `authorKeyConflict`;
   digest order never chooses. An ordinary event is authoritative only when
   exactly one nonrevoked key interval covers its counter and its prior-
   attestation chain crosses every applicable boundary. Concurrent active reuse
   of one `keyId` by different hosts is rejected. Rotation never rewrites valid
   history, relay/backfill preserves the child's attestation, and unsigned legacy
   events are audit-only.
   `LearningSyncPeerEnrollmentRevisionEntity.enrolled` is UUID v5 over its
   complete host-invariant body: host, authoritative roster event ref/digest/
   authenticated instant, schema, and policy. Recorder host/time/frontier are in
   its fresh signed event, so concurrent recorders reference identical fact
   bytes and a duplicate recorder event after retirement cannot reactivate it.
   Heartbeat/retirement/restoration are independent UUID v4 actions with complete
   payload digests. `LearningPeerCapabilityRevisionEntity.unknownBootstrap` is
   likewise UUID v5 over host, first-enrollment fact, canonical unknown fields,
   schema, and policy; migration-recorder data is excluded. Advertisements are
   independent UUID v4 actions pinning build and signed release manifest.
   Actor rules are mandatory after attestation validation: enrollment resolves
   authoritative roster provenance; heartbeat, advertisement, observation, and
   acknowledgment author host equals payload host; unknown bootstrap requires
   migration authority/roster proof; retirement/restoration requires explicit
   user configuration authority. Claimed transport origin is never proof.

   `AuthenticatedTimePolicy` pins accepted clock bridges, HLC monotonicity,
   maximum future skew/uncertainty/offline age, and deadline-boundary rules.
   `AuthenticatedCausalInstantRefV2` is content-addressed only over source message
   ID/commitment, source-event payload digest, author-attestation digest, clock
   domain, recomputed earliest/latest interval, and time-policy ref. Its digest
   uses domain `lotti.learning.authenticated-causal-instant.v2`. A later clock
   anchor is deliberately excluded from identity.

   Each later anchor is persisted through a separate content-addressed
   `TimeValidationSupportEntity(instantRef, validationClockAnchorRef,
   authenticatedTimePolicyRef, observedClockAuthorityFrontierRef)`, with its
   content digest under `lotti.learning.time-validation-support.v1`. Multiple valid supports therefore cannot change
   an enrollment fact, generation, snapshot, deadline, or due identity. Where a
   historical closure must freeze proof completeness, a separate
   `TimeValidationDecisionRef` names the instant, complete observed clock-
   authority frontier, ordered support refs, and policy; host-invariant semantic
   entities never embed recorder-selected support.

   An instant becomes authoritative only when its message/attestation/key chain,
   HLC successor or authorized reset, causally prior baseline anchor, registered
   bridge, and at least one later anchor covering the source event all validate,
   and no known required-authority anchor at the complete clock frontier
   contradicts it. The following overflow-checked inequalities are the sole
   normative offline-age and future-skew predicates:

   ```text
   source.latestUtcMicros - priorAnchor.earliestUtcMicros
     <= authenticatedTimePolicy.maxOfflineAnchorAgeMicros

   source.latestUtcMicros
     <= validationAnchor.earliestUtcMicros
        + authenticatedTimePolicy.maxFutureSkewMicros
   ```

   A predicate using either anchor's `latestUtcMicros`, receiver wall time, or
   receipt time is invalid. A revoked, conflicting, incomplete, or unresolved
   authority produces `timeUnresolved`/`timeFault`.

   Enrolled time comes from the roster event; heartbeat/advertisement/observation
   from the self-authenticated event; retirement/restoration from the authorized
   configuration event; bootstrap from first enrollment; acknowledgment from its
   owning event. Authority-bearing future boundaries use an immutable
   `AuthenticatedDeadlineRef(sourceArtifactRefAndField, baseInstantRef,
   derivationSpec, canonicalBoundaryUtcMicros, authenticatedTimePolicyRef,
   deadlinePolicyRef, digest)`. Its derivation is a relative duration from the
   base interval's latest edge, an explicit UTC target, or an explicit local
   target that pins timezone, tzdb version, and overlap choice and rejects DST
   gaps. The digest uses domain `lotti.learning.authenticated-deadline.v1`.
   A boundary is reached only when trusted current time's earliest instant is at
   or after it. An event is definitely on/before only when its latest instant is
   at/before, definitely after only when its earliest instant is after, and is
   otherwise ambiguous.

   A candidate observation stores the registered source instant rather than bare
   `occurredAt`. Policy `nextEligible`, invitation/session availability/expiry,
   prompt deferral, generation/runtime request deadlines, liveness expiry,
   spaced-review due, GC cutoff, and retention use authenticated deadline refs.
   `createdAt`, provider timing, and local purge time remain audit/display data.
   When an artifact first declares a deadline for its own owning event, it stores
   only the canonical derivation spec; the ref is derived after append and may be
   referenced only by a projection or later artifact. Invalid actor/signature is
   hard-quarantined; unresolved time blocks any membership/snapshot/GC or prompt
   reduction that would otherwise fail open. A roster host with unresolved time
   is `activeTimeUnknown`.

   Enrollment folding is executable: first enrollment initializes liveness to
   its authenticated interval; a valid heartbeat updates it with `max`; retirement latches and
   wins concurrent positive revisions; enrolled/heartbeat events after a latch
   are audit-only until a restoration causally covers every retirement;
   restoration then clears the latch and initializes liveness from the
   authenticated configuration instant. Concurrent valid positive branches merge
   by maximum validated interval, never receipt time. A restoration concurrent with a still-maximal
   retirement is ineffective. Capability folding treats unknown bootstrap as a
   neutral placeholder that a valid self-authenticated concurrent/later
   advertisement may replace; materially divergent concurrent advertisements
   are `ambiguousIncompatible`. Canonical ID chooses only between semantically
   equivalent representations.
   Active membership requires a nonretired folded state and liveness inside the
   versioned window, so enrollment/restoration makes an unknown-capability host
   active immediately and fail closed.
   Cross-log dependency uses a validated
   `ObservedLogFrontierRef(agentId, scopeRef, orderedTips, frontierDigest)`, which resolves
   the target log's complete ancestor closure. It is not a `messagePrev` edge and
   creates no cross-agent causal precedence.
   A generation may reference multiple immutable historical active-peer
   snapshots. Deterministic code derives one required peer frontier as the join
   of every definitely pre-deadline key/enrollment/capability creation event and
   recomputes the expected snapshot solely from that frontier/generation/fold.
   Boundary-ambiguous/time-unresolved input prevents authority. The one matching
   content-addressed artifact is effective; superseded history is projection
   metadata and never appears in snapshot identity. Thus equal joined frontiers
   create equal replacement bytes even when peers know different historical
   scoped snapshots. Frontier-incomparable snapshots are invalid once observed
   together. A late pre-deadline action permanently invalidates the incomplete
   snapshot and dependent closure. Its scoped event need not and cannot descend
   from global-log events. The generation becomes `closureRebuildPending`; its
   passed deadline prohibits new calls, and only a fresh closure over an
   effective replacement or an explicit retry/new generation may proceed.
   Policy-gate unavailability has no snapshot link; capability and terminal
   forms link exactly one currently effective snapshot.
   Capability-observation validation partitions generation-owned fields from
   host-owned status/frontier fields. A deadline-eligible observation must
   match the snapshot's exact effective-peer digest and contributing refs.
   Missing, mismatched, post-deadline, deadline-ambiguous, time-invalid, or authority-invalid observations are
   stale. After causal-maximal selection, `eligible` conservatively defeats a
   concurrent ineligibility claim and disagreeing noneligible statuses remain
   ambiguous/pending; semantic equals may choose a canonical representation.
   Consent has a canonical scope, item-review, research-export, or efficacy-
   study subject. The study subject pins protocol/version and disclosure of
   randomization, control feedback delay, rescue, withdrawal, data, and
   retention; it neither implies nor is implied by research-export consent. An item-review subject
   pins a canonical reviewer-disclosure manifest, separate from dispute-lineage
   inputs, that enumerates the owner, every lineage artifact, every reviewer-
   visible evidence/response/appeal/prior-finding artifact, synced payload, or
   local-content digest plus the complete executor-neutral
   `LearningRequiredCapabilityContract` body, its recomputed digest, and origin-
   capture attestation, route,
   redaction policy, and exact redacted-preview digest. Item consent and the
   review/audit request link and match every manifest byte. Local-content refs
   never create synced blobs. The canonical neutral contract contains schema/
   policy, scope, adapter kind/API major, a closed implementation-version rule
   plus pinned compatibility-matrix digest, required capability enums, opaque
   revision/descriptor refs, required local availability, and content/redaction/
   privacy versions; it excludes host, root, and binding generation. Its
   host-bound origin attestation is provenance. An executor proves its own
   current attestation satisfies exact contract fields, the pinned version
   compatibility rule, capability superset, and exact local content availability.
   Unknown fields or unavailable compatibility data fail closed; a bare digest
   is never interpreted without its body. Any expanded or altered disclosure
   requires new consent.
5. Candidate identity covers verifier scope, owning workflow and workflow ID,
   source run/signal, and checkpoint type, and excludes policy and host-specific
   authority. Each candidate-observation artifact separately pins mode-specific
   source fields/metadata/adapters/capture policy plus its exact
   authorization snapshot, avoiding same-ID conflicts across devices. Session
   actions use a deterministic epoch: `initial` or derived from the exact
   disposition/invitation-expiry artifact on candidate reopen. Decisions,
   invitations, sessions, dispositions, and reopen events persist that epoch.
   Session identity covers candidate, evidence-manifest digest, settled admission-
   authority plus staged policy decisions, source/scope, inference profile,
   availability/expiry derivation inputs, privacy/authorization bytes, and the
   `PreparationGenerationId` plus complete `AdmissionReviewPolicySet` body/
   digest and complete replayable `AssistanceSelection` first pinned by the
   action epoch's effective preparation-authority
   event. Build/admission/review requests and the final policy decision must
   byte-match both.
   Every artifact derives `artifactDigest` from the complete canonical immutable
   payload; ID, that derived digest, and the sync envelope are outside the
   payload, and `ArtifactRef.digest` always means this complete-payload digest.
   Deterministic/content-addressed IDs are UUID v5 over it, while explicitly
   user/execution-owned UUID v4 IDs remain independent. The session ID uses the
   deterministic contract, so no byte-varying
   body field can collide. The immutable session names this authority as pinned;
   later effective review authority is
   projection state. Blueprint identity pins
   exact question/locale/template/objective/operation/rubric/evidence/
   assistance bytes; admission is separately content-addressed after the final
   blueprint digest exists.
   Generic-invitation and evidence-snapshot IDs likewise cover their complete
   canonical immutable payloads, including deterministic time-derivation inputs,
   authorization/schema/privacy, missing/redaction/coverage, and payload refs as
   applicable; abbreviated tuples cannot share an ID with different bytes.
   Candidate observation atomically writes the host-invariant candidate anchor,
   host-specific observation, required links, and one event.
   For external sources, `automaticInvitations` authorizes only a privacy-neutral
   observation with opaque connector event/frontier IDs, coarse allow-listed
   policy flags, and a digest computed solely over those neutral fields. Paths,
   symbols, exact revisions, detail-committing digests, labels, concept text,
   and metadata remain in an
   expiring local table unless `syncExternalEvidenceManifest` separately permits
   a scanned sanitized observation.
   Evaluation-request identity also covers its complete canonical execution
   payload, including authorization, route/profile, prompt/schema/privacy,
   calibration, assessment-validator/scorer/rating policy, generation/repair,
   and deadline inputs. Volatile execution
   token, latency, provider-transaction, host, and timing data lives in separate
   unique execution-observation artifacts; the authenticated result-completion
   instant belongs to the causal event.
6. `LearningAuthorizationSnapshotEntity` freezes purpose-to-consent revision IDs
   and digests, provider privacy confirmation/profile, authorized adapters,
   external-manifest/derived-content sync permissions, output-scan policy, local-
   origin/capture capability-attestation digest, ordered executor-neutral
   required-capability contract bodies plus recomputed digests, and causal
   frontier. A peer applies the deterministic satisfaction predicate above to
   its own current attestation rather than matching the origin digest. Candidate observation,
   every `candidatePreparationAuthorized` event, evidence capture, session
   identity, blueprint build/admission, admission review, evaluation, and
   assessment audit pin the relevant snapshot. Runtime rechecks authority before each adapter/model call and
   before derived persistence. A concurrent revoke wins, cancels/discards late
   work, and produces an invalidation root plus deterministic per-artifact/link
   markers over every concurrent/later observation, preparation authority,
   policy/invitation descendant, evidence, support exposure,
   build/admission/review, session,
   evaluation capability/unavailability/request/audit, failure/execution
   observation, and derived descendant. A
   preparation event is effective only while its pinned snapshot is valid; its
   revocation projects `evidenceBlocked(authorizationInvalidated)` and cannot
   leave the candidate `preparing`. Typed due-observation → exact schedule-
   assessment support links and validated timing-basis/completion-source refs
   extend the closure to spaced-review work only when the last valid support or
   effective timing authority is invalidated/no longer schedule-eligible.
   Newly arriving offline
   descendants receive the same marker. Invalid observations/unengaged work are
   excluded; user attempts remain visible with a warning while evaluation/
   display/promotion is blocked. Causally earlier completed history is not
   retroactively erased. Authorization invalidation is a logical authority and
   presentation boundary only. It may evict ordinary recomputable memory/cache
   entries, but it does not authorize physical removal of any persisted artifact,
   link, payload, response, or evidence byte; it has no per-host purge
   acknowledgment, GC completion, collection intent, or receipt. Physical
   erasure requires a separately authenticated, explicit user
   `LearningDeletionRequestEntity` whose target selector covers the invalidation
   root or affected history. Only that deletion request may enter decision 12's
   applicable marker, membership, closure,
   intent, collection, and receipt lifecycle. This keeps a
   consent revoke from being silently reinterpreted as a deletion request.
   A group-stable admission-review authority does not inherit terminal
   invalidation merely from one support snapshot. The affected request/result/
   observation and authority-support links are marked and projection recomputes
   from remaining support; the authority artifact is marked only when its
   selected admission or semantic blueprint/group lineage is intrinsically
   invalid. Zero support makes it ineffective but allows a later reauthorized
   request to support the same byte-identical authority ID.
7. Atomic repository transitions write new artifacts, links, and one fresh causal
   message together through `AgentSyncService`. Equal immutable IDs are
   insert-or-verify-byte-identical on canonical payload; author host, vector
   clock, database time, and other sync-envelope fields are excluded. Conflicts
   are quarantined. Per-kind actor validation compares the authenticated sync-
   envelope author or user authority with the claimed host/roster provenance
   before any peer revision or capability observation can commit. Original
   artifact IDs are never mutated for deletion.
8. Correctness is lease-independent. Equal candidate/request work deduplicates by
   semantic identity; equal validated stochastic outputs deduplicate while
   byte-distinct outputs retain unique result IDs. Supersession may target
   only unopened branches at its observed frontier. Late protected engagement
   overrides the supersession projection, restores the effective engaged/
   attempted/assessment state, and permits evaluation when every other authority,
   evidence, and calibration check remains valid; the supersession event stays
   in audit history. Multiple engaged branches remain grouped
   parallel checks and suppress further prompts; their ratings are never merged.
   Blueprint build, blueprint admission, and evaluation each use deterministic
   request identity; model concept selection runs only inside the one atomic
   blueprint-build operation. Each uses local single-flight, provider idempotency
   where available, causal cancellation/failure/result events, and one
   deterministic schema repair. Admission review
   and assessment audit additionally use first-class, authorization-pinned
   requests with generation, ordered tagged original/prior-review inputs, exact
   reviewer-disclosure manifests,
   deadline/route/calibration, and cancel/fail/complete events. Materially
   disagreeing admissions have no digest winner and require explicit review;
   every selecting admission review covers the current admission group, valid
   semantic-review lineage, and separate all-history audit lineage; assessment
   audit retains its complete base-result/prior-audit lineages. A selected
   admission must be an eligible, calibrated,
   valid request input for the same blueprint. Every initial, sibling, retry,
   and adjudication request for one admission group and one exact authority-
   affecting policy set carries the same deterministic review-lineage ID. The
   canonical `AdmissionReviewPolicySet` contains schema and review-lineage major,
   material-finding normalization, semantic-agreement, resolution/dominance,
   selected-admission eligibility, authority-validator policy, authority schema,
   and a closed route/prompt/output-schema/calibration/result-validator
   compatibility declaration plus cleared-equivalence manifest digest. Every
   preparation generation, request, node, session, and authority embeds the
   complete body and recomputed digest; the lineage ID is derived from admission
   group plus that digest. `PreparationGenerationId` also covers candidate/action
   epoch, policy digest, complete tagged source value (with artifact digests
   where applicable), authorization snapshot, and complete explicit or
   background-default `AssistanceSelection`. Background selection includes its
   exact preference revisions/frontier/fold policy; mutable current preferences
   are never replay input. A version change creates a separate preparation/lineage; cross-
   version results are audit-only for the old branch, and migration requires
   explicit policy reconsideration and new authorized preparation rather than
   digest selection. A frontier-complete
   request is selecting; incomplete
   requests are advisory. Every nonempty selecting request group derives a
   confirmed/blocked/further-review/disputed resolution node. An adjudication
   node dominates a prior node only when its valid frontier/tagged inputs consume
   every then-current semantic result and its consumed-node state digest matches.
   Projection removes dominated nodes, rejects any undominated disputed/blocked/
   further-review node, and requires all maximal confirmed nodes to agree.
   Materially agreeing late representations preserve node state and dominance;
   a material change reopens authority. Confirmed maximal agreement creates
   a group-stable authority artifact independent of request and stochastic
   reviewer-result identity and including the lineage's complete policy-set
   body/digest. A request may support multiple
   historical authorities and one authority may have multiple supporting
   requests/events, but projection permits at most one effective authority per
   lineage. Contradictory locally settled authorities remain audit-only after
   merge. Late agreeing results cannot rewrite a session pin, while material
   lineage expansion invalidates downstream authority. Agreeing concurrent
   reviews first satisfy a semantic-agreement predicate
   before digest order may select byte representation. Late disagreement
   preserves user work but blocks evaluation/display/promotion.
   Invalidated/deleted results remain in an audit-only lineage but are excluded
   from semantic inputs/dominance. A reauthorized request pins new authority and
   disclosure; its audit-context edges neither revive marked content nor carry
   the old invalidation transitively.
   Evaluation unavailability is also lease-independent. Host-local incapability
   remains pending/local UI. Each active peer emits a privacy-safe, generation-
   specific capability observation derived from its nonsynced attestation;
   the exact deadline-eligibility and conservative concurrent-observation fold
   above yields one semantic observation per host. Missing, stale, or ambiguous
   observations keep work pending. Synced provider/evidence
   exhaustion requires the canonical generation contract, deadline-bound active-
   peer snapshot, and complete selected-observation frontier; repair exhaustion additionally
   requires a closed generation with exact request/failure links and execution
   frontier. Projection first invalidates stale-snapshot closures and any closure
   causally after a valid result, then makes a result audit-only if it descends
   from any member of the complete remaining valid closure set, including a
   nonmaximal ancestor. Only a non-audit result concurrent with every member
   governs; maximal-antichain reduction occurs afterward for presentation and
   cannot resurrect a descendant result. Otherwise the complete maximal
   closure antichain persists: agreeing closures may choose a display
   representation, while differing reasons/remedies form an ordered union with
   no primary artifact. Invalidation of a closure snapshot requires a fresh
   closure over the effective replacement and never restores post-deadline
   execution; incomplete historical inputs require explicit retry/new generation.
   Immutable assessment reliability uses only request-pinned
   inputs/output and never mutable result-group agreement.
   Deterministic assessment sampling produces a typed sample artifact before a
   sampled audit request. Audit output independently carries nullable display,
   promotion-qualifying, and schedule assessment IDs. Schedule selection is
   included in semantic agreement and obeys resolution-specific nullability,
   input-membership, schedule/promotion invariants and, for every sample/appeal/
   dispute/adjudication source, covers recorded complete assessment-group and
   prior-audit-lineage frontiers. A late material assessment or prior-audit
   lineage disagreement clears all three selections and requires expanded adjudication; a
   late agreeing representation
   cannot replace settled IDs or invalidate a due source by digest order alone.
   A suppressed candidate returns to observation only through a registered
   policy-reconsideration event. Reopen/action validity uses each event's causal
   prefix; a causally later reopen dominates, concurrent unengaged epochs select
   the lowest epoch ID, and protected concurrent epochs remain parallel while
   suppressing more offers. Candidate reopen creates a new session branch;
   skipped, expired, and effectively unengaged-superseded sessions never reopen
   in place.
9. The synced attempt contains the exact sanitized `submittedResponseText`,
   digest, redaction policy, assistance/access/input provenance, and only support
   events causally preceding submission for rating eligibility. Post-assessment
   support never mutates it. Device-local drafts, optional originals, external
   evidence cache, and workspace bindings never enter the sync outbox.
10. Consent and preferences are immutable synced revisions. Concurrent revoke
    wins unless followed by a causally later grant. Global preference values
    dominate and ordinary scopes may only tighten them. External capture requires
    valid purpose consent plus a local root binding. Syncing external manifest
    metadata and derived learning content are separate purposes. Without both,
    stop after any privacy-neutral invitation and before blueprint/model work or
    durable derived-learning artifacts; static
    preauthored self-check guidance is not an assessment or history artifact.
11. Derive separate candidate, session, current concept-review, immutable
    assessment-history/concept, and cross-agent global-burden projections.
    Pending interactions remain a tagged union. A materially disagreeing result
    set has no primary/display assessment and cannot promote state until an audit
    explicitly names display, qualifying, and schedule IDs independently. A broad manual multi-concept
    check is always dimension-only, indexes secondary concepts only for
    discovery, and is never promotable. Cross-agent burden rows key a
    deterministic candidate action epoch plus immutable surface/action identity
    rather than a fresh message append ID or undefined generation. Every
    disposition, including defer boundary, is mapped. Every source attempt has
    one policy-invariant outer lineage:

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
    ```

    The entity ID and body must reproduce that domain and those five inputs
    exactly. Rubric, assessment group/representation, audit/admission state,
    timing basis, recovery binding, selection, and active policy generation are
    child variants and never alter the outer key. A different exact concept or
    genuinely new learner attempt creates a new lineage. A future identity
    algorithm requires a control-key-activated
    `LearningScheduleLineageMigrationEntity` mapping both immutable lineages to
    the already existing `ReviewDueOpportunityKey`; it cannot create a parallel
    protected opportunity. A `LearningScheduleSelectionAuthorityEntity`
    persists the complete
    normalized `ScheduleSelectionKey`/semantic body, group-stable direct-agreement
    or audit-settlement authority, eligibility class, admission authority,
    selection policy, and all maximal predecessor authority refs at its complete
    causal prefix. Its content-addressed predecessor graph is acyclic and partial
    maxima coverage is ineffective. Exact assessment IDs, recorder hosts/frontiers, and chosen
    time supports are excluded from its identity. Each exact assessment
    representation instead persists through a separate host/qualification-
    specific `LearningSpacedReviewDueObservationEntity` and typed observation →
    assessment, observation → due, and selection-authority → exact-support
    links. Equivalent one-to-many supports therefore add audit rows without
    changing authority or due identity; deletion/invalidation removes only the affected support, and
    the due remains supported while another valid observation exists.
    Rebuildable projections use separate completion, recovery-binding, reminder,
    selection-authority, due-group, and due-support-member tables; no group row
    stores one arbitrary assessment, completion, or support observation.

    Attempt-anchored outcomes use the exact submission event and authenticated
    baseline interval. Activity recovery admits only typed qualifying
    completions whose authenticated interval's earliest value is strictly after
    that submission interval's latest value. Define:

    ```text
    recoveryBindingDigest = D(
      "lotti.learning.activity-recovery-binding.v1",
      complete canonical LearningActivityRecoveryBindingEntity body
    )
    supportExposureOccurrenceDigest = D(
      "lotti.learning.support-exposure-occurrence.v1",
      (supportExposureArtifactRef,
       learningSupportExposureRecordedEventRef,
       authenticatedInstantRef)
    )
    recoveryBindingOrSupportExposureDigest =
        activeCompletionBinding.recoveryBindingDigest
      | answerBearingSupportExposure.supportExposureOccurrenceDigest
    ```

    The fold first selects the latest valid active-completion binding under the
    exact descending comparator
    `(completionAuthenticatedInstant.latestUtcMicros,
    completionAuthenticatedInstant.earliestUtcMicros,
    recoveryBindingDigest)`. For `activityRecoveryRequired`, the quiet-boundary
    set is that selected prerequisite binding plus every definitely later, same-
    concept, answer-bearing support occurrence. For `attemptAnchored`, the set is
    every valid post-attempt active binding or same-concept answer-bearing support
    occurrence, even when no active binding exists. The fold selects from the
    applicable set under the exact descending comparator
    `(selectedExposure.instant.latestUtcMicros,
    selectedExposure.instant.earliestUtcMicros,
    recoveryBindingOrSupportExposureDigest)`. The third field is compared in
    descending canonical byte order. It is only a final representation tie-break
    after equal authenticated intervals and never resolves concept,
    classification, causal/time, or authority ambiguity.

    `activityRecoveryRequired` projects `waitingForLearningActivity` until a
    valid active binding exists; answer-bearing support alone cannot satisfy that
    prerequisite. Once it exists, the due boundary is the later of the binding's
    completion boundary and every definitely later valid answer-bearing support
    boundary. `attemptAnchored` falls back to its original deadline and otherwise
    uses the later of that baseline and the selected post-attempt exposure's
    pinned quiet boundary. A newer answer-bearing exposure postpones only
    unengaged work and never promotes learning; invalidating it falls back to the
    next valid item. Process-only cues, passive non-answer content,
    accommodations, evaluator/repair/closure/result/retry/audit/sync latency,
    background generation, and unopened surfaces are never timing exposures.

    The unique effective selection/policy/timing child may emit one due and link
    one downstream candidate; incomparable maxima fail closed. Protected
    engagement is keyed to the whole `ReviewDueOpportunityKey`: engagement in
    any due, selection, timing, policy, device, candidate, or session branch
    preserves that learner work as `protectedHistorical` and suppresses every
    automatic sibling. A late exposure then produces a neutral timing notice and
    cannot claim that its quiet interval was satisfied; only explicit learner
    retry may request updated authority after the effective boundary. Only a
    distinct `ScheduleSourceLineageKey`, normally a new learner attempt, creates
    another automatic opportunity. An uncleared calibration route creates
    a non-assessment unavailability artifact, not an assessment/history row.
    Per generation, the same ordered group algorithm invalidates stale-snapshot
    and post-result closures, makes a result audit-only against the complete
    remaining valid closure set, permits only a non-audit result concurrent with
    every member to govern, and only then reduces closures to a maximal
    presentation antichain. Without a governing assessment,
    projection retains the complete maximal unavailability antichain. Semantic
    agreement may choose one display representation; disagreement stores an
    ordered group/union with no scalar primary. A normalized group-member
    projection preserves each closure's authority form and optional snapshot;
    a group-level shared snapshot is populated only when every member has the
    same non-null value, never for heterogeneous groups. A newer generation remains
    pending rather than inheriting an older closure.
12. `LearningDeletionRequestEntity` contains target/selector, causal
    deletion frontier, actor ref, policy major, and local-cache flags; it never
    embeds its own owning event, attestation, or authenticated instant. The
    owning event yields that instant only after the request bytes are committed.
    Target closures are normative. Session/candidate/history deletion preserves
    scope-subject consent/preferences/configuration but
    includes every item-scoped human-review consent revision and disclosure link
    whose owner is deleted, plus every session-owned evaluation generation, all
    historical active-peer snapshots, capability/unavailability artifacts, and
    their key/enrollment/capability/request/failure lineage links. Shared global
    peer-key, enrollment, and capability revisions are collected only at zero
    reachability and subject to the deletion-control retention below.
    Session deletion includes every support-exposure event/artifact whose
    `sourceSessionRef` names that session and marks its exact scope/session/
    blueprint/source/contract links; a linked source assessment, workflow event,
    or contract is collected only when ordinary reachability also reaches zero.
    Session deletion always marks the direct session →
    admission-review-authority link. The shared authority entity and its
    authority → request/admission/result links are included only after traversal
    proves zero reachability from undeleted sessions and retained review
    lineages; marked links provide no reachability. Candidate/history closures
    inherit that rule. Marked item-consent links likewise provide no payload
    reachability; only the ordinary content-free anti-resurrection marker remains.
    Configuration deletion is explicit. All-history/
    data requests live in the global scope and apply
    idempotent marker events to each affected scoped log; a crash resumes from
    the durable request rather than pretending cross-log atomicity. Each covered
    artifact/link receives a separate deterministic,
    request-independent marker over original type/ID/digest and deletion-policy
    major. Concurrent requests link to identical marker bytes. Late descendants
    receive the same marker and cannot resurrect projections or model work. A
    deleted source assessment removes its due-observation support; loss of the
    final support marks the due opportunity and unengaged downstream work;
    protected user-authored downstream sessions remain visible only under the
    source-deleted overlay until separately deleted.
    Markers traverse schedule-source lineages, support exposures, verifier-
    practice completions, recovery bindings, selection support, timing bases,
    and their typed links when owned exclusively by deleted history. User
    reminders are independent: session deletion does not infer their removal,
    while their owning scope's history/all-data closure includes them explicitly.
    Before any request that can mark global peer/deletion-control configuration
    writes its first marker, its atomic request event creates exactly one content-
    addressed `LearningDeletionGcMembershipSnapshotEntity` over the unmarked
    peer registry and complete initial fold. The initial snapshot carries only
    the membership-window derivation spec; it cannot embed a deadline derived
    from its own owning request event. No GC semantic authority contains recorder
    append time, selected clock support, or a caller-chosen frontier. Recorder-
    specific facts live in independently valid observations. Other deletion
    targets use their scoped marker/retention path and cannot invent a global-GC
    completion, intent, or receipt.

    Membership and cutoff use these exact canonical schemas:

    ```text
    LearningDeletionGcRequiredHostAuthorityEntity(
      schemaVersion, deletionRequestRef, initialMembershipSnapshotRef,
      hostId, membershipFoldPolicyRef
    )

    LearningDeletionGcActivationObservationEntity(
      requiredHostAuthorityRef, recorderHostId, activationKind,
      activationRevisionAndEventRefs,
      orderedContributingKeyAndEnrollmentRevisionRefs,
      authenticatedActivationInstantRef,
      observedRegistryStrictParentFrontierRef,
      beforeStateDigest, afterStateDigest, validationPolicyRef
    )

    LearningDeletionGcMembershipReopenAuthorizationEntity(
      id = UUIDv4, schemaVersion, deletionRequestRef,
      orderedSupersededMaximalCutoffRefs,
      observedCutoffStrictParentFrontierRef,
      requestedMembershipWindowSpec, reasonCode,
      independentUserConfigurationAuthorityRef, reopenPolicyRef
    )

    LearningDeletionGcMembershipCutoffEntity(
      schemaVersion, deletionRequestRef, initialMembershipSnapshotRef,
      cutoffGeneration,
      source = initial(deletionRequestOwningEventRef,
                       requestAuthenticatedCausalInstantRef,
                       membershipOpenDurationSpec)
             | reopen(reopenAuthorizationRef,
                      reopenAuthorizationOwningEventRef,
                      reopenAuthorizationAuthenticatedCausalInstantRef,
                      requestedMembershipWindowSpec),
      membershipCutoffDeadlineRef,
      peerRegistrySignedSequenceFenceRef,
      membershipFoldPolicyRef, cutoffPolicyRef
    )

    LearningDeletionGcMembershipBarrierEntity(
      schemaVersion, deletionRequestRef, initialMembershipSnapshotRef,
      effectiveCutoffRef, orderedRequiredHostAuthorityRefs,
      requiredHostAuthoritySetDigest, membershipFoldPolicyRef,
      barrierPolicyRef
    )
    ```

    Unless a schema explicitly declares UUID v4 or device-local identity, every
    synced GC artifact above and below is UUID v5/content-addressed over its
    complete canonical body. Equal IDs are insert-or-verify-byte-identical.
    Stable authorities exclude recorder host, observed support frontier, chosen
    clock anchor, local cursor, and append time; observation/receipt bodies retain
    the authenticated host-specific facts they attest.

    Initial membership and later enrollment/restoration/heartbeat reactivation
    normalize to one stable required-host authority per `(request, host)`;
    duplicate activation observations only add support. After the request append,
    the worker derives the initial cutoff deadline from the request event instant
    plus its pinned window. Barrier construction waits until trusted current
    time reaches that deadline and the `peerRegistry` signed sequence fence is
    gap-free through the boundary. Activations whose latest instant is at/before
    the cutoff are required; those whose earliest instant is after are post-
    cutoff; overlap, unresolved time, an invalid control key, or a fence gap
    blocks authority.

    A reopen is never inferred from a system recorder. Its user/configuration
    event must occur before any effective collection intent, name every maximal
    cutoff in its strict parent prefix, satisfy the policy's bounded extension
    and reopen-count rules, and be the sole source of a later cutoff generation.
    The reopen-authorization artifact carries only its duration spec. After its
    user event commits, the later system cutoff event derives the new deadline
    from that event's authenticated instant plus the byte-matching spec and pins
    both refs. Neither artifact embeds an instant/deadline derived from its own
    owning event.
    `cutoffGeneration` is zero for initial or exactly
    `max(superseded.cutoffGeneration) + 1`. Concurrent partial or materially
    different reopen branches remain ineffective until a later authorization
    covers every maximum. An effective reopen replaces the barrier and resets
    closure, acknowledgment, reachability, retention, completion, and intent
    authority. Once an intent is committed, membership never reopens. A newly
    discovered pre-cutoff activation before intent replaces the barrier; a post-
    cutoff host enters the return gate instead of expanding membership.

    Closure, acknowledgment, and proof bytes are exact rather than prose-only:

    ```text
    LearningDeletionGcClosureManifestEntity(
      schemaVersion, deletionRequestRef, membershipBarrierRef,
      deletionClosureSignedSequenceFenceRef,
      orderedRootRefs, rootSetDigest,
      orderedTraversalEdgeRefs, traversalEdgeSetDigest,
      orderedTargetRefs, targetSetDigest,
      orderedMarkerRefs, markerSetDigest,
      orderedSharedPayloadRefs, sharedPayloadSetDigest,
      traversalPolicyRef, markerPolicyRef, closurePolicyRef
    )

    LearningDeletionGcClosureGenerationEntity(
      schemaVersion, deletionRequestRef, membershipBarrierRef,
      generationNumber, orderedPredecessorMaximalGenerationRefs,
      closureManifestRef, closureManifestDigest, generationPolicyRef
    )

    LearningDeletionGcAcknowledgmentAuthorityEntity(
      schemaVersion, deletionRequestRef, membershipBarrierRef,
      requiredHostAuthorityRef, closureGenerationRef,
      closureManifestRef, requiredHostAuthoritySetDigest,
      markerSetDigest, deletionClosureSignedSequenceFenceRef,
      acknowledgmentPolicyRef
    )

    LearningDeletionGcAcknowledgmentObservationEntity(
      schemaVersion, acknowledgmentAuthorityRef, hostId,
      appliedDeletionControlSignedSequenceFenceRef,
      appliedClosureGenerationRef, appliedClosureManifestRef,
      appliedMarkerSetDigest,
      localLogicalPurgeManifestDigest, localPurgeState = complete,
      localValidationProofDigest, observationPolicyRef
    )

    LearningDeletionGcReachabilityProofEntity(
      schemaVersion, deletionRequestRef, membershipBarrierRef,
      closureGenerationRef, closureManifestRef,
      deletionClosureSignedSequenceFenceRef, reachabilityPolicyRef,
      evaluatedRootSetDigest, evaluatedTraversalEdgeSetDigest,
      evaluatedTargetSetDigest, evaluatedMarkerSetDigest,
      evaluatedSharedPayloadSetDigest,
      orderedRemainingReachableTargetRefs,
      remainingReachableTargetSetDigest,
      orderedRemainingSharedPayloadRefs,
      remainingSharedPayloadSetDigest
    )

    LearningDeletionGcRetentionProofAuthorityEntity(
      schemaVersion, deletionRequestRef, membershipBarrierRef,
      closureGenerationRef, retentionDeadlineRef,
      safetyRetentionPolicyRef
    )

    LearningDeletionGcRetentionProofObservationEntity(
      retentionProofAuthorityRef, trustedValidationClockAnchorRef,
      observedClockAuthorityFrontierRef
    )
    ```

    Every ordered set and digest is recomputed from the closure manifest's
    gap-free strict-parent prefix. Roots, edges, targets, markers, and shared
    payloads must match the traversal/ownership policies exactly. Closure
    generation is genesis or one greater than every named maximal predecessor;
    its predecessor graph is acyclic and incomplete maxima coverage is
    ineffective. A pre-fence descendant or edge replaces the manifest/
    generation before intent. After the fence, repository insertion either
    atomically creates the request-independent marker or rejects an unmarked edge
   to a target.

    There is one stable acknowledgment authority per required host and effective
    manifest generation. Its observation is valid only when the persisted event
    author equals `hostId`, every applied ref/digest byte-matches the authority,
    the applied sequence fence covers the manifest fence, and the local logical-
    purge manifest proves all covered caches/derived indexes are excluded.
    Multiple observations may support one authority; recorder identity and later
    local frontiers never alter it. Reachability succeeds only when both ordered
    remaining sets are empty and their digests equal the canonical empty-set
    digest. The retention deadline is derived from the deletion request's
    authenticated instant plus its pinned safety window, never from completion,
    intent, execution, or receipt time. The retention authority is stable; later
    clock observations support it without changing its identity.

    Completion, intent, local execution, and receipt are four distinct facts:

    ```text
    LearningDeletionGcCompletionEntity(
      schemaVersion, deletionRequestRef, membershipBarrierRef,
      closureGenerationRef, closureManifestRef,
      orderedAcknowledgmentAuthorityRefs,
      acknowledgmentAuthoritySetDigest,
      reachabilityProofRef, retentionProofAuthorityRef,
      completionPolicyRef
    )

    DeletionCollectionPolicyLineageId = UUIDv5(
      "lotti.learning.deletion-collection-policy-lineage.v1",
      globalScopeRef,
      compatibilityMajor
    )

    CollectionDomainRuleV1(
      collectionDomainId = agentArtifactStore
                         | syncedEvidencePayloadStore
                         | attachmentChunkStore
                         | deviceLocalLearningCache,
      coveredTargetKinds,
      collectorSet = everyRequiredPeerHost
                   | configuredCollectorHosts(orderedHostAuthorityRefs),
      receiptActorContract = signedLearningEventAuthorEqualsCollectorHost
                           | registeredStorageBridgeEqualsCollectorHost,
      localJobAdapterId,
      rulePolicyRef
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

    LearningDeletionCollectionPolicyEntity(
      schemaVersion,
      collectionPolicyLineageId,
      generationNumber,
      orderedCollectionDomainRules,
      policyBodyDigest,
      signedActivationRef,
      orderedPredecessorMaximalPolicyRefs
    )

    DeletionCollectionPolicyActivatedBodyV1(
      schemaVersion,
      collectionPolicyLineageId,
      generationNumber,
      orderedCollectionDomainRules,
      policyBodyDigest = D(
        "lotti.learning.deletion-collection-policy-semantics.v1",
        orderedCollectionDomainRules),
      predecessorSetDigest = D(
        "lotti.learning.deletion-collection-policy-predecessor-set.v1",
        orderedPredecessorMaximalPolicyRefs)
    )

    deletionCollectionPolicyActivatedBodyDigest = D(
      "lotti.learning.deletion-collection-policy-activated-body.v1",
      DeletionCollectionPolicyActivatedBodyV1)

    CollectionReceiptKey(collectorHostId, collectionDomainId)

    LearningDeletionGcCollectionIntentEntity(
      schemaVersion, deletionRequestRef, completionRef,
      membershipBarrierRef, closureGenerationRef, closureManifestRef,
      collectionPolicyRef,
      orderedRequiredCollectionReceiptKeys, requiredReceiptKeySetDigest,
      targetSetDigest, markerSetDigest, sharedPayloadSetDigest,
      deletionPolicyMajor
    )

    LearningDeletionGcLocalCollectionJob(
      jobId = UUIDv5(collectionIntentRef, collectionReceiptKey),
      collectionIntentRef, collectionPolicyRef, collectionReceiptKey,
      localJobAdapterId,
      expectedTargetSetDigest, expectedSharedPayloadSetDigest,
      phase = queued | collectingTargets | collectingSharedPayloads
             | verifyingAbsence | complete,
      canonicalPhaseCursor, attemptCount, sanitizedLastError?,
      completedPhysicalCollectionDigest?
    )

    LearningDeletionGcCollectionReceiptEntity(
      schemaVersion, collectionIntentRef, deletionRequestRef,
      completionRef, closureGenerationRef, closureManifestRef,
      collectorHostId, collectionDomainId, collectedTargetSetDigest,
      collectedSharedPayloadSetDigest,
      completedPhysicalCollectionDigest,
      collectionPolicyRef, collectionImplementationVersion
    )
    ```

    The collection-policy lineage uses the same signed activation envelope,
    strict-parent predecessor coverage, exact generation increment, semantic
    equality, and fail-closed incomparable-maxima rules as the schedule-policy
    lineage. Its activation requires an unambiguous trusted control key with
    `deletionCollectionPolicyActivation`. The owning event adds exactly one
    `verificationDeletionCollectionPolicyScope`, one
    `verificationDeletionCollectionPolicyActivation`, every required
    `verificationDeletionCollectionPolicySupersedes`, and the shared
    `verificationSignedPolicyActivationControlKeyRevision` link. For purpose
    `deletionCollectionPolicy`, the activation's lineage, generation,
    predecessor-set digest, and `activatedBodyDigest` must byte-match
    `DeletionCollectionPolicyActivatedBodyV1` and
    `deletionCollectionPolicyActivatedBodyDigest`; the entity's
    `policyBodyDigest` must equal the formula in that body. ADR 0031 owns the
    exact `SchedulePolicyActivatedBodyV1` and `ActivityContractActivatedBodyV1`
    preimages for the other two purposes; this ADR persists and validates their
    signed activation refs without defining an alternate digest formula. Unknown
    domain IDs, target kinds, collector authorities, actor contracts, or job
    adapters are invalid; a local default cannot fill a policy gap.

    The completion certificate means only that all current prerequisites agree.
    Before intent, invalidating a barrier, manifest, acknowledgment,
    reachability, or retention prerequisite rolls projection back and makes the
    completion ineffective. Persisting the immutable collection intent and
    enqueueing the nonsynced durable local job is one transaction. Intent is the
    terminal anti-resurrection boundary because physical deletion may begin
    immediately afterward; it freezes membership and makes all covered content
    permanently presentation/execution-ineligible. It is not a claim that bytes
    have been removed.

    The intent's required receipt-key set is recomputed deterministically by
    applying every rule in its effective signed policy to the exact closure
    manifest and host barrier. `everyRequiredPeerHost` expands to every required
    host; configured collectors expand to their exact signed host-authority refs.
    Every physical target kind must be covered exactly once. Overlap, omission,
    an unavailable configured collector, an extra key, or a key not derivable
    from the policy fails closed. The intent has exactly one
    `verificationDeletionGcCollectionIntentPolicy` link to that generation; a
    recorder may neither omit a host/domain nor add one it does not own.

    The local job verifies the intent and policy's current canonical bytes,
    selects only the rule's registered adapter, deletes the manifest's exact
    targets/shared payloads idempotently, checkpoints its cursor after each
    durable batch, and resumes after crash without broadening scope. Only after
    physical deletion and a full post-delete absence check may the executor
    append `verificationDeletionGcCollected` and its true receipt. Receipt
    validation requires its exact `(collectorHostId, collectionDomainId)` key to
    occur in the intent and every result digest, domain, adapter, closure, intent,
    and policy ref to match the completed local job. Under
    `signedLearningEventAuthorEqualsCollectorHost`, the persisted event origin
    author must equal `collectorHostId`. Under
    `registeredStorageBridgeEqualsCollectorHost`, the receipt's required typed
    link and independent bridge attestation must bind that exact synthetic
    collector host and registered domain. A peer or bridge cannot claim another
    collector's key. A receipt written before physical completion is invalid.
    Required hosts apply the intent and produce every domain receipt assigned to
    them;
    a post-cutoff/returning host must run the same intent-scoped local job and
    prove receipt application before learning writes.
    The terminal `collected` state requires the observed valid receipt-key set to
    equal the intent's required set exactly. Multiple valid
    executions for one host remain audit records and may select a canonical
    representation only after their expected/result digests agree; disagreement
    blocks completion and cannot be resolved by ID order.

    Hidden pre-fence data discovered after intent is quarantined, marked, and
    purged under the same request; it cannot reopen authority or re-enter a
    projection. The normative state order is `membershipCollecting →
    membershipCutoffRecorded → barrierEffective → closureFenced →
    awaitingAcknowledgments → retentionOrReachabilityPending →
    completionAuthorized → collectionIntentCommitted → collectionExecuting →
    collected`.

    Authority/observation indexes are normalized and rebuildable. Control-key
    revisions/compromise invalidations, signed fence chains, key/time support,
    enrollment/liveness, request/snapshot, reopen/cutoff/barrier, closure
    manifest/generation, markers, acknowledgment authorities, proofs, signed
    collection-policy generations/activations, completion, intent, receipts, and
    enough typed links to validate them remain
    deletion-control data through the maximum offline-return and compromise-
    discovery windows. Local jobs remain until their receipt is durable and
    verified. Only afterward may detailed observations/proof working sets compact
    under a versioned retention policy; the minimal intent/receipt and control-
    authority chain remain for the anti-resurrection lifetime.
13. A preparatory release adds four append-only logical registries in the global
    policy log: peer-author keys, trusted-control keys/capabilities, an immutable
    sync-peer enrollment roster sourced independently from the underlying sync
    membership log, and a separate capability-advertisement registry with readable/writable payload
    epochs and preservation support. It writes `unknownBootstrap` for every
    enrolled host lacking an advertisement. It also persists origin/time
    attestations in the typed event envelope and preserves them through relay/
    backfill. Current compatibility applies the authenticated actor/time constraints and executable liveness/retirement/
    restoration/capability fold above to the complete enrolled universe; every evaluation generation instead stores its canonical
    deadline contract and one-or-more historical content-addressed snapshots
    containing complete key/enrollment/capability frontiers and effective peer
    states. If any active enrolled peer is unknown, ambiguously advertised, or
    incompatible,
    durable verification is disabled before any new candidate/session/evaluation
    artifact, related outbox row, or held local history record is created;
    deletion controls for existing history remain available. There is no local-
    only/backfill mode. Active membership is versioned heartbeat-window plus
    the enrollment fold and is replayable without consulting capabilities. A
    retired/expired/returning peer must upgrade and ingest peer/control-key
    revisions and compromise invalidations, signed sequence fences, clock-anchor/
    time support, enrollment, capability, logical authorization invalidations,
    schedule-source lineages and support-exposure occurrences, deletion records,
    the effective signed deletion-collection policy, current GC barrier/manifest,
    completion certificate, collection intent, and applicable true receipts
    before learning writes resume.

    The migration is fail-closed and does not reinterpret legacy bytes. A
    same-log frontier that cannot prove the strict-parent-prefix rule, an
    attestation carrying fields inside `authorizedReset`, an unsigned/unknown-
    capability control key or fence, an old schedule lineage whose body does not
    reproduce the V1 domain/scope/concept namespace/key/version/source-attempt
    key and lacks a valid lineage-migration artifact, a support occurrence with
    no signed `learningSupportExposureRecorded` event, and an authorization-
    invalidation acknowledgment from an earlier draft schema are audit-only and
    authorize no time, quiet boundary, closure, or physical deletion. Any
    policy-less collection intent or draft/prototype “collection receipt”
    persisted before physical deletion is imported only as nonauthoritative
    collection-intent audit context; it cannot become a true receipt. The worker
    must validate or create a current completion and intent, run a new resumable
    local job, verify physical absence, and append the new receipt schema. There
    is no in-place digest rewrite. Compatibility remains disabled until every
    active peer advertises the bare-reset attestation, strict-frontier, control-
    key/fence, schedule-lineage/support-exposure, signed collection-policy,
    closure-manifest, collection-intent, local-job, and post-collection-receipt
    schema majors.

    Mandatory fixtures include golden canonical bytes/digests/signatures across
    restart, relay, and backfill; mutation of every message/attestation/anchor
    field and wrong-domain replay; rejection of nested reset key/anchor fields
    and mismatch against the sole outer key/baseline; valid genesis self-authentication plus missing
    independent authority/PoP, mismatched owning event, extra sibling artifact,
    and ordinary unbound-event rejection; rotation boundaries, concurrent
    rotations, exact-maxima versus partial recovery, normal revocation,
    compromise ranges with late arrivals, and duplicate key use across hosts.
    Trusted-control-key fixtures cover capability separation, genesis/rotation/
    revocation/recovery, exact-maxima recovery, wrong-capability fence signing,
    compromise sequence ranges, concurrent maxima, and suspect-key self-
    authorization rejection. Every artifact/event frontier family has owner,
    same-event, concurrent-tip, partial-complete-prefix, and valid strict-parent-
    prefix fixtures.
    Time fixtures include two valid later anchors yielding one causal-instant ID,
    unresolved-to-valid support arrival without semantic-ID churn, revoked or
    contradictory anchors, HLC rollback, skew/offline-age/uncertainty boundaries,
    asymmetric anchor uncertainty where a forbidden anchor-`latest` predicate
    would pass but the normative anchor-`earliest` predicate fails,
    and byte-identical peer-snapshot replacement despite different support
    arrival order. Deadline fixtures cover equality/ambiguity, DST gaps/overlaps,
    policy identity, every migrated authority-bearing time, and rejection of an
    owning-event instant/deadline cycle or receipt-time fallback. Schedule/
    activity fixtures cover passive/partial/irrelevant/model-only rejection,
    exact concept and registered-source validation; byte-exact support source/
    kind/cognitive-class/carryover bodies and required/forbidden source-contract
    links; actual-presentation events versus background generation/unopened
    surfaces; occurrence-digest tie-breaks; latest-exposure selection; next-
    latest fallback; repeated-practice postponement; one exact V1 lineage across
    rubric/group/audit/timing/policy replacement; signed identity migration
    preserving one opportunity; opportunity-wide protection; normalized one-to-
    many supports; independent reminders; and rebuild convergence. GC fixtures
    cover duplicate activation/ack observations converging on stable authorities;
    signed-fence missing/duplicate/extra sequence, wrong key capability,
    compromised range, and incomparable maxima; pre/overlapping/post-cutoff
    activation; user-authorized reopen, partial-maxima/concurrent reopen,
    bounded-window violation, and post-intent reopen rejection; late pre-cutoff
    rollback before intent; closure-manifest omitted/extra root, edge, target,
    marker, or payload; closure-generation partial predecessors; acknowledgment
    host/ref/digest/fence mismatch; canonical empty and nonempty reachability plus
    retention proofs; signed collection-policy genesis/supersession/conflict and
    wrong control-key capability; unknown/overlapping/omitted domain coverage;
    every-required-host and configured-collector expansion; unavailable
    collector; forged bridge authority; cross-host receipt claim; exact receipt-
    key equality; and prerequisite invalidation before intent. Crash fixtures
    cover intent/local-job atomic enqueue, restart before the first batch, every
    durable cursor, completion after physical deletion but before receipt, and
    receipt retry. A forged/pre-execution receipt is rejected; every required
    host receipt is required; hidden data after intent is quarantined; and a
    returning peer purges before write. Authorization invalidation alone never
    removes persisted bytes, while a separately explicit covering deletion
    request does. A known enrolled peer without a capability revision, concurrent
    retirement/heartbeat, and fail-closed old-client migration remain required.
14. Keep assessments out of the journal rating catalog. A future explicit
    “save reflection to journal” action may create a user-authored journal entry;
    no machine assessment becomes a journal fact automatically.

## Consequences

- Candidate invitations, prepared sessions, attempts, appeals, and deletions
  remain auditable and converge without overwriting one another.
- Exact questions, sanitized responses, evidence revisions, rubric/assistance,
  and evaluator provenance make assessments reproducible.
- Scope, consent, candidate, and event encoding are recoverable after restart
  instead of being left to implementation invention.
- Engagement-aware convergence protects learner work while allowing unopened
  duplicate branches to disappear.
- Stable authority/observation splits let independent recorders converge without
  placing a chosen clock proof, frontier, or append time in semantic identity.
- Authorization invalidation immediately stops use and presentation but cannot
  silently erase persisted history; physical erasure always has a separate
  user-authored deletion request and auditable GC lineage.
- The GC completion certificate remains reversible proof state until the
  separately persisted collection intent establishes the terminal anti-
  resurrection boundary. A receipt is emitted only after physical collection
  and proves execution rather than scheduling it.
- Device-local evidence/drafts/originals can expire or be unavailable on another
  peer; the synced manifest must explain that limitation and execution waits for
  a capable device or recapture.
- Canonical signing, credential/time support, deadline derivation,
  candidate/session projections, deletion closure, capability negotiation, and
  global graph cleanup add substantial implementation and migration complexity.
- New artifacts cannot sync safely until the compatibility prerequisite ships.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0018: Convergent Multi-Device Execution](./0018-convergent-multi-device-execution.md)
- [ADR 0020: Agent Input Capture](./0020-agent-input-capture.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
