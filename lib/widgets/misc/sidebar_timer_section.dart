import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/widgets/misc/timer_navigation.dart';

/// Inline timer panel rendered in the desktop sidebar's `aboveSettings`
/// slot whenever a time-recording session is active.
///
/// Tapping anywhere on the body navigates to the running task (or the
/// timer's journal entry, if not linked to a task). Tapping the stop
/// button stops the timer. The panel collapses to [SizedBox.shrink] when
/// no timer is running, so it consumes no space in the idle state.
class SidebarTimerSection extends ConsumerWidget {
  const SidebarTimerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeService = getIt<TimeService>();

    return StreamBuilder<JournalEntity?>(
      stream: timeService.getStream(),
      builder: (context, snapshot) {
        final current = snapshot.data;
        if (current == null) {
          return const SizedBox.shrink();
        }
        return _SidebarTimerCard(
          current: current,
          linkedFrom: timeService.linkedFrom,
          onStop: () async => timeService.stop(),
          onTapBody: () => navigateToTimerTarget(
            ref: ref,
            current: current,
            linkedFrom: timeService.linkedFrom,
          ),
        );
      },
    );
  }
}

class _SidebarTimerCard extends StatelessWidget {
  const _SidebarTimerCard({
    required this.current,
    required this.linkedFrom,
    required this.onStop,
    required this.onTapBody,
  });

  final JournalEntity current;
  final JournalEntity? linkedFrom;
  final Future<void> Function() onStop;
  final VoidCallback onTapBody;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final errorColor = tokens.colors.alert.error.defaultColor;
    final title = _resolveTitle(messages.taskUntitled);
    final durationText = formatDuration(entryDuration(current));

    return Semantics(
      container: true,
      label: messages.sidebarRunningTimerLabel,
      child: Material(
        color: errorColor.withAlpha(20),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTapBody,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step3,
              tokens.spacing.step3,
              tokens.spacing.step3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimerTitleRow(title: title),
                SizedBox(height: tokens.spacing.step2),
                _TimerBodyRow(
                  durationText: durationText,
                  onStop: onStop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveTitle(String fallback) {
    if (linkedFrom is Task) {
      final t = (linkedFrom! as Task).data.title.trim();
      if (t.isNotEmpty) return t;
    }
    final linkedText = linkedFrom?.entryText?.plainText.trim();
    if (linkedText != null && linkedText.isNotEmpty) return linkedText;
    final currentText = current.entryText?.plainText.trim();
    if (currentText != null && currentText.isNotEmpty) return currentText;
    return fallback;
  }
}

class _TimerTitleRow extends StatelessWidget {
  const _TimerTitleRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Icon(
          Icons.work_outline_rounded,
          size: 16,
          color: tokens.colors.text.mediumEmphasis,
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerBodyRow extends StatelessWidget {
  const _TimerBodyRow({
    required this.durationText,
    required this.onStop,
  });

  final String durationText;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final errorColor = tokens.colors.alert.error.defaultColor;
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 20,
          color: errorColor,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            durationText,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: errorColor,
              fontFeatures: numericBadgeFontFeatures,
            ),
          ),
        ),
        _StopTimerButton(onStop: onStop),
      ],
    );
  }
}

class _StopTimerButton extends StatelessWidget {
  const _StopTimerButton({required this.onStop});

  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final errorColor = tokens.colors.alert.error.defaultColor;
    final tooltip = context.messages.sidebarRunningTimerStopTooltip;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Material(
          color: errorColor.withAlpha(40),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onStop,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.stop_rounded,
                size: 18,
                color: errorColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
