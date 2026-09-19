import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/services/db_notification.dart' show agentNotification;
import 'package:lotti/utils/consts.dart';

/// The ACTIVE relationship banners across all active relationship agents,
/// newest first — the relationship kind's registered source for the shared
/// banner dock (`nudgeBannerSourcesProvider`, merged in
/// `app_bootstrap.dart`; the `activeGoalNudgesProvider` shape).
///
/// A tap lands on the person's detail page — the briefing lives there
/// (the ADR 0059 open question, resolved per the plan's proposal).
final FutureProvider<List<NudgeBannerEntry>> activeRelationshipNudgesProvider =
    FutureProvider.autoDispose<List<NudgeBannerEntry>>((ref) async {
      // The dock mounts unconditionally on its surfaces, so the rollout
      // flag gates HERE: relationships off → no banners, even for rows
      // that synced in from a device that has the feature enabled.
      final enabled =
          ref.watch(configFlagProvider(enableRelationshipsFlag)).value ?? false;
      if (!enabled) return const [];
      final lifecycleListener = AppLifecycleListener(
        onResume: ref.invalidateSelf,
      );
      ref
        ..onDispose(lifecycleListener.dispose)
        ..watch(agentUpdateStreamProvider(agentNotification));
      final agents = await ref
          .watch(agentServiceProvider)
          .listAgents(lifecycle: AgentLifecycle.active);
      final repository = ref.watch(agentRepositoryProvider);
      final relationshipRepository = ref.watch(relationshipRepositoryProvider);
      final entries = <NudgeBannerEntry>[];
      final now = clock.now();
      DateTime? nextDeadline;
      void considerDeadline(DateTime? deadline) {
        if (deadline == null || !deadline.isAfter(now)) return;
        if (nextDeadline == null || deadline.isBefore(nextDeadline!)) {
          nextDeadline = deadline;
        }
      }

      for (final identity in agents) {
        if (identity.kind != AgentKinds.relationshipAgent) continue;
        ref.watch(agentUpdateStreamProvider(identity.agentId));
        final links = await repository.getLinksFrom(
          identity.agentId,
          type: AgentLinkTypes.agentRelationship,
        );
        if (links.isEmpty) continue;
        final relationshipId = links.first.toId;
        final relationship = await relationshipRepository.getRelationshipById(
          relationshipId,
        );
        if (relationship == null || relationship.meta.deletedAt != null) {
          continue;
        }
        final nudges = (await repository.getEntitiesByAgentId(
          identity.agentId,
          type: AgentEntityTypes.relationshipNudge,
        )).whereType<RelationshipNudgeEntity>();
        for (final nudge in nudges) {
          if (nudge.deletedAt != null || nudge.status != NudgeStatus.active) {
            continue;
          }
          final view = NudgeEntityView.of(nudge)!;
          // Staleness and snooze are timed visibility boundaries: honour
          // them without an agent notification by re-evaluating at the
          // earliest deadline still ahead (the goal-provider pattern).
          considerDeadline(nudge.staleAt);
          if (nudge.staleAt != null && !now.isBefore(nudge.staleAt!)) continue;
          final snoozedUntil = nudgeBannerSnoozedUntil(view);
          considerDeadline(snoozedUntil);
          if (nudgeBannerIsSnoozed(view, now)) continue;
          if (nudgeBannerIsDismissedForDay(view, now)) {
            considerDeadline(nudgeBannerNextLocalMidnight(now));
            continue;
          }
          entries.add((
            nudge: view,
            subjectTitle: relationship.data.title,
            kind: NudgeBannerKind.relationship,
            tapRoute: '/people/$relationshipId',
          ));
        }
      }
      entries.sort(
        (a, b) => (b.nudge.activatedAt ?? b.nudge.createdAt).compareTo(
          a.nudge.activatedAt ?? a.nudge.createdAt,
        ),
      );
      if (nextDeadline != null) {
        final timer = Timer(nextDeadline!.difference(now), ref.invalidateSelf);
        ref.onDispose(timer.cancel);
      }
      return entries;
    }, name: 'activeRelationshipNudgesProvider');

/// This person's reminder while the tap that opened it has paused it
/// (ADR 0063): the banner, and when it comes back. Null when no reminder is
/// paused that way — none is active, it was never tapped, or it was put off
/// on purpose since (a chosen snooze is the user's own answer).
typedef PausedRelationshipReminder = ({NudgeBannerEntry entry, DateTime until});

final FutureProviderFamily<PausedRelationshipReminder?, String>
pausedRelationshipReminderProvider = FutureProvider.autoDispose
    .family<PausedRelationshipReminder?, String>((
      ref,
      relationshipId,
    ) async {
      final agentId = relationshipAgentIdFor(relationshipId);
      ref
        ..watch(agentUpdateStreamProvider(agentId))
        // The tap hides the banner here the moment its pause is written;
        // the write itself sends no agent notification.
        ..watch(locallySnoozedNudgeDeadlinesProvider);
      final repository = ref.watch(agentRepositoryProvider);
      // The agent is named after the person: the banner's subject, without
      // a second read of the person the page already holds.
      final identity = await repository.getEntity(agentId);
      if (identity is! AgentIdentityEntity) return null;
      final nudges = (await repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      )).whereType<RelationshipNudgeEntity>();
      final now = clock.now();
      for (final nudge in nudges) {
        if (nudge.deletedAt != null || nudge.status != NudgeStatus.active) {
          continue;
        }
        final view = NudgeEntityView.of(nudge)!;
        final until = nudgeBannerSnoozedUntil(view);
        if (until == null || !until.isAfter(now)) continue;
        final latest = view.snoozeHistory
            .where((event) => event.activation == view.activationCount)
            .lastOrNull;
        if (latest?.reason != NudgeSnoozeReason.opened) continue;
        final timer = Timer(until.difference(now), ref.invalidateSelf);
        ref.onDispose(timer.cancel);
        return (
          entry: (
            nudge: view,
            subjectTitle: identity.displayName,
            kind: NudgeBannerKind.relationship,
            tapRoute: '/people/$relationshipId',
          ),
          until: until,
        );
      }
      return null;
    }, name: 'pausedRelationshipReminderProvider');
