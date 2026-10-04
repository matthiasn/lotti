part of 'goal_agent_workflow.dart';

/// The transactional write behind GoalAgentWorkflow.persistOutputs: the revision fence, ad state, report head and reply rows, all in one transaction.
extension _GoalOutputPersistence on GoalAgentWorkflow {
  Future<GoalOutputPersistenceResult> _persistOutputs({
    required String agentId,
    required String runKey,
    required String threadId,
    required GoalAgentStrategy strategy,
    required GoalWakeDerivation derivation,
    required DateTime now,
    DateTime? evaluationReference,
    String? escalationBaseline,
    bool replyToUser = false,
    bool userRequestedAd = false,
    String? adCreationDiscriminator,
    String? replyToMessageId,
  }) async {
    final factsReference = evaluationReference ?? now;
    final reportId = strategy.hasReport ? GoalAgentWorkflow._uuid.v4() : null;
    final attributionEnvelope = await prepareAgentReportAttribution(
      runKey: runKey,
      reportId: reportId,
    );
    var attributionFinalized = false;
    var reportHeadAdvanced = false;
    var fenced = false;
    // The banner this wake created, if any — the words the armed alert may
    // take once the transaction holding the banner has committed.
    NudgeBrief? alertBrief;

    await _syncService.runInTransaction(() async {
      // A revision approved while the model was thinking moves the head
      // on — and NOTHING from this wake may then publish beside the
      // revised goal: its report and banner describe the superseded
      // target. Checked INSIDE the output transaction so a revision
      // committing between a pre-check and these writes cannot slip
      // through. The fence keys on the derivation snapshot's ACTIVE
      // status: a stale escalation deliberately evaluates the superseded
      // version that armed its period and stays exempt.
      final headNow = await _repository.getEntity(goalSpecHeadId(agentId));
      if (headNow is! GoalSpecHeadEntity) {
        // The goal was DELETED while the model ran: recreating messages,
        // reports or banners here would resurrect rows for a hard-deleted
        // agent and sync them out after the deletion.
        fenced = true;
        return;
      }
      if (derivation.version.status == GoalSpecVersionStatus.active &&
          headNow.versionId != derivation.version.id) {
        fenced = true;
        return;
      }

      // RE-READ inside the transaction, never trust the pre-inference
      // snapshot: the user may have dismissed an ad while the model was
      // thinking, and that dismissal must bind EVERY guard below — the
      // retire skips, the cooldown, and the fresh-active check alike.
      // Scoped to THIS wake's spec: a superseded-spec banner syncing in
      // late must not satisfy the fresh-active guard and suppress the
      // current goal's banner (dismissals stay visible regardless — the
      // quiet window is the goal's, not one spec version's).
      final allRows =
          (await _repository.getEntitiesByAgentId(
                agentId,
                type: AgentEntityTypes.goalNudge,
              ))
              .whereType<GoalNudgeEntity>()
              .where((n) => n.deletedAt == null)
              .toList();
      final nudges = [
        for (final nudge in allRows)
          if (_specScopedRow(nudge, derivation.version.id)) nudge,
      ];
      final byId = {for (final nudge in nudges) nudge.id: nudge};

      // Snooze is a temporary visibility preference, not a terminal ad
      // verdict. Keep the same active row and its activation/rating history;
      // the banner provider reveals it again at the persisted instant without
      // another model call.
      for (final action in strategy.snoozeRequests) {
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status != NudgeStatus.active) continue;
        final updated =
            snoozeNudgeBannerEntity(
                  nudge: NudgeEntityView.of(nudge)!,
                  now: now,
                  until: action.until,
                  returnUtcOffsetMinutes: action.returnUtcOffsetMinutes,
                  eventId: const Uuid().v5(
                    Namespace.url.value,
                    'lotti://goal-agent/${nudge.id}/snooze/$runKey/'
                    '${action.until.toUtc().toIso8601String()}',
                  ),
                )
                as GoalNudgeEntity;
        await _syncService.upsertEntity(updated);
        // A single model turn may request several successive quiet deadlines
        // for one banner. Fold each write into the next so no append-only event
        // is overwritten by the transaction's original snapshot.
        byId[action.adId] = updated;
      }

      // Interactive replies are explicit reply_to_user action rows so the
      // durable chat projection can whitelist them without exposing thoughts.
      // Plain final prose remains a compatibility fallback for models that
      // answer before observing the new tool contract.
      final candidateAssistantText = replyToUser
          ? strategy.replyToUser ?? strategy.finalResponse
          : strategy.finalResponse;
      final assistantText =
          userRequestedAd &&
              (strategy.createdAds.isNotEmpty ||
                  strategy.rerunRequests.isNotEmpty) &&
              _isCooldownRefusal(candidateAssistantText)
          ? null
          : candidateAssistantText;
      if (assistantText != null) {
        final persistedAssistantText = replyToUser
            ? sanitizeAgentReportText(assistantText, stripBareIds: true)
            : assistantText;
        final payloadId = replyToUser
            ? _goalAgentReplyPayloadId(agentId, runKey)
            : GoalAgentWorkflow._uuid.v4();
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{'text': persistedAssistantText},
          ),
        );
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: replyToUser
                ? goalAgentReplyMessageId(agentId, runKey)
                : GoalAgentWorkflow._uuid.v4(),
            agentId: agentId,
            threadId: threadId,
            kind: replyToUser
                ? AgentMessageKind.action
                : AgentMessageKind.thought,
            createdAt: now,
            vectorClock: null,
            contentEntryId: payloadId,
            metadata: AgentMessageMetadata(
              runKey: runKey,
              toolName: replyToUser
                  ? AgentConversationToolNames.replyToUser
                  : null,
              operationId: replyToUser ? replyToMessageId : null,
            ),
          ),
        );
      }

      // Standing report + head (scope `current`). Sanitized: weaker
      // models echo the FACTS' internal ids into prose (the shared
      // report-writer behavior).
      if (reportId != null) {
        await _syncService.upsertEntity(
          AgentDomainEntity.agentReport(
            id: reportId,
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: now,
            vectorClock: null,
            content: sanitizeAgentReportText(
              strategy.reportContent ?? strategy.reportTldr!,
              stripBareIds: true,
            ),
            tldr: sanitizeAgentReportText(
              strategy.reportTldr!,
              stripBareIds: true,
            ),
            oneLiner: sanitizeAgentReportText(
              strategy.reportOneLiner!,
              stripBareIds: true,
            ),
            provenance: <String, Object?>{
              'trackStatus': strategy.reportStatus!.name,
              'periodKey': derivation.periodKey,
              'specVersionId': derivation.version.id,
              // Sanitized like every other visible string on this entity.
              // The card PREFERS these sections over the flat `content`, so
              // leaving them raw put the internal ids the sanitizer exists to
              // remove straight back in front of the reader — and made the
              // sections disagree with the sanitized fallback beneath them.
              GoalReportProvenanceKeys.sections: ?_sanitizeReportSections(
                strategy.reportSections,
              ),
              if (attributionEnvelope != null)
                aiAttributionProvenanceKey: attributionEnvelope.toJson(),
            },
            threadId: threadId,
          ),
        );
        // Out-of-order overdue escalations must not let an OLDER period
        // replace the current standing report: the head only advances
        // when this wake's period is not older than the published one.
        final existingHead = await _repository.getReportHead(
          agentId,
          AgentReportScopes.current,
        );
        final published = await _repository.getLatestReport(
          agentId,
          AgentReportScopes.current,
        );
        final publishedPeriod = published?.provenance['periodKey'];
        // A superseded-spec wake keeps its report ROW as history but
        // never advances the shared head: same-period LWW would let a
        // delayed v1 escalation hide v2's standing report behind a
        // spec-provenance filter until v2 publishes again.
        final headMayAdvance =
            derivation.version.status == GoalSpecVersionStatus.active &&
            (publishedPeriod is! String ||
                derivation.periodKey.compareTo(publishedPeriod) >= 0);
        if (headMayAdvance) {
          await _syncService.upsertEntity(
            AgentDomainEntity.agentReportHead(
              id: existingHead?.id ?? GoalAgentWorkflow._uuid.v4(),
              agentId: agentId,
              scope: AgentReportScopes.current,
              reportId: reportId,
              // Stamped with the PERIOD's end (not the wall clock) for
              // overdue periods: two devices lease-elected onto different
              // overdue periods write concurrent head versions, and LWW
              // on this timestamp then prefers the NEWER period no matter
              // which device finished last.
              updatedAt: _headTimestamp(derivation.periodKey, now),
              // Carry the head this write replaces (ADR 0068 addendum): a
              // second report for the same overdue period stamps the same
              // period end, and built on no clock it would be resolved as
              // concurrent with the head and lose the tie.
              vectorClock: existingHead?.vectorClock,
            ),
          );
          reportHeadAdvanced = true;
        }
      }

      // Deterministic recovery retire: when the authoritative status no
      // longer permits ads (back on track, recovering, data gap), every
      // still-active ad is retired HERE — the obsolete chiding banner
      // must not depend on the model remembering retire_goal_ad, nor
      // run out its 72 h staleAt.
      // A superseded-spec wake owns none of the CURRENT banners: its
      // historical facts must neither retire nor rerun rows that may
      // belong to the revised goal (creates stay — they are evidence for
      // the wake's own period, and a fresh current banner already blocks
      // them via the fresh-active guard).
      final staleSpecWake =
          derivation.version.status != GoalSpecVersionStatus.active;
      // The trend gate is for AUTOMATIC at-risk ads. In chat, a create/rerun
      // tool call is the model's structured response to the user's explicit
      // request, so every current track status is eligible. The remaining
      // persistence guards (stale spec and duplicate copy) still apply.
      final interactiveAdRequested =
          replyToUser &&
          userRequestedAd &&
          (strategy.createdAds.isNotEmpty || strategy.rerunRequests.isNotEmpty);
      final adsEligible =
          _adsEligible(derivation.facts, derivation.priors) ||
          interactiveAdRequested;
      if (!staleSpecWake && !adsEligible) {
        final modelRetired = {
          for (final action in strategy.retireRequests) action.adId,
        };
        for (final nudge in nudges) {
          if (nudge.status != NudgeStatus.active ||
              modelRetired.contains(nudge.id)) {
            continue;
          }
          await _syncService.upsertEntity(
            nudge.copyWith(
              status: NudgeStatus.retired,
              retiredAt: now.toUtc(),
              updatedAt: now,
              provenance: {
                ...nudge.provenance,
                'retireReason': 'status no longer permits ads',
              },
            ),
          );
        }
      }

      // Retire before create: a wake that swaps ads must never leave two
      // active ones if it dies between writes.
      for (final action in strategy.retireRequests) {
        if (staleSpecWake) break;
        // The in-transaction snapshot is the consistent view: only a row
        // that is STILL active retires — a dismissal (the user's
        // quiet-window verdict) or a Phase A expiry that landed first
        // survives; rewriting expired→retired would feed the clock-expired
        // ad back into the reuse library.
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status != NudgeStatus.active) {
          continue;
        }
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: NudgeStatus.retired,
            retiredAt: now.toUtc(),
            updatedAt: now,
            provenance: {...nudge.provenance, 'retireReason': action.reason},
          ),
        );
      }

      // A fresh dismissal blocks AUTOMATIC ad activity. A later, explicit
      // chat request supersedes that earlier quiet preference: the structured
      // create/rerun action is the model's typed evidence that the pending
      // user message asked for another banner.
      final cooldownActive = _factsRenderer.dismissalCooldownActive(
        nudges,
        now,
      );
      final cooldownBlocksAds = cooldownActive && !interactiveAdRequested;
      // Validate replacement material before retiring the currently visible
      // banner. A duplicate/replayed create request is not a replacement and
      // must leave the active activation intact.
      final seenDigests = {
        for (final nudge in nudges) nudge.briefDigest,
      };
      final creationId =
          'goal_nudge:$agentId:${derivation.periodKey}:'
          '${adCreationDiscriminator ?? escalationBaseline ?? derivation.facts.previousStatus?.name ?? 'first'}:'
          '${derivation.version.id}';
      final hasViableCreatedReplacement =
          !allRows.any((nudge) => nudge.id == creationId) &&
          strategy.createdAds.any(
            (request) => !seenDigests.contains(
              goalBriefDigest(sanitizeNudgeBrief(request.brief)),
            ),
          );
      final hasViableRerunReplacement = strategy.rerunRequests.any(
        (action) => byId[action.adId]?.status == NudgeStatus.retired,
      );
      final hasViableInteractiveReplacement =
          interactiveAdRequested &&
          (hasViableCreatedReplacement || hasViableRerunReplacement);
      // Automatic ads remain limited to offTrack or worsening atRisk (P4/P5).
      // A structured ad action on an interactive atRisk wake is the explicit
      // user-requested exception computed above.
      // A rating evaluates one activation; it does not make the card vanish
      // immediately. Once the user explicitly asks for another banner,
      // however, that rated activation is complete and is retired here so the
      // replacement can land even if the model omitted retire_goal_ad.
      final explicitlyRetiredNow = {
        for (final action in strategy.retireRequests) action.adId,
      };
      final replacedRetiredNow = <String>{};
      if (hasViableInteractiveReplacement && !staleSpecWake && adsEligible) {
        for (final nudge in nudges) {
          if (nudge.status != NudgeStatus.active ||
              explicitlyRetiredNow.contains(nudge.id)) {
            continue;
          }
          replacedRetiredNow.add(nudge.id);
          await _syncService.upsertEntity(
            nudge.copyWith(
              status: NudgeStatus.retired,
              retiredAt: now.toUtc(),
              updatedAt: now,
              provenance: {
                ...nudge.provenance,
                'retireReason': 'replaced by explicit chat request',
              },
            ),
          );
        }
      }
      // P6: a fresh active ad blocks a second one. Ads retired in THIS
      // wake don't count — explicit retire+create and rated replacement both
      // remain legal.
      final retiredNow = {...explicitlyRetiredNow, ...replacedRetiredNow};
      var freshActiveExists = nudges.any(
        (n) =>
            n.status == NudgeStatus.active &&
            !retiredNow.contains(n.id) &&
            now.difference(n.activatedAt ?? n.createdAt) < goalAdFreshFor,
      );
      for (final action in strategy.rerunRequests) {
        if (staleSpecWake) {
          logError('rerun suppressed: the wake ran under a superseded spec');
          continue;
        }
        if (!adsEligible) {
          logError('rerun suppressed: status does not permit ads');
          continue;
        }
        if (cooldownBlocksAds) {
          logError('rerun suppressed: dismissal cooldown active');
          continue;
        }
        if (freshActiveExists) {
          logError('rerun suppressed: a fresh active ad already exists');
          continue;
        }
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status != NudgeStatus.retired) {
          continue;
        }
        freshActiveExists = true;
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: NudgeStatus.active,
            activationCount: nudge.activationCount + 1,
            activatedAt: now.toUtc(),
            staleAt: now.toUtc().add(goalAdLifetime),
            snoozedUntil: null,
            lastSnoozeDuration: null,
            dismissedForDayAt: null,
            updatedAt: now,
            runKey: runKey,
            threadId: threadId,
            provenance: {
              ..._withoutGoalBannerSnooze(nudge.provenance),
              'rerunReason': action.reason,
              // Re-stamp the evidence fingerprint: the re-run is a fresh
              // acknowledgment of the CURRENT facts, so later Phase A
              // sweeps must compare against this wake's derivation.
              'factsDigest': goalFactsDigest(
                derivation.facts,
                criteria: derivation.version.criteria,
                evaluationReference: factsReference,
              ),
            },
          ),
        );
      }

      // Near-duplicate guard: the digest exists to stop the same copy
      // accumulating rows — across the library and within one response.
      // Automatic creation ids derive from the LOGICAL escalation — its
      // period plus the ARMING baseline carried on the wake's trigger tokens —
      // never from locally observed row counts (which differ across
      // partitions) nor from the re-derived previousStatus (which is
      // post-register and would collide when the same status recurs in
      // one day). An interactive turn instead uses its durable message id:
      // after an earlier banner retired, a user-requested replacement must
      // not collide with that transition's terminal row. Duplicate executions
      // of either wake still converge on the same id.
      // Period + arming baseline + originating spec version: duplicate
      // executions of one escalation converge (identical everything), a
      // same-day recurrence differs by baseline, and a same-day REVISION
      // producing the same baseline differs by spec — so the skip below
      // can never starve the revised goal of its required banner.
      for (final request in strategy.createdAds) {
        if (staleSpecWake) {
          logError(
            'ad creation suppressed: the wake ran under a superseded spec',
          );
          break;
        }
        if (!adsEligible) {
          logError('ad creation suppressed: status does not permit ads');
          continue;
        }
        if (cooldownBlocksAds) {
          logError('ad creation suppressed: dismissal cooldown active');
          continue;
        }
        if (freshActiveExists) {
          logError('ad creation suppressed: a fresh active ad exists');
          continue;
        }
        // Weaker models echo FACTS ids into copy; the banner renders
        // this text verbatim, so it gets the same sanitizer as reports.
        final brief = sanitizeNudgeBrief(request.brief);
        final digest = goalBriefDigest(brief);
        if (!seenDigests.add(digest)) {
          logError('ad creation skipped: duplicate brief digest');
          continue;
        }
        if (allRows.any((n) => n.id == creationId)) {
          // The SAME transition recurring within one day (offTrack →
          // recover → offTrack) maps to one id — skipping preserves the
          // earlier banner's outcome, ratings and counters, and one
          // banner per identical daily transition is the respectful
          // ceiling anyway (the digest/cooldown spirit).
          logError(
            'ad creation skipped: this transition already produced '
            "today's banner",
          );
          continue;
        }
        freshActiveExists = true;
        alertBrief = brief;
        await _syncService.upsertEntity(
          AgentDomainEntity.goalNudge(
            id: creationId,
            agentId: agentId,
            status: NudgeStatus.active,
            brief: brief,
            briefDigest: digest,
            // UTC throughout: local instants serialize without an offset
            // and would shift the 72 h lifetime and freshness checks by
            // the zone difference on a syncing peer.
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
            vectorClock: null,
            runKey: runKey,
            threadId: threadId,
            triggerProgressId: goalProgressId(agentId, derivation.periodKey),
            reasonSummary: request.reasonSummary,
            staleAt: now.toUtc().add(goalAdLifetime),
            activatedAt: now.toUtc(),
            // The originating spec version: a banner syncing in AFTER
            // the revision sweep carries its own fencing evidence. The
            // facts digest lets Phase A's sweep recognize the banner as
            // data-stale once new evidence changes the derivation.
            provenance: {
              'specVersionId': derivation.version.id,
              'factsDigest': goalFactsDigest(
                derivation.facts,
                criteria: derivation.version.criteria,
                evaluationReference: factsReference,
              ),
            },
          ),
        );
      }

      // Observations.
      await persistAgentObservations(
        _syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        now: now,
        observations: strategy.observations,
      );

      // Revision proposals: ChangeSet-gated — the goal spec NEVER mutates
      // here; PR 4's approval flow mints the new version on accept.
      if (staleSpecWake && strategy.revisionProposals.isNotEmpty) {
        logError(
          'revision proposal suppressed: the wake ran under a superseded '
          'spec — approving it would distort the newer goal',
        );
      }
      if (!staleSpecWake && strategy.revisionProposals.isNotEmpty) {
        await _syncService.upsertEntity(
          AgentDomainEntity.changeSet(
            id: GoalAgentWorkflow._uuid.v4(),
            agentId: agentId,
            taskId: agentId,
            threadId: threadId,
            runKey: runKey,
            status: ChangeSetStatus.pending,
            items: buildDeferredChangeItems(
              [
                for (final proposal in strategy.revisionProposals)
                  {
                    'toolName': GoalAgentToolNames.proposeGoalRevision,
                    'args': {
                      'changes': proposal.changes,
                      'rationale': proposal.rationale,
                      // Approval is valid only while this exact immutable
                      // version remains the goal head. An offline proposal
                      // syncing in after an owner edit therefore cannot
                      // overwrite the newer goal.
                      'baseVersionId': derivation.version.id,
                      // Provenance for the minted version: the wake
                      // conversation that proposed this revision.
                      'sourceThreadId': threadId,
                    },
                  },
              ],
              (toolName, args) =>
                  'Goal revision proposal: '
                  '${(args['rationale'] as String?) ?? ''}',
            ),
            createdAt: now,
            vectorClock: null,
          ),
        );
      }
    });
    if (fenced) {
      logError(
        'outputs fenced: spec head moved while the wake ran against '
        '${derivation.version.id}',
      );
      if (replyToUser) {
        throw StateError(
          'interactive goal turn was fenced by a concurrent spec revision',
        );
      }
      return const GoalOutputPersistenceResult(
        attributionFinalized: false,
        reportHeadAdvanced: false,
      );
    }

    // The alert in the agent's words — AFTER the transaction, like Phase A's
    // sink calls, so a rolled-back banner never re-words an alert, and only
    // for a banner this wake created: a re-run banner keeps the alert as is.
    if (alertBrief case final brief?) {
      await _alertCopy?.restate(subjectId: agentId, brief: brief);
    }

    // Finalize AFTER the transaction: the projection must never describe
    // a report the rolled-back transaction did not write. Contained — a
    // bookkeeping failure must not fail a persisted wake; the session is
    // recovered later rather than the wake reported broken.
    if (attributionEnvelope != null) {
      try {
        await getIt<AiAttributionService>().finalize(attributionEnvelope);
        attributionFinalized = true;
      } catch (error, stackTrace) {
        logError(
          'report attribution projection remains pending for recovery',
          error: error,
          stackTrace: stackTrace,
        );
        attributionFinalized = true;
      }
    }
    return GoalOutputPersistenceResult(
      attributionFinalized: attributionFinalized,
      reportHeadAdvanced: reportHeadAdvanced,
    );
  }
}
