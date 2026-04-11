import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/services/time_service.dart';

/// Interactive time tracker card with real time recording and linked entry display.
class DesktopTimeTrackerCard extends ConsumerStatefulWidget {
  const DesktopTimeTrackerCard({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<DesktopTimeTrackerCard> createState() =>
      _DesktopTimeTrackerCardState();
}

class _DesktopTimeTrackerCardState
    extends ConsumerState<DesktopTimeTrackerCard> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final linkedEntities = ref.watch(
      resolvedOutgoingLinkedEntriesProvider(widget.taskId),
    );

    final timeEntries = linkedEntities.whereType<JournalEntry>().toList();
    var totalDuration = Duration.zero;
    for (final entry in timeEntries) {
      totalDuration += entry.meta.dateTo.difference(entry.meta.dateFrom);
    }

    final durationLabel = showcaseFormatDuration(totalDuration);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.messages.taskShowcaseTimeTracker,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: TaskShowcasePalette.highText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (totalDuration > Duration.zero) ...[
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: TaskShowcasePalette.success(context),
                  ),
                  SizedBox(width: tokens.spacing.step1),
                  Text(
                    durationLabel,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: TaskShowcasePalette.success(context),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                ],
                GestureDetector(
                  onTap: () => setState(() => _collapsed = !_collapsed),
                  child: Icon(
                    _collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: TaskShowcasePalette.mediumText(context),
                  ),
                ),
              ],
            ),
            if (!_collapsed) ...[
              SizedBox(height: tokens.spacing.step4),
              _TrackTimeButton(taskId: widget.taskId),
              if (timeEntries.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step4),
                for (var i = 0; i < timeEntries.length; i++) ...[
                  _TimeEntryRow(entry: timeEntries[i]),
                  if (i < timeEntries.length - 1)
                    Divider(color: TaskShowcasePalette.border(context)),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackTimeButton extends ConsumerWidget {
  const _TrackTimeButton({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final timeService = getIt<TimeService>();

    return StreamBuilder<JournalEntity?>(
      stream: timeService.getStream(),
      builder: (context, snapshot) {
        final isRecording =
            snapshot.data != null && timeService.linkedFrom?.meta.id == taskId;

        return GestureDetector(
          onTap: () async {
            if (isRecording) {
              await timeService.stop();
            } else {
              final entry = ref
                  .read(entryControllerProvider(id: taskId))
                  .value
                  ?.entry;
              if (entry != null) {
                final entryCreationService = ref.read(
                  entryCreationServiceProvider,
                );
                await entryCreationService.createTimerEntry(linked: entry);
              }
            }
          },
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
            decoration: BoxDecoration(
              color: isRecording
                  ? TaskShowcasePalette.error(context).withValues(alpha: 0.15)
                  : TaskShowcasePalette.subtleFill(context),
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
              border: Border.all(
                color: isRecording
                    ? TaskShowcasePalette.error(context)
                    : TaskShowcasePalette.border(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRecording ? Icons.stop_rounded : Icons.timer_outlined,
                  size: 20,
                  color: isRecording
                      ? TaskShowcasePalette.error(context)
                      : TaskShowcasePalette.highText(context),
                ),
                SizedBox(width: tokens.spacing.step2),
                Text(
                  isRecording
                      ? context.messages.audioRecordingStop
                      : context.messages.addActionAddTimer,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: isRecording
                        ? TaskShowcasePalette.error(context)
                        : TaskShowcasePalette.highText(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimeEntryRow extends StatelessWidget {
  const _TimeEntryRow({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final duration = entry.meta.dateTo.difference(entry.meta.dateFrom);
    final text = entry.entryText?.plainText.trim() ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text.isNotEmpty)
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: TaskShowcasePalette.highText(context),
                    ),
                  ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  DateFormat('d MMM yy, HH:mm').format(entry.meta.dateFrom),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: TaskShowcasePalette.lowText(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: TaskShowcasePalette.highText(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            showcaseFormatDuration(duration),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: TaskShowcasePalette.highText(context),
            ),
          ),
        ],
      ),
    );
  }
}
