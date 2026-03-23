import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
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
                  : ListView.separated(
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
              child: Container(
                height: 48,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ShowcasePalette.border(context),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    4,
                    2,
                    12,
                    2,
                  ),
                  child: DesignSystemSearch(
                    hintText: context.messages.projectShowcaseSearchHint,
                    initialText: query,
                    onChanged: onSearchChanged,
                    onClear: onSearchCleared,
                    onSearchPressed: onSearchChanged,
                  ),
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
    final showStateSurface = selected || hovered;
    final stateColor = selected
        ? ShowcasePalette.selectedRow(context)
        : ShowcasePalette.hoverFill(context);

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: showStateSurface ? stateColor : Colors.transparent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.project.data.title,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: ShowcasePalette.highText(context),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TinyProgressRing(score: record.healthScore),
                          Text(
                            '${record.healthScore}',
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: ShowcasePalette.lowText(context),
                                ),
                          ),
                          Text(
                            '·',
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: ShowcasePalette.lowText(context),
                                ),
                          ),
                          Text(
                            _taskSummaryLabel(
                              context,
                              record.totalTaskCount,
                              record.project.data.targetDate,
                            ),
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: ShowcasePalette.lowText(context),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ProjectStatusLabel(status: record.project.data.status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _taskSummaryLabel(
    BuildContext context,
    int count,
    DateTime? targetDate,
  ) {
    final taskCount = context.messages.settingsCategoriesTaskCount(count);
    if (targetDate == null) {
      return '$taskCount · ${context.messages.projectShowcaseOngoing}';
    }

    return '$taskCount · ${context.messages.projectShowcaseDueDate(DateFormat('MMM d').format(targetDate))}';
  }
}

class _TinyProgressRing extends StatelessWidget {
  const _TinyProgressRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(
        value: score / 100,
        strokeWidth: 2,
        backgroundColor: ShowcasePalette.border(context),
        valueColor: AlwaysStoppedAnimation(
          ShowcasePalette.amber(context),
        ),
      ),
    );
  }
}
