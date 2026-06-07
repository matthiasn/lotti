// The project row and its meta-span builder — part of the
// project_list_shared library so it shares the row layout constants.
part of 'project_list_shared.dart';

/// A single project row in the list, with task-progress ring, task count,
/// due label, and status tag.
class ProjectRow extends ConsumerWidget {
  const ProjectRow({
    required this.item,
    required this.selected,
    required this.topOverlap,
    required this.bottomOverlap,
    required this.onHoverChanged,
    required this.onTap,
    this.backgroundTopInset = 0,
    this.backgroundBottomInset = 0,
    this.contentHorizontalPadding = _kProjectRowHorizontalPadding,
    super.key,
  });

  final ProjectListItemData item;
  final bool selected;
  final double topOverlap;
  final double bottomOverlap;
  final double backgroundTopInset;
  final double backgroundBottomInset;
  final double contentHorizontalPadding;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final metaStyle = tokens.typography.styles.others.caption.copyWith(
      color: ShowcasePalette.lowText(context),
    );
    final projectId = item.project.meta.id;
    final oneLiner = ref.watch(projectOneLinerProvider(projectId)).value;

    return GroupedCardRowSurface(
      key: key ?? ValueKey('project-row-surface-$projectId'),
      rowKey: ValueKey('project-overview-row-$projectId'),
      backgroundKey: ValueKey('project-row-background-$projectId'),
      selected: selected,
      hoverColor: ShowcasePalette.hoverFill(context),
      selectedColor: ShowcasePalette.selectedRow(context),
      topOverlap: topOverlap,
      bottomOverlap: bottomOverlap,
      backgroundTopInset: backgroundTopInset,
      backgroundBottomInset: backgroundBottomInset,
      padding: EdgeInsets.fromLTRB(
        contentHorizontalPadding,
        _kProjectRowVerticalPadding,
        contentHorizontalPadding,
        _kProjectRowVerticalPadding,
      ),
      onHoverChanged: onHoverChanged,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.project.data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: ShowcasePalette.highText(context),
                  ),
                ),
                if (oneLiner != null && oneLiner.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    oneLiner,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ShowcasePalette.lowText(context),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: metaStyle,
                    children: _metaSpans(
                      context,
                      metaStyle,
                      item,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _kProjectRowGap),
          ProjectStatusLabel(status: item.status),
        ],
      ),
    );
  }
}

List<InlineSpan> _metaSpans(
  BuildContext context,
  TextStyle metaStyle,
  ProjectListItemData item,
) {
  final tokens = context.designTokens;
  final taskCount = context.messages.settingsCategoriesTaskCount(
    item.taskRollup.totalTaskCount,
  );
  final dueLabel = item.targetDate == null
      ? context.messages.projectShowcaseOngoing
      : context.messages.projectShowcaseDueDate(
          DateFormat.MMMd(
            Localizations.localeOf(context).toString(),
          ).format(item.targetDate!),
        );

  return [
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _TinyProgressRing(
        key: ValueKey(
          'project-row-progress-ring-${item.project.meta.id}',
        ),
        progress: item.taskRollup.completionRatio,
        progressColor: _progressRingColor(context, item.taskRollup),
        trackColor: ShowcasePalette.highText(
          context,
        ).withValues(alpha: 0.12),
      ),
    ),
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(width: tokens.spacing.step1),
    ),
    TextSpan(
      text: '${item.taskRollup.completionPercent}% · ',
      style: metaStyle,
    ),
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(
        Icons.format_list_bulleted_rounded,
        size: tokens.typography.lineHeight.caption,
        color: ShowcasePalette.lowText(context),
      ),
    ),
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(width: tokens.spacing.step1),
    ),
    TextSpan(text: '$taskCount · $dueLabel', style: metaStyle),
  ];
}
