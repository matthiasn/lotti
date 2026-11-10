// What a timeline block shows inside its card — its title tiers, time,
// reason spark, edit glyph and done check — apart from the card itself and
// its placement, so neither file outgrows the repo's size limit.
part of 'day_timeline_block.dart';

String? _reasonFor(TimeBlock block) {
  final reason = block.reason?.trim();
  return reason == null || reason.isEmpty ? null : reason;
}

class _BlockContent extends StatelessWidget {
  const _BlockContent({
    required this.block,
    required this.tracked,
    required this.past,
    required this.onRename,
    required this.showsEdit,
  });

  final TimeBlock block;
  final bool tracked;
  final bool past;
  final ValueChanged<String>? onRename;

  /// Whether the block can be edited: the title row then shows the pencil
  /// glyph whose target [DayBlock] lays over the corner.
  final bool showsEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isBuffer = block.type == TimeBlockType.buffer;
    final isCal = block.type == TimeBlockType.cal;
    final isTaskLinked =
        block.taskId != null && block.taskId!.trim().isNotEmpty;
    final isDone = block.state == TimeBlockState.completed;
    final running = tracked && block.state == TimeBlockState.inProgress;
    final reason = tracked ? null : _reasonFor(block);
    // Standalone ai/manual placements are click-to-edit; everything
    // else (cal events, buffers, task-linked, tracked) is read-only.
    final editable =
        !tracked && !isBuffer && !isCal && !isTaskLinked && onRename != null;
    // Recorded titles and the plan still to come read at full strength —
    // what is left of the plan is what "Looks good" approves; a planned
    // block already past recedes a step.
    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tracked || !past
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.mediumEmphasis,
      fontWeight: tokens.typography.weight.semiBold,
      fontStyle: isBuffer ? FontStyle.italic : FontStyle.normal,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Height-tiered content policy: never let text shear mid-glyph.
        // Micro blocks (< ~3/4 caption line) show fill + stripe only;
        // short blocks a single fitted title line; the subtitle joins
        // from ~44px; two title lines from 64px. ALL thresholds use
        // SCALED extents — at accessibility text sizes the text box
        // grows, so the tier a block qualifies for must grow with it.
        final textScaler = MediaQuery.textScalerOf(context);
        final lineHeight = textScaler.scale(
          tokens.typography.lineHeight.bodySmall,
        );
        final unscaledSliverLine = tokens.typography.lineHeight.caption;
        final sliverLineHeight = textScaler.scale(unscaledSliverLine);
        if (constraints.maxHeight < sliverLineHeight * 0.75 ||
            constraints.maxWidth < TapTargets.minimum) {
          // Even a fitted caption line would be illegibly small, or the block
          // is too narrow to hold a word (the phone's peeking lane) — fill +
          // stripe only, never a two-letter fragment (the Semantics label on
          // DayBlock still carries the title).
          return const SizedBox.shrink();
        }
        if (constraints.maxHeight < lineHeight + 2) {
          // Sliver tier: one caption line so short recorded sessions
          // (the unplanned incident!) stay information, not just color.
          // The line is FITTED to the available height via a clamped
          // linear scaler — a 22-minute block at default zoom (content
          // shorter than a full caption line) shrinks its glyphs to fit
          // instead of dropping the title or shearing it mid-x-height.
          final fittedScale =
              math.min(sliverLineHeight, constraints.maxHeight) /
              unscaledSliverLine;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              block.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.linear(fittedScale),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tracked
                    ? tokens.colors.text.highEmphasis
                    : tokens.colors.text.mediumEmphasis,
              ),
            ),
          );
        }
        final compact = constraints.maxHeight < textScaler.scale(44);
        final showSubtitle = !isBuffer && !compact;
        final titleMaxLines = constraints.maxHeight >= textScaler.scale(64)
            ? 2
            : 1;
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
                        LottiIcons.calendar,
                        size: tokens.typography.size.caption,
                        color: tokens.colors.text.mediumEmphasis,
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
                          : !running && !(compact && !isBuffer)
                          ? Text(
                              block.title,
                              style: titleStyle,
                              maxLines: titleMaxLines,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            )
                          : Text.rich(
                              TextSpan(
                                children: [
                                  // A recording still running says so in
                                  // the rows' own word, ahead of its name.
                                  if (running) ...[
                                    TextSpan(
                                      text:
                                          context.messages.dailyOsNextAgendaNow,
                                      style: captionLabelStyle(
                                        tokens,
                                        color: tokens.colors.text.highEmphasis,
                                      ),
                                    ),
                                    WidgetSpan(
                                      child: SizedBox(
                                        width: tokens.spacing.step2,
                                      ),
                                    ),
                                  ],
                                  // Too short for the time on its own line,
                                  // a block leads with it, as every list on
                                  // the page does, so a long title cannot
                                  // cut it off.
                                  if (compact && !isBuffer) ...[
                                    TextSpan(
                                      text: formatClock(context, block.start),
                                      style: tokens
                                          .typography
                                          .styles
                                          .others
                                          .caption
                                          .copyWith(
                                            color: tokens
                                                .colors
                                                .text
                                                .mediumEmphasis,
                                            fontFeatures: dayFigures,
                                          ),
                                    ),
                                    WidgetSpan(
                                      child: SizedBox(
                                        width: tokens.spacing.step2,
                                      ),
                                    ),
                                  ],
                                  TextSpan(text: block.title),
                                ],
                              ),
                              style: titleStyle,
                              maxLines: titleMaxLines,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                    ),
                    if (reason != null && !compact) ...[
                      SizedBox(width: tokens.spacing.step1),
                      _BlockReasonIcon(reason: reason),
                    ],
                    if (showsEdit) ...[
                      SizedBox(width: tokens.spacing.step1),
                      // The glyph only, quiet so the title reads first; its
                      // tap target is the block's corner (see DayBlock). One
                      // size in every block, in a slot one title line tall
                      // that it never outgrows.
                      ExcludeSemantics(
                        child: SizedBox(
                          width: tokens.typography.size.bodySmall,
                          height: lineHeight,
                          child: Icon(
                            LottiIcons.edit,
                            size: tokens.typography.size.bodySmall,
                            color: tokens.colors.text.lowEmphasis,
                          ),
                        ),
                      ),
                    ],
                    if (tracked && isDone) ...[
                      SizedBox(width: tokens.spacing.step1),
                      // In the title's ink: success green on a category's
                      // tint would be two hues arguing on one block.
                      Icon(
                        LottiIcons.confirm,
                        size: tokens.typography.size.caption,
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ],
                  ],
                ),
                if (showSubtitle)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step1),
                    child: Text(
                      _subTitle(context, block),
                      // The page's one voice for times: the caption, with
                      // the same figures as the agenda's time column.
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                        fontFeatures: dayFigures,
                      ),
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
    final parts = <String>[formatClockRange(context, block.start, block.end)];
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
}

class _BlockReasonIcon extends StatelessWidget {
  const _BlockReasonIcon({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A tap shows the reason — on a touch screen a long press is not a
    // gesture anyone looks for — and the tap stops here rather than opening
    // the block.
    return Tooltip(
      message: reason,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: context.messages.dailyOsNextDayWhyChipLabel,
        child: Icon(
          LottiIcons.aiSpark,
          size: tokens.typography.size.caption,
          color: tokens.colors.aiCard.accent.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
