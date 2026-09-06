import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_ins_card.dart';
import 'package:lotti/features/relationships/ui/widgets/linked_tasks_card.dart';
import 'package:lotti/features/relationships/ui/widgets/person_header.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:lotti/features/relationships/ui/widgets/post_interaction_prompt.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_action_bar.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// One person's page (design 2026-09-06 §2–3), a sibling of the task page:
/// the cover-style hero with the header actions, the header block with the
/// cadence fact and the health band as pills, then the section cards in the
/// design's order — Briefing · Next time · Check-ins · Reach · Tasks — above
/// the sticky action bar (Log check-in · mic · the actionable channel).
///
/// On the desktop split the same page fills the detail pane, with every
/// section on one centred reading column. Deleting cascades through the
/// repository, the agent and the reminder (the same three legs as before).
class RelationshipDetailsPage extends ConsumerWidget {
  const RelationshipDetailsPage({required this.relationshipId, super.key});

  final String relationshipId;

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    RelationshipEntry relationship,
  ) async {
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.relationshipDeleteConfirmTitle(
        relationship.data.title,
      ),
      message: context.messages.relationshipDeleteConfirmMessage,
      confirmLabel: context.messages.deleteButton,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final deleted = await ref
          .read(relationshipRepositoryProvider)
          .deleteRelationship(relationship.id);
      if (deleted) {
        // The cascade's agent leg (ADR 0059 Decision 7): contained —
        // the person is gone either way, and a failed agent teardown is
        // repaired by runtime maintenance, not by failing this delete.
        unawaited(() async {
          try {
            await ref
                .read(relationshipAgentServiceProvider)
                .handleRelationshipDeleted(relationship.id);
          } catch (_) {
            // Logged by the service layer where possible; never surfaced.
          }
        }());
        // The cascade's reminder leg (ADR 0037 §5): an alarm armed weeks
        // ago would otherwise still fire, naming someone the user deleted.
        // Destroying the agent stops Phase A from clearing it later, so
        // this cannot be left to the next tick.
        //
        // Guarded like the agent leg, and for the same reason: `ref.read`
        // itself throws once this widget is disposed, and the await above is
        // long enough for that to happen. Unguarded it would surface as
        // "could not delete" for a delete that succeeded.
        unawaited(() async {
          try {
            await ref
                .read(relationshipReminderServiceProvider)
                .clearFor(relationship.id);
          } catch (_) {
            // clearFor is non-throwing by contract; this guards the read.
          }
        }());
      }
      if (!context.mounted) return;
      if (deleted) {
        beamToNamed('/people');
      } else {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorDeleteFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to delete relationship',
        name: 'RelationshipDetailsPage',
        error: e,
        stackTrace: s,
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorDeleteFailed,
        );
      }
    }
  }

  /// Leaves the page. On a phone the page was pushed and pops; on the
  /// desktop split it is the detail pane, and leaving means clearing the
  /// selection so the list stands alone again.
  void _back(BuildContext context) {
    if (isDesktopLayout(context)) {
      beamToNamed('/people');
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final detailAsync = ref.watch(
      relationshipDetailControllerProvider(relationshipId),
    );
    // Keep the last rendered detail during background reloads.
    final detail = detailAsync.value;

    if (detail == null) {
      // Resolved-null means the person is gone (deleted here or on another
      // device) — that is not an error, so say so instead of alarming.
      final body = detailAsync.isLoading
          ? const CircularProgressIndicator.adaptive()
          : Text(
              detailAsync.hasError
                  ? context.messages.commonError
                  : context.messages.relationshipNotFound,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            );
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: body),
      );
    }

    final relationship = detail.relationship;
    final checkIns = detail.checkIns;
    final data = relationship.data;
    final latest = checkIns.firstOrNull;
    final item = (relationship: relationship, lastCheckIn: latest);
    final categoryId = relationship.meta.categoryId;
    final categoryName = categoryId == null
        ? null
        : getIt<EntitiesCacheService>().getCategoryById(categoryId)?.name;

    // The standing briefing, read here as well as in the card: the header's
    // band pill and the card's chip must agree on whether one exists.
    final report = currentRelationshipReport(
      ref
          .watch(agentReportProvider(relationshipAgentIdFor(relationshipId)))
          .value,
    );
    final healthBand = report == null
        ? null
        : relationshipHealthMetricsFromReport(report)?.band;
    // The card renders nothing for someone not enrolled and never briefed;
    // the gap that would follow it has to know that too.
    final showBriefing = report != null || data.important;

    final sections = <Widget>[
      PersonHeaderBlock(
        item: item,
        categoryName: categoryName,
        healthBand: healthBand,
      ),
      if (showBriefing) RelationshipBriefingCard(relationship: relationship),
      if (NextTimeCard.hasContent(latest)) NextTimeCard(latest: latest),
    ];

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      // extendBody so the glass strip's BackdropFilter has body content
      // underneath to blur; the Scaffold reserves the bar's height as the
      // body's bottom inset, consumed by the trailing spacer below.
      extendBody: true,
      bottomNavigationBar: RelationshipActionBar(
        relationship: relationship,
        onLogCheckIn: () => showCheckInCaptureSheet(
          context: context,
          relationshipId: relationshipId,
        ),
        onSpeak: () => showCheckInCaptureSheet(
          context: context,
          relationshipId: relationshipId,
          startSpeaking: true,
        ),
      ),
      // Builder so MediaQuery.paddingOf reads the Scaffold-modified value.
      body: Builder(
        builder: (context) {
          // Every section — and the check-in log, which is a sliver and so
          // cannot sit inside `DetailContentWidth` — on the one reading
          // column that widget gives boxed content.
          final insets = detailContentInsets(context);
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          final gap = SizedBox(height: tokens.spacing.sectionGap);
          return CustomScrollView(
            slivers: [
              PersonHeroAppBar(
                relationship: relationship,
                contentInset: insets.left,
                onBack: () => _back(context),
                onTalkToAgent: () =>
                    beamToNamed('/people/$relationshipId/chat'),
                onDelete: () => _handleDelete(context, ref, relationship),
              ),
              SliverPadding(
                padding: insets,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final section in sections) ...[section, gap],
                    // Renders nothing until the user comes back from a
                    // call placed on this page; then it is the most
                    // time-sensitive thing here, directly above the log
                    // it offers to extend.
                    const PostInteractionPrompt(),
                  ]),
                ),
              ),
              // The log grows without bound and renders lazily in its own
              // sliver, inside the card decoration the boxed sections wear.
              SliverPadding(
                padding: insets,
                sliver: CheckInsCardSliver(
                  checkIns: checkIns,
                  onOpen: (checkIn) =>
                      showCheckInEditSheet(context: context, checkIn: checkIn),
                ),
              ),
              SliverPadding(
                padding: insets,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    gap,
                    if (data.contactChannels.isNotEmpty) ...[
                      ReachCard(
                        relationshipId: relationshipId,
                        channels: data.contactChannels,
                      ),
                      gap,
                    ],
                    LinkedTasksCard(
                      relationshipId: relationshipId,
                      tasks: detail.linkedTasks,
                      categoryId: categoryId,
                    ),
                    SizedBox(height: bottomInset + tokens.spacing.sectionGap),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
