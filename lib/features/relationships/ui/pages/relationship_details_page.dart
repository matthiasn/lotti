import 'dart:async';

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_link_action.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/post_interaction_prompt.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// One person's page: header (name, status, importance, cadence) and the
/// check-in log, newest first, with a log-check-in FAB. The app bar carries
/// edit and delete actions; tapping a check-in opens it for editing.
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

    return Scaffold(
      // The page's primary action, so it wears the interactive accent every
      // other create-here FAB in the app wears — Material's default
      // `FloatingActionButton` painted it in the theme's secondary container
      // instead, which read as a neutral pill beside the teal used for
      // "Link task" a few rows below it.
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: DesignSystemFloatingActionButton(
          key: const ValueKey('relationship-log-check-in-fab'),
          semanticLabel: context.messages.relationshipLogCheckIn,
          label: context.messages.relationshipLogCheckIn,
          icon: LottiIcons.greeting,
          onPressed: () => showCheckInCaptureSheet(
            context: context,
            relationshipId: relationshipId,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(data.title),
              actions: [
                if (data.important)
                  Icon(
                    LottiIcons.star,
                    color: tokens.colors.interactive.enabled,
                  ),
                // Renders nothing on desktop, where channels are typed by
                // hand (plan v2 phase 7 item 2).
                ContactLinkAction(relationship: relationship),
                IconButton(
                  tooltip: context.messages.relationshipEditTitle,
                  onPressed: () => showRelationshipEditModal(
                    context: context,
                    relationship: relationship,
                  ),
                  icon: const Icon(LottiIcons.edit),
                ),
                IconButton(
                  tooltip: context.messages.deleteButton,
                  onPressed: () => _handleDelete(context, ref, relationship),
                  icon: const Icon(LottiIcons.delete),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step5 +
                    DesignSystemBottomNavigationBar.occupiedHeight(context) +
                    tokens.spacing.step12,
              ),
              // The fixed sections stay in a list delegate; the check-in log
              // grows without bound and renders lazily in its own builder
              // sliver (the project-detail split: fixed sections + a builder
              // list for the unbounded part).
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _RelationshipHeader(data: data),
                      SizedBox(height: tokens.spacing.sectionGap),
                      // Above the briefing: returning from a call the user
                      // just placed, the offer to log it is the most
                      // time-sensitive thing on the page (plan v2 phase 7
                      // item 5). Renders nothing the rest of the time.
                      const PostInteractionPrompt(),
                      // The executive briefing directly under the header —
                      // the agent's standing voice on this page (plan v2
                      // phase 5).
                      RelationshipBriefingCard(relationship: relationship),
                      if (data.contactChannels.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.sectionGap),
                        _SectionHeading(
                          context.messages.relationshipContactChannelsLabel,
                        ),
                        SizedBox(height: tokens.spacing.step3),
                        for (final channel in data.contactChannels)
                          _ContactChannelRow(
                            relationshipId: relationshipId,
                            channel: channel,
                          ),
                      ],
                      SizedBox(height: tokens.spacing.sectionGap),
                      _LinkedTasksSection(
                        relationshipId: relationshipId,
                        tasks: detail.linkedTasks,
                      ),
                      SizedBox(height: tokens.spacing.sectionGap),
                      _SectionHeading(
                        context.messages.relationshipCheckInsLabel,
                      ),
                      SizedBox(height: tokens.spacing.step3),
                      if (checkIns.isEmpty)
                        Text(
                          context.messages.relationshipNoCheckIns,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                    ]),
                  ),
                  if (checkIns.isNotEmpty)
                    SliverList.separated(
                      itemCount: checkIns.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: tokens.spacing.cardItemSpacing),
                      itemBuilder: (context, index) =>
                          _CheckInRow(checkIn: checkIns[index]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipHeader extends StatelessWidget {
  const _RelationshipHeader({required this.data});

  final RelationshipData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cadenceDays = data.checkInCadenceDays;

    Widget chip(String label, IconData icon) => Chip(
      avatar: Icon(icon, size: tokens.spacing.step4),
      label: Text(label),
      labelStyle: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );

    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        chip(
          relationshipStatusLabel(context, data.status),
          LottiIcons.radioUnselected,
        ),
        if (cadenceDays != null)
          chip(
            relationshipCadenceLabel(context, cadenceDays),
            LottiIcons.refresh,
          ),
        if (data.nickname != null) chip(data.nickname!, LottiIcons.moodGood),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      title,
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
  }
}

class _ContactChannelRow extends StatelessWidget {
  const _ContactChannelRow({
    required this.relationshipId,
    required this.channel,
  });

  final String relationshipId;
  final ContactChannel channel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = channel.label;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        contactChannelTypeIcon(channel.type),
        color: tokens.colors.text.mediumEmphasis,
      ),
      title: Text(
        channel.value,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
      subtitle: Text(
        label == null || label.isEmpty
            ? contactChannelTypeLabel(context, channel.type)
            : label,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
      // Renders nothing until the platform confirms it can service an
      // action, and nothing at all for a channel with no launchable scheme
      // (plan v2 phase 7 item 4).
      trailing: ContactQuickActions(
        relationshipId: relationshipId,
        channel: channel,
      ),
    );
  }
}

/// Tasks linked to this person, with a picker to link more and per-row
/// unlinking (plan v2 phase 2 item 3 — `RelationshipLink` both ways).
class _LinkedTasksSection extends ConsumerWidget {
  const _LinkedTasksSection({
    required this.relationshipId,
    required this.tasks,
  });

  final String relationshipId;
  final List<Task> tasks;

  Future<void> _pickTask(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(relationshipRepositoryProvider);
    final linkedIds = {for (final task in tasks) task.meta.id};

    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.relationshipLinkTaskButton,
      padding: EdgeInsets.zero,
      builder: (modalContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: TaskSearchPickerBody(
              excludeIds: {relationshipId, ...linkedIds},
              onTaskSelected: (task) async {
                var linked = false;
                try {
                  linked = await repository.linkTask(
                    relationshipId: relationshipId,
                    taskId: task.meta.id,
                  );
                } catch (error, stackTrace) {
                  developer.log(
                    'Failed to link task to relationship',
                    name: 'RelationshipDetailsPage',
                    error: error,
                    stackTrace: stackTrace,
                  );
                }
                if (!modalContext.mounted) return;
                Navigator.of(modalContext).pop();
                // `createLink` answers false when the upsert changed no row,
                // so a silent close would read as a link that worked.
                if (!linked && context.mounted) {
                  context.showToast(
                    tone: DesignSystemToastTone.error,
                    title: context.messages.relationshipErrorLinkTaskFailed,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlinkTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.unlinkTaskConfirmNamed(
        task.data.title.isEmpty
            ? context.messages.taskUntitled
            : task.data.title,
      ),
      confirmLabel: context.messages.unlinkTaskTitle,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final removed = await ref
          .read(relationshipRepositoryProvider)
          .unlinkTask(relationshipId: relationshipId, taskId: task.meta.id);
      if (!removed && context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.unlinkTaskFailedMessage,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to unlink task from relationship',
        name: 'RelationshipDetailsPage',
        error: error,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.unlinkTaskFailedMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionHeading(
                context.messages.relationshipLinkedTasksLabel,
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickTask(context, ref),
              icon: const Icon(LottiIcons.link),
              label: Text(context.messages.relationshipLinkTaskButton),
            ),
          ],
        ),
        if (tasks.isEmpty)
          Text(
            context.messages.relationshipNoLinkedTasks,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          )
        else
          for (final task in tasks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LottiIcons.confirmCircled,
                color: tokens.colors.text.mediumEmphasis,
              ),
              title: Text(
                task.data.title.isEmpty
                    ? context.messages.taskUntitled
                    : task.data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              subtitle: Text(
                taskLabelFromStatusString(
                  task.data.status.toDbString,
                  context,
                ),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              trailing: IconButton(
                tooltip: context.messages.unlinkTaskTitle,
                onPressed: () => _unlinkTask(context, ref, task),
                icon: const Icon(LottiIcons.linkOff),
              ),
              onTap: () => beamToNamed('/tasks/${task.meta.id}'),
            ),
      ],
    );
  }
}

class _CheckInRow extends StatelessWidget {
  const _CheckInRow({required this.checkIn});

  final CheckInEntry checkIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final data = checkIn.data;
    final narrative = checkIn.entryText?.plainText.trim();
    final sentiment = data.sentiment;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCheckInEditSheet(context: context, checkIn: checkIn),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    checkInInteractionIcon(data.interactionType),
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      checkInInteractionLabel(context, data.interactionType),
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                  Text(
                    entryDateLabel(context, checkIn.meta.dateFrom),
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
              ),
              if (sentiment != null) ...[
                SizedBox(height: tokens.spacing.step3),
                Text(
                  checkInSentimentLabel(context, sentiment),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
              if (narrative != null && narrative.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step3),
                Text(
                  narrative,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
              if (data.topics.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step3),
                // Topics are this check-in's tags, so they wear the tag
                // pill the rest of the app spends on labels — the tight
                // `radii.xs` corner that says "read-out, not button".
                Wrap(
                  spacing: tokens.spacing.step2,
                  runSpacing: tokens.spacing.step2,
                  children: [
                    for (final topic in data.topics)
                      DsPill(
                        variant: DsPillVariant.filled,
                        shape: DsPillShape.tag,
                        bordered: true,
                        label: topic,
                        labelColor: tokens.colors.text.mediumEmphasis,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
