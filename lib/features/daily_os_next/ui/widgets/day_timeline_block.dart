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
/// Planned blocks carry their category color; [tracked] blocks (recorded
/// sessions) render in the neutral treatment from handoff v2 item 2 —
/// faint neutral fill, neutral left border, a small category dot, a green
/// check when done, a mono time range, and a "· tracked" suffix. They
/// never read as drafted: they already happened.
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

    final fill = isBuffer
        ? Colors.transparent
        : tracked
        ? tokens.colors.surface.enabled
        : category.withValues(alpha: 0.12);
    final leftStripeColor = isBuffer
        ? tokens.colors.text.lowEmphasis.withValues(alpha: 0.32)
        : tracked
        ? tokens.colors.decorative.level02
        : category;

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
            color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.20),
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
    final category = categoryColorFromHex(block.category.colorHex);
    final isBuffer = block.type == TimeBlockType.buffer;
    final isCal = block.type == TimeBlockType.cal;
    final isTaskLinked =
        block.taskId != null && block.taskId!.trim().isNotEmpty;
    final isDone = block.state == TimeBlockState.completed;
    // Standalone ai/manual placements are click-to-edit; everything
    // else (cal events, buffers, task-linked, tracked) is read-only.
    final editable =
        !tracked && !isBuffer && !isCal && !isTaskLinked && onRename != null;
    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontWeight: FontWeight.w600,
      fontStyle: isBuffer ? FontStyle.italic : FontStyle.normal,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Per the prototype: blocks shorter than 36 px collapse to the
        // title row only. The sub-title row would otherwise overflow
        // the block on 30-min cal events.
        final compact = constraints.maxHeight < 36;
        final showSubtitle = !isBuffer && !compact;
        final titleMaxLines = constraints.maxHeight >= 56 ? 2 : 1;
        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tracked) ...[
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step1),
                      child: SizedBox.square(
                        dimension: tokens.spacing.step2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: category,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                  ],
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
                  if (tracked && isDone && !compact) ...[
                    SizedBox(width: tokens.spacing.step1),
                    Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: tokens.colors.alert.success.defaultColor,
                    ),
                  ],
                ],
              ),
              if (block.reason != null &&
                  block.type == TimeBlockType.ai &&
                  !tracked &&
                  constraints.maxHeight >= 72) ...[
                SizedBox(height: tokens.spacing.step1),
                WhyChip(reason: block.reason!),
              ],
              if (showSubtitle)
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step1),
                  child: Text(
                    _subTitle(context, block),
                    style: tracked
                        ? monoMetaStyle(
                            tokens,
                            tokens.colors,
                          ).copyWith(fontSize: 10)
                        : tokens.typography.styles.others.caption.copyWith(
                            color: tokens.colors.text.lowEmphasis,
                            fontSize: 10,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
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
    if (tracked) parts.add(context.messages.dailyOsNextTimelineTracked);
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
