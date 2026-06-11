part of 'day_timeline.dart';

class _BlockPosition extends StatelessWidget {
  const _BlockPosition({
    required this.block,
    required this.windowStart,
    required this.foldingState,
    required this.pxPerMinute,
    required this.tracked,
    required this.onRename,
  });

  final TimeBlock block;
  final DateTime windowStart;
  final TimelineFoldingState foldingState;
  final double pxPerMinute;
  final bool tracked;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final top = foldingState.positionForDate(
      block.start,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final end = foldingState.positionForDate(
      block.end,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final rawHeight = math.max(0, end - top).toDouble();
    final minimumReadableHeight =
        tokens.typography.lineHeight.bodySmall + tokens.spacing.step2 * 2;
    final preferredGap = tokens.spacing.step1;
    final blockGap = rawHeight > minimumReadableHeight + preferredGap
        ? math.min(preferredGap, rawHeight / 3)
        : 0.0;
    final height = math.max(0, rawHeight - blockGap).toDouble();
    return Positioned(
      top: top + blockGap / 2,
      left: tokens.spacing.step3,
      right: tokens.spacing.step3,
      height: height,
      child: DayBlock(
        key: Key('daily_os_day_block_${block.id}'),
        block: block,
        tracked: tracked,
        onRename: onRename,
      ),
    );
  }
}

/// A single placed block on the Day timeline.
///
/// Paint-by-numbers contract: PLANNED blocks are the faint outline waiting
/// to be filled in — a whisper of category color (5% fill, tinted dashed
/// outline while drafted) — and [tracked] blocks (recorded sessions) are
/// the filled-in paint: full-strength category stripe, an 18% category
/// fill, a green check when done, and a mono time range. Doing is what
/// makes a block alive, so the recorded lane carries the color.
class DayBlock extends ConsumerWidget {
  const DayBlock({
    required this.block,
    this.tracked = false,
    this.onRename,
    super.key,
  });

  final TimeBlock block;
  final bool tracked;

  /// Inline rename for standalone blocks. Ignored for task-linked,
  /// calendar, buffer, and tracked blocks.
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final category = _categoryColor();
    final isBuffer = block.type == TimeBlockType.buffer;
    final isDrafted = !tracked && block.state == TimeBlockState.drafted;
    final taskId = block.taskId?.trim();
    final onTap = taskId == null || taskId.isEmpty
        ? null
        : () {
            // Tracked blocks project a real time recording. Publish the
            // focus intent before navigating so the task detail page
            // scrolls to (and highlights) that exact recording, matching
            // the old calendar behaviour. Drafted/agent blocks have no
            // backing entry, so they just open the task at the top.
            final entryId = block.trackedEntryId;
            if (entryId != null) {
              publishTaskFocus(
                taskId: taskId,
                entryId: entryId,
                ref: ref,
                alignment: kDefaultScrollAlignment,
              );
            }
            beamToNamed('/tasks/$taskId');
          };

    // Recorded tint needs more chroma in light mode to keep the
    // filled-in/sketch contrast legible on a white canvas.
    final isLight = Theme.of(context).brightness == Brightness.light;
    final trackedTint = isLight ? 0.30 : 0.18;
    // Composite the tint over the canvas so the fill is opaque: hour
    // gridlines must read as the empty canvas, not through the cards.
    final canvas = tokens.colors.background.level01;
    final fill = isBuffer
        ? Colors.transparent
        : Color.alphaBlend(
            category.withValues(alpha: tracked ? trackedTint : 0.05),
            canvas,
          );
    final leftStripeColor = isBuffer
        ? tokens.colors.text.lowEmphasis.withValues(alpha: 0.32)
        : tracked
        ? category
        : category.withValues(alpha: 0.45);

    final borderRadius = BorderRadius.circular(tokens.radii.m);
    final card = Ink(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: leftStripeColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.radii.m),
                bottomLeft: Radius.circular(tokens.radii.m),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: _BlockContent(
                block: block,
                tracked: tracked,
                onRename: onRename,
              ),
            ),
          ),
        ],
      ),
    );

    // Drafted blocks read provisional via a dashed outline; committed
    // and tracked blocks read solid.
    final outlined = isDrafted
        ? DsDashedBorder(
            color: category.withValues(alpha: 0.30),
            radius: tokens.radii.m,
            child: card,
          )
        : card;

    if (onTap == null) {
      return Material(
        type: MaterialType.transparency,
        child: outlined,
      );
    }

    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: outlined,
        ),
      ),
    );
  }

  Color _categoryColor() => categoryColorFromHex(block.category.colorHex);
}

class _BlockContent extends StatelessWidget {
  const _BlockContent({
    required this.block,
    required this.tracked,
    required this.onRename,
  });

  final TimeBlock block;
  final bool tracked;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isBuffer = block.type == TimeBlockType.buffer;
    final isCal = block.type == TimeBlockType.cal;
    final isTaskLinked =
        block.taskId != null && block.taskId!.trim().isNotEmpty;
    final isDone = block.state == TimeBlockState.completed;
    // Standalone ai/manual placements are click-to-edit; everything
    // else (cal events, buffers, task-linked, tracked) is read-only.
    final editable =
        !tracked && !isBuffer && !isCal && !isTaskLinked && onRename != null;
    // Recorded titles read at full strength; planned ones recede a step —
    // the plan is the sketch, the recording is the ink.
    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tracked
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.mediumEmphasis,
      fontWeight: FontWeight.w600,
      fontStyle: isBuffer ? FontStyle.italic : FontStyle.normal,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Height-tiered content policy: never let text shear mid-glyph.
        // Micro blocks (< one comfortable line) show fill + stripe only;
        // short blocks a single centered title line; the subtitle joins
        // from ~44px; two title lines from 64px.
        final lineHeight = MediaQuery.textScalerOf(
          context,
        ).scale(tokens.typography.lineHeight.bodySmall);
        if (constraints.maxHeight < lineHeight + 2) {
          return const SizedBox.shrink();
        }
        final compact = constraints.maxHeight < 44;
        final showSubtitle = !isBuffer && !compact;
        final titleMaxLines = constraints.maxHeight >= 64 ? 2 : 1;
        // OverflowBox + ClipRect: duration-sized boxes clip content
        // gracefully at the block edge instead of throwing RenderFlex
        // overflows when a height lands between the visibility thresholds.
        return ClipRect(
          child: OverflowBox(
            alignment: compact ? Alignment.centerLeft : Alignment.topLeft,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCal) ...[
                      Icon(
                        Icons.event_rounded,
                        size: 12,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      SizedBox(width: tokens.spacing.step1),
                    ],
                    if (!tracked && isTaskLinked) ...[
                      Icon(
                        Icons.link_rounded,
                        size: 12,
                        color: tokens.colors.alert.info.defaultColor,
                      ),
                      SizedBox(width: tokens.spacing.step1),
                    ],
                    Expanded(
                      child: editable && !compact
                          ? EditableTitle(
                              value: block.title,
                              onSubmitted: onRename!,
                              style: titleStyle,
                            )
                          : Text(
                              block.title,
                              style: titleStyle,
                              maxLines: titleMaxLines,
                              overflow: TextOverflow.fade,
                              softWrap: true,
                            ),
                    ),
                    if (tracked && isDone) ...[
                      SizedBox(width: tokens.spacing.step1),
                      Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: tokens.colors.alert.success.defaultColor,
                      ),
                    ],
                  ],
                ),
                if (showSubtitle)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step1),
                    child: Text(
                      _subTitle(context, block),
                      // One mono voice for time metadata in both lanes.
                      style: monoMetaStyle(
                        tokens,
                        tokens.colors,
                      ).copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subTitle(BuildContext context, TimeBlock block) {
    final parts = <String>[_formatRange(block)];
    if (block.sessionIndex != null && block.sessionTotal != null) {
      parts.add(
        context.messages.dailyOsNextTimelineSessionOf(
          block.sessionIndex!,
          block.sessionTotal!,
        ),
      );
    }
    if (block.location != null) parts.add(block.location!);
    return parts.join(' · ');
  }

  String _formatRange(TimeBlock block) {
    return '${_clock(block.start)}–${_clock(block.end)}';
  }

  String _clock(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({
    required this.windowStart,
    required this.now,
    required this.foldingState,
    required this.pxPerMinute,
  });

  final DateTime windowStart;
  final DateTime now;
  final TimelineFoldingState foldingState;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final red = tokens.colors.alert.error.defaultColor;
    final top = foldingState.positionForDate(
      now,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    return Positioned(
      top: top - 0.75,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: red, shape: BoxShape.circle),
            ),
            Expanded(
              child: Container(height: 1.5, color: red),
            ),
          ],
        ),
      ),
    );
  }
}
