import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The left pane showing search + grouped project rows.
class ProjectListPane extends StatefulWidget {
  const ProjectListPane({
    required this.state,
    required this.onProjectSelected,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onFilterPressed,
    super.key,
  });

  final ProjectListDetailState state;
  final ValueChanged<String> onProjectSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onFilterPressed;

  @override
  State<ProjectListPane> createState() => _ProjectListPaneState();
}

class _ProjectListPaneState extends State<ProjectListPane> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.state.visibleGroups;
    final selectedId = widget.state.selectedProject?.project.meta.id;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: ShowcasePalette.border(context)),
        ),
      ),
      child: Column(
        children: [
          _SearchHeader(
            query: widget.state.searchQuery,
            onSearchChanged: widget.onSearchChanged,
            onSearchCleared: widget.onSearchCleared,
            onFilterPressed: widget.onFilterPressed,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: groups.isEmpty
                  ? const NoResultsPane()
                  : DesignSystemScrollbar(
                      controller: _scrollController,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          return ProjectGroupSection(
                            group: groups[index],
                            selectedProjectId: selectedId,
                            onProjectSelected: (item) =>
                                widget.onProjectSelected(item.project.meta.id),
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
    required this.onFilterPressed,
  });

  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onFilterPressed;

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
                child: IconButton(
                  onPressed: onFilterPressed,
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: ShowcasePalette.teal(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
