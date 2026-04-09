import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';

const _desktopContentMaxWidth = 760.0;
const _horizontalContentPadding = 16.0;

class ProjectsOverviewSliverList extends StatelessWidget {
  const ProjectsOverviewSliverList({
    required this.groups,
    required this.onProjectTap,
    this.selectedProjectId,
    this.bottomPadding = 24,
    super.key,
  });

  final List<ProjectCategoryGroup> groups;
  final ValueChanged<ProjectListItemData> onProjectTap;
  final String? selectedProjectId;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      sliver: SliverMainAxisGroup(
        slivers: [
          for (var index = 0; index < groups.length; index++) ...[
            SliverToBoxAdapter(
              child: ProjectsOverviewContentWidth(
                child: ProjectGroupSection(
                  group: groups[index],
                  selectedProjectId: selectedProjectId,
                  onProjectSelected: onProjectTap,
                ),
              ),
            ),
            if (index < groups.length - 1)
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ],
      ),
    );
  }
}

class ProjectsOverviewContentWidth extends StatelessWidget {
  const ProjectsOverviewContentWidth({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth >= kDesktopBreakpoint
        ? _desktopContentMaxWidth
        : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalContentPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}
