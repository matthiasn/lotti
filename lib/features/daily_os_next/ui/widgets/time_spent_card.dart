import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// "Today so far" — the always-present, bounded tracked-time block.
///
/// Mirrors `prototype/shared.jsx → TimeSpentCard` (handoff v2 item 1):
/// header row with a calm eyebrow on the left and a right-aligned mono
/// summary (`4h 35m · 3 done`); one row per recorded session with a
/// category dot, truncating title, mono time range, and a green check
/// when done. Bounded to [maxRows] (3 on desktop, 2 on mobile); the
/// overflow collapses behind a ghost "N earlier sessions" expander.
///
/// Used pinned at the top of the Capture column and as the body of the
/// Agenda tab's empty state.
class TimeSpentCard extends StatefulWidget {
  const TimeSpentCard({
    required this.blocks,
    this.title,
    this.compact = false,
    this.maxRows,
    super.key,
  });

  /// Recorded sessions for the day, in any order — rows render sorted
  /// by start time.
  final List<TimeBlock> blocks;

  /// Eyebrow label override. Defaults to the localized "Today so far";
  /// callers rendering a non-today date pass a date-aware label.
  final String? title;

  /// Tightens the padding for narrow hosts.
  final bool compact;

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
    final tokens = context.designTokens;
    final messages = context.messages;
    final maxRows = widget.maxRows ?? (isDesktopLayout(context) ? 3 : 2);

    final sorted = [...widget.blocks]
      ..sort((a, b) => a.start.compareTo(b.start));
    // The most recent sessions stay visible; earlier ones collapse
    // behind the expander.
    final shown = _expanded || sorted.length <= maxRows
        ? sorted
        : sorted.sublist(sorted.length - maxRows);
    final hiddenCount = sorted.length - shown.length;

    final totalMinutes = sorted.totalMinutes;
    final doneCount = sorted.completedCount;

    return Container(
      key: const Key('daily_os_time_spent_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact
            ? tokens.spacing.step4
            : tokens.spacing.cardPadding,
        vertical: tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  widget.title ?? messages.dailyOsNextTimeSpentTitle,
                  style: calmEyebrowStyle(tokens),
                ),
              ),
              Text(
                messages.dailyOsNextTimeSpentSummary(
                  formatMinutesCompact(totalMinutes),
                  doneCount,
                ),
                style: monoMetaStyle(tokens, tokens.colors),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          for (final (index, block) in shown.indexed)
            _TimeSpentRow(block: block, showDivider: index > 0),
          if (hiddenCount > 0 || _expanded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('daily_os_time_spent_expander'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.colors.text.lowEmphasis,
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                    vertical: tokens.spacing.step1,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: tokens.typography.size.bodySmall,
                ),
                label: Text(
                  _expanded
                      ? messages.dailyOsNextTimeSpentShowLess
                      : messages.dailyOsNextTimeSpentEarlierSessions(
                          hiddenCount,
                        ),
                  style: calmEyebrowStyle(tokens),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeSpentRow extends StatelessWidget {
  const _TimeSpentRow({required this.block, required this.showDivider});

  final TimeBlock block;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = categoryColorFromHex(block.category.colorHex);
    final done = block.state == TimeBlockState.completed;
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(color: tokens.colors.decorative.level01),
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox.square(
            dimension: tokens.spacing.step3,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              block.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Text(
            formatClockRange(context, block.start, block.end),
            style: monoMetaStyle(tokens, tokens.colors),
          ),
          if (done) ...[
            SizedBox(width: tokens.spacing.step2),
            Icon(
              Icons.check_rounded,
              size: tokens.typography.size.bodySmall,
              color: tokens.colors.alert.success.defaultColor,
            ),
          ],
        ],
      ),
    );
  }
}
