import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/project_lookup_providers.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:lotti/widgets/projects/project_status_attributes.dart';
import 'package:lotti/widgets/projects/project_status_chip.dart';
import 'package:material_ui/material_ui.dart';

/// Sentinel id for the "No project" row, which unlinks the task. Namespaced
/// so it can never collide with a real project id.
const String _kProjectPickerNoneSentinel = '__project_picker_none__';

/// Modal content for selecting a privacy-compatible project within a category.
///
/// Watches the category's projects and keeps only those whose privacy matches
/// the task's, so the picker never offers a link
/// `ProjectRepository.linkTaskToProject` would refuse.
class ProjectSelectionModalContent extends ConsumerWidget {
  const ProjectSelectionModalContent({
    required this.categoryId,
    required this.taskIsPrivate,
    required this.onProjectSelected,
    this.currentProjectId,
    super.key,
  });

  final String categoryId;
  final bool taskIsPrivate;
  final Future<bool> Function(ProjectEntry? project) onProjectSelected;
  final String? currentProjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `when` with `skipLoadingOnReload`, not `whenData`: a refresh (the
    // provider invalidating itself on a project notification, which the
    // pick's own link write fires) already keeps the rows, but a reload from a
    // dependency change goes through `whenData` as a bare loading state, which
    // would swap the sheet for a spinner and lose the typed query. The body
    // keeps its last rows through either, which is the no-flash rule.
    final projectsAsync = ref
        .watch(projectsForCategoryProvider(categoryId))
        .when<AsyncValue<List<ProjectEntry>>>(
          skipLoadingOnReload: true,
          data: (projects) => AsyncData(
            projects
                .where(
                  (project) => (project.meta.private ?? false) == taskIsPrivate,
                )
                .toList(),
          ),
          error: AsyncError.new,
          loading: AsyncLoading.new,
        );
    return ProjectSelectionModalBody(
      projectsAsync: projectsAsync,
      onProjectSelected: onProjectSelected,
      currentProjectId: currentProjectId,
    );
  }
}

/// The project adapter over [EntityPickerSheet] — the testable core shared by
/// every project-picker entry point.
///
/// It composes the same sheet the category and label pickers do, so the three
/// look and behave alike: a design-system search field filters the category's
/// projects by title, the project the task is in is pinned at the top with a
/// "No project" row under it to unlink, and every project row carries its
/// status chip. Tapping a row hands the project (or `null` for "No project")
/// to [onProjectSelected] and closes the picker when the write is accepted;
/// a rejected or failed write keeps the picker open and explains itself in an
/// inline callout above the search field.
class ProjectSelectionModalBody extends StatefulWidget {
  const ProjectSelectionModalBody({
    required this.projectsAsync,
    required this.onProjectSelected,
    this.currentProjectId,
    super.key,
  });

  final AsyncValue<List<ProjectEntry>> projectsAsync;

  /// Writes the pick. `null` unlinks the task. Resolves to whether the write
  /// was accepted; a `false` or a throw keeps the picker open.
  final Future<bool> Function(ProjectEntry? project) onProjectSelected;

  /// The project the task is linked to, pinned and ticked at the top.
  final String? currentProjectId;

  @override
  State<ProjectSelectionModalBody> createState() =>
      _ProjectSelectionModalBodyState();
}

class _ProjectSelectionModalBodyState extends State<ProjectSelectionModalBody> {
  /// The last pick was refused or failed; the callout explaining it is shown.
  bool _selectionRejected = false;

  /// A pick's write is in flight. Rows stay hit-testable across that await,
  /// so without this a second tap would start a second link write.
  bool _picking = false;

  /// The rows for [query]: the pinned current project, the "No project" row,
  /// then every other matching project in the order the category lists them.
  List<PickerItem> _entries(List<ProjectEntry> projects, String query) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? projects
        : projects
              .where((p) => p.data.title.toLowerCase().contains(q))
              .toList();

    final currentId = widget.currentProjectId;
    ProjectEntry? current;
    if (currentId != null) {
      for (final project in filtered) {
        if (project.meta.id == currentId) {
          current = project;
          break;
        }
      }
    }

    // The pinned current is rendered first, so drop it from the main list to
    // avoid showing it twice.
    final listed = current == null
        ? filtered
        : filtered.where((p) => p.meta.id != currentId).toList();

    return [
      if (current != null) _projectItem(current),
      // "No project" belongs with the canonical (empty-query) list or alongside
      // the still-visible pinned current — and only while there is a project
      // to unlink. When a search has filtered the current project out, it is
      // suppressed so it never appears orphaned. The empty-query branch keeps
      // it available even when the current project is absent from the list
      // (its privacy or category no longer matches the task's), so such a
      // link can still be removed.
      if (currentId != null && (q.isEmpty || current != null)) _noneItem(),
      for (final project in listed) _projectItem(project),
    ];
  }

  PickerItem _projectItem(ProjectEntry project) {
    final tokens = context.designTokens;
    final (statusLabel, _, _) = projectStatusAttributes(
      context,
      project.data.status,
    );
    return PickerItem(
      id: project.meta.id,
      rowKey: ValueKey('project-${project.meta.id}'),
      leading: Icon(
        LottiIcons.folder,
        color: tokens.colors.text.mediumEmphasis,
        size: IconSizes.l,
      ),
      title: project.data.title,
      // The status chip is a visual-only badge, so fold its state into the
      // row's accessible name.
      semanticLabel: '${project.data.title}, $statusLabel',
      badges: [ProjectStatusChip(status: project.data.status)],
    );
  }

  PickerItem _noneItem() => PickerItem(
    id: _kProjectPickerNoneSentinel,
    rowKey: const ValueKey('project-none'),
    leading: Icon(
      LottiIcons.block,
      color: context.designTokens.colors.text.mediumEmphasis,
      size: IconSizes.l,
    ),
    title: context.messages.projectPickerUnassigned,
  );

  Future<void> _onPick(List<ProjectEntry> projects, String id) async {
    if (_picking) return;

    final project = id == _kProjectPickerNoneSentinel
        ? null
        : projects.where((p) => p.meta.id == id).firstOrNull;
    // A tap on the row that is already ticked changes nothing: close without
    // a write rather than re-linking the task to the project it is in.
    if (project?.meta.id == widget.currentProjectId) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _picking = true;
      _selectionRejected = false;
    });
    var accepted = false;
    try {
      accepted = await widget.onProjectSelected(project);
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return;
    if (!accepted) {
      setState(() {
        _picking = false;
        _selectionRejected = true;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    return widget.projectsAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.all(tokens.spacing.step7),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Center(
          child: Text(
            messages.projectErrorLoadProjects,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
          ),
        ),
      ),
      data: (List<ProjectEntry> projects) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectionRejected)
            Padding(
              // No bottom inset: the sheet's own top inset is the gap between
              // the callout and the search field.
              padding: EdgeInsets.only(
                left: tokens.spacing.step5,
                top: tokens.spacing.step5,
                right: tokens.spacing.step5,
              ),
              child: DesignSystemInlineCallout(
                key: const ValueKey('project-picker-rejected'),
                icon: LottiIcons.error,
                tone: tokens.colors.alert.error.defaultColor,
                text: messages.projectPickerUpdateFailed,
                announce: true,
              ),
            ),
          EntityPickerSheet(
            mode: PickerMode.single,
            entriesBuilder: (query) => _entries(projects, query),
            searchHintText: messages.projectShowcaseSearchHint,
            // A category without projects says so, rather than reporting a
            // search that found nothing.
            emptyMessage: projects.isEmpty
                ? messages.projectNoProjects
                : messages.filterSelectionNoMatches,
            selectedId: widget.currentProjectId,
            onPick: (id) => _onPick(projects, id),
          ),
        ],
      ),
    );
  }
}
