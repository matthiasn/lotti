import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';

const _desktopContentMaxWidth = 760.0;
const _wideContentMaxWidth = 1120.0;
const _horizontalContentPadding = 16.0;

/// Sliver that renders the grouped project overview as [ProjectGroupSection]s,
/// one per category group.
///
/// On narrow/medium widths the sections stack in a single, width-capped reading
/// column ([ProjectsOverviewContentWidth]); once the available width crosses
/// [kWideProjectsOverviewBreakpoint] they flow into two balanced columns so a
/// wide window is actually used. The width is measured from the sliver's
/// `crossAxisExtent`, so the desktop master+detail split (narrow list pane)
/// correctly stays single-column. [selectedProjectId] highlights the active
/// row in that split view.
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
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (constraints.crossAxisExtent >= kWideProjectsOverviewBreakpoint) {
          return _buildTwoColumn(context);
        }
        return _buildSingleColumn(context);
      },
    );
  }

  Widget _buildSingleColumn(BuildContext context) {
    final gap = context.designTokens.spacing.sectionGap;
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
              SliverToBoxAdapter(child: SizedBox(height: gap)),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumn(BuildContext context) {
    final tokens = context.designTokens;
    final gap = tokens.spacing.sectionGap;
    // A wider inter-column gutter than the inter-card vertical gap makes the
    // two columns read as parallel peers, not an even grid.
    final gutter = gap + tokens.spacing.step3;
    final (left, right) = balanceProjectColumns(groups);

    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _wideContentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalContentPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _column(left, gap)),
                  SizedBox(width: gutter),
                  Expanded(child: _column(right, gap)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _column(List<ProjectCategoryGroup> columnGroups, double gap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < columnGroups.length; index++) ...[
          if (index > 0) SizedBox(height: gap),
          ProjectGroupSection(
            group: columnGroups[index],
            selectedProjectId: selectedProjectId,
            onProjectSelected: onProjectTap,
          ),
        ],
      ],
    );
  }
}

/// Upper bound on category count for the optimal (brute-force) column split;
/// beyond it `_balanceColumns` falls back to a greedy fill. 2^14 masks is
/// trivial to scan and far above any realistic number of categories.
const _maxBruteForceColumns = 14;

/// Splits [groups] into two columns that minimise the height difference between
/// them. Each category is kept whole and original order is preserved within a
/// column. For a realistic number of categories the optimal partition is found
/// by brute force; beyond [_maxBruteForceColumns] it falls back to a greedy
/// shortest-column fill.
@visibleForTesting
(List<ProjectCategoryGroup>, List<ProjectCategoryGroup>) balanceProjectColumns(
  List<ProjectCategoryGroup> groups,
) {
  // Estimate each section's rendered height as its header (~1.5 rows) plus one
  // unit per project row.
  double heightOf(ProjectCategoryGroup group) => 1.5 + group.projectCount;

  final count = groups.length;
  if (count <= 1) {
    return (groups, const <ProjectCategoryGroup>[]);
  }

  final left = <ProjectCategoryGroup>[];
  final right = <ProjectCategoryGroup>[];

  if (count <= _maxBruteForceColumns) {
    var bestMask = 1;
    var bestDiff = double.infinity;
    // Masks 1..(2^count - 2) keep both columns non-empty.
    for (var mask = 1; mask < (1 << count) - 1; mask++) {
      var leftHeight = 0.0;
      var rightHeight = 0.0;
      for (var i = 0; i < count; i++) {
        if ((mask >> i) & 1 == 1) {
          leftHeight += heightOf(groups[i]);
        } else {
          rightHeight += heightOf(groups[i]);
        }
      }
      final diff = (leftHeight - rightHeight).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestMask = mask;
      }
    }
    for (var i = 0; i < count; i++) {
      ((bestMask >> i) & 1 == 1 ? left : right).add(groups[i]);
    }
    return (left, right);
  }

  var leftHeight = 0.0;
  var rightHeight = 0.0;
  for (final group in groups) {
    if (leftHeight <= rightHeight) {
      left.add(group);
      leftHeight += heightOf(group);
    } else {
      right.add(group);
      rightHeight += heightOf(group);
    }
  }
  return (left, right);
}

/// Centers [child] and caps its width on wide (desktop-breakpoint) screens so
/// the overview content stays readable, while letting it span full width on
/// narrow ones. Also applies the standard horizontal content padding.
class ProjectsOverviewContentWidth extends StatelessWidget {
  const ProjectsOverviewContentWidth({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // On wide screens the header/search shares the two-column body's frame
    // (same cap + left edge) so they don't read as misaligned; below that it
    // uses the single-column reading cap.
    final maxWidth = screenWidth >= kWideProjectsOverviewBreakpoint
        ? _wideContentMaxWidth
        : screenWidth >= kDesktopBreakpoint
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
