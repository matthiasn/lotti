import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// The left pane showing search + grouped project rows.
class ProjectListPane extends StatelessWidget {
  const ProjectListPane({
    required this.state,
    required this.onProjectSelected,
    required this.onSearchChanged,
    required this.onSearchCleared,
    super.key,
  });

  final ProjectListDetailState state;
  final ValueChanged<String> onProjectSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context) {
    final groups = state.visibleGroups;
    final selectedId = state.selectedProject?.project.meta.id;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: ShowcasePalette.border(context)),
        ),
      ),
      child: Column(
        children: [
          _SearchHeader(
            query: state.searchQuery,
            onSearchChanged: onSearchChanged,
            onSearchCleared: onSearchCleared,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: groups.isEmpty
                  ? const NoResultsPane()
                  : DesignSystemScrollbar(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return ProjectGroupSection(
                            group: groups[index],
                            selectedProjectId: selectedId,
                            onProjectSelected: onProjectSelected,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.query,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: ShowcasePalette.page(context),
      child: Center(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: DesignSystemSearch(
                  hintText: context.messages.projectShowcaseSearchHint,
                  initialText: query,
                  onChanged: onSearchChanged,
                  onClear: onSearchCleared,
                  onSearchPressed: onSearchChanged,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: ShowcasePalette.teal(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A category-labelled section containing grouped [ProjectRow] entries.
class ProjectGroupSection extends StatefulWidget {
  const ProjectGroupSection({
    required this.group,
    required this.selectedProjectId,
    required this.onProjectSelected,
    super.key,
  });

  final ProjectGroup group;
  final String? selectedProjectId;
  final ValueChanged<String> onProjectSelected;

  @override
  State<ProjectGroupSection> createState() => _ProjectGroupSectionState();
}

class _ProjectGroupSectionState extends State<ProjectGroupSection> {
  String? _hoveredProjectId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = widget.group.projects.first.category;

    bool isHighlighted(ProjectRecord record) =>
        record.project.meta.id == widget.selectedProjectId ||
        record.project.meta.id == _hoveredProjectId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              CategoryTag(
                label: widget.group.label,
                icon: category.icon?.iconData ?? Icons.label_outline,
                color: colorFromCssHex(
                  category.color ?? defaultCategoryColorHex,
                ),
              ),
              const Spacer(),
              Text(
                context.messages.projectCountSummary(
                  widget.group.projects.length,
                ),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ShowcasePalette.mediumText(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: ShowcasePalette.surface(context),
            child: SizedBox(
              width: 370,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < widget.group.projects.length;
                    index++
                  ) ...[
                    ProjectRow(
                      record: widget.group.projects[index],
                      selected:
                          widget.group.projects[index].project.meta.id ==
                          widget.selectedProjectId,
                      hovered:
                          widget.group.projects[index].project.meta.id ==
                          _hoveredProjectId,
                      onHoverChanged: (hovered) {
                        setState(() {
                          _hoveredProjectId = hovered
                              ? widget.group.projects[index].project.meta.id
                              : _hoveredProjectId ==
                                    widget.group.projects[index].project.meta.id
                              ? null
                              : _hoveredProjectId;
                        });
                      },
                      onTap: () => widget.onProjectSelected(
                        widget.group.projects[index].project.meta.id,
                      ),
                    ),
                    if (index < widget.group.projects.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color:
                              isHighlighted(widget.group.projects[index]) ||
                                  isHighlighted(
                                    widget.group.projects[index + 1],
                                  )
                              ? Colors.transparent
                              : ShowcasePalette.border(context),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single project row in the list, with title, health ring, task count, and
/// status label.
class ProjectRow extends StatelessWidget {
  const ProjectRow({
    required this.record,
    required this.selected,
    required this.hovered,
    required this.onHoverChanged,
    required this.onTap,
    super.key,
  });

  final ProjectRecord record;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final metaStyle = tokens.typography.styles.others.caption.copyWith(
      color: ShowcasePalette.lowText(context),
    );

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: DesignSystemListItem(
        title: record.project.data.title,
        subtitleSpans: _metaSpans(
          context,
          metaStyle,
          record.healthScore,
          record.totalTaskCount,
          record.project.data.targetDate,
        ),
        trailing: ProjectStatusLabel(status: record.project.data.status),
        activated: selected,
        selected: selected,
        activatedBackgroundColor: ShowcasePalette.selectedRow(context),
        hoverBackgroundColor: ShowcasePalette.hoverFill(context),
        onTap: onTap,
      ),
    );
  }

  List<InlineSpan> _metaSpans(
    BuildContext context,
    TextStyle metaStyle,
    int score,
    int count,
    DateTime? targetDate,
  ) {
    final tokens = context.designTokens;
    final taskCount = context.messages.settingsCategoriesTaskCount(count);
    final dueLabel = targetDate == null
        ? context.messages.projectShowcaseOngoing
        : context.messages.projectShowcaseDueDate(
            DateFormat.MMMd(
              Localizations.localeOf(context).toString(),
            ).format(targetDate),
          );

    return [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 3),
          child: _TinyProgressRing(
            key: const ValueKey('project-row-health-ring'),
            score: score,
          ),
        ),
      ),
      TextSpan(text: '$score · ', style: metaStyle),
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
}

class _TinyProgressRing extends StatelessWidget {
  const _TinyProgressRing({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: CustomPaint(
        painter: _TinyProgressRingPainter(
          progress: score.clamp(0, 100) / 100,
          trackColor: ShowcasePalette.lowText(
            context,
          ).withValues(alpha: 0.18),
          progressColor: score >= 80
              ? ShowcasePalette.timeGreen(context)
              : ShowcasePalette.amber(context),
        ),
      ),
    );
  }
}

class _TinyProgressRingPainter extends CustomPainter {
  const _TinyProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.25;
    const inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _TinyProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
