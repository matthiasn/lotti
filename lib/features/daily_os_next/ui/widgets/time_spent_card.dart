import 'dart:math' as math;

import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_section_header.dart';
import 'package:lotti/features/design_system/components/cards/ds_rows_card.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' show beamToNamed;
import 'package:material_ui/material_ui.dart';

/// "Today so far" — the always-present, bounded tracked-time block.
///
/// A [DaySectionHeader] with a right-aligned summary (`4h 35m · 3 done`) over the
/// sessions as rows on one [DsRowsCard], each in the agenda's anatomy: the
/// start in a right-aligned time column, a category dot, the title, and the
/// session's length — or the success check once it is done ([DayRowScaffold]).
/// Bounded to [maxRows] (3 on desktop, 2 on mobile); earlier sessions fold
/// into the card's first row, "N earlier sessions", which unfolds them.
///
/// Used pinned at the top of the Capture column and between the Activity
/// tab's "Needs you" and "Handled" groups.
class TimeSpentCard extends StatefulWidget {
  const TimeSpentCard({
    required this.blocks,
    this.title,
    this.showSummary = true,
    this.maxRows,
    super.key,
  });

  /// Recorded sessions for the day, in any order — rows render sorted
  /// by start time.
  final List<TimeBlock> blocks;

  /// Eyebrow label override. Defaults to the localized "Today so far";
  /// callers rendering a non-today date pass a date-aware label.
  final String? title;

  /// Whether the eyebrow carries the total and done count. A host that
  /// already says them (the day page's briefing, without a plan) leaves them
  /// out rather than repeat them.
  final bool showSummary;

  /// Visible rows before the expander takes over. Defaults to 3 on
  /// desktop layouts and 2 otherwise.
  final int? maxRows;

  @override
  State<TimeSpentCard> createState() => _TimeSpentCardState();
}

class _TimeSpentCardState extends State<TimeSpentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    // Guard against non-positive overrides — sublist math below needs
    // at least one visible row.
    final maxRows = math.max(
      1,
      widget.maxRows ?? (isDesktopLayout(context) ? 3 : 2),
    );

    final sorted = [...widget.blocks]
      ..sort((a, b) => a.start.compareTo(b.start));
    // The most recent sessions stay visible; earlier ones collapse
    // behind the expander.
    final shown = _expanded || sorted.length <= maxRows
        ? sorted
        : sorted.sublist(sorted.length - maxRows);

    final totalMinutes = sorted.totalMinutes;
    final doneCount = sorted.completedCount;

    // How many earlier sessions fold behind the first row; still counted
    // while unfolded, so the row can fold them again.
    final hidden = math.max(0, sorted.length - maxRows);
    return Column(
      key: const Key('daily_os_time_spent_card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DaySectionHeader(
          label: widget.title ?? messages.dailyOsNextTimeSpentTitle,
          summary: widget.showSummary
              ? messages.dailyOsNextTimeSpentSummary(
                  formatMinutesCompact(totalMinutes),
                  doneCount,
                )
              : null,
        ),
        DsRowsCard(
          rows: [
            // Earlier sessions fold into the card's first row, as the
            // agenda folds its finished items: the latest stay in view.
            if (hidden > 0)
              _EarlierSessionsRow(
                key: const Key('daily_os_time_spent_expander'),
                first: sorted.first.start,
                count: hidden,
                expanded: _expanded,
                onToggle: () => setState(() => _expanded = !_expanded),
              ),
            for (final block in shown)
              _TimeSpentRow(key: ValueKey(block.id), block: block),
          ],
        ),
      ],
    );
  }
}

/// The folded earlier sessions, as the card's first row: the first one's
/// time, how many there are, and a chevron that unfolds them in place.
class _EarlierSessionsRow extends StatelessWidget {
  const _EarlierSessionsRow({
    required this.first,
    required this.count,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final DateTime first;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final label = expanded
        ? messages.dailyOsNextTimeSpentShowLess
        : messages.dailyOsNextTimeSpentEarlierSessions(count);
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      excludeSemantics: true,
      onTap: onToggle,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          child: DayRowScaffold(
            time: formatClock(context, first),
            leading: Icon(
              LottiIcons.schedule,
              size: tokens.typography.size.caption,
              color: tokens.colors.text.lowEmphasis,
            ),
            trailing: Icon(
              expanded ? LottiIcons.chevronUp : LottiIcons.chevronDown,
              size: tokens.typography.size.subtitle2,
              color: tokens.colors.text.lowEmphasis,
            ),
            child: Text(
              label,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One recorded session on the shared row grid. A session that belongs to a
/// task opens it, and ends in the agenda's chevron to say so.
class _TimeSpentRow extends StatelessWidget {
  const _TimeSpentRow({required this.block, super.key});

  final TimeBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final done = block.state == TimeBlockState.completed;
    final taskId = block.taskId?.trim();
    final opensTask = taskId != null && taskId.isNotEmpty;
    final mark = done
        ? Icon(
            LottiIcons.confirm,
            size: tokens.typography.size.bodySmall,
            color: tokens.colors.alert.success.defaultColor,
          )
        : Text(
            formatMinutesCompact(block.duration.inMinutes),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontFeatures: dayFigures,
            ),
          );
    final row = DayRowScaffold(
      time: formatClock(context, block.start),
      leading: SizedBox.square(
        dimension: tokens.spacing.step2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: categoryColorFromHex(block.category.colorHex),
            shape: BoxShape.circle,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          if (opensTask) ...[
            SizedBox(width: tokens.spacing.step2),
            Icon(
              LottiIcons.chevronRight,
              size: tokens.typography.size.subtitle2,
              color: tokens.colors.text.lowEmphasis,
            ),
          ],
        ],
      ),
      child: Text(
        block.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
    if (!opensTask) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => beamToNamed('/tasks/$taskId'),
        child: row,
      ),
    );
  }
}
