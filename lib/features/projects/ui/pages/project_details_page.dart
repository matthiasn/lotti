import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';

/// Read-first project detail surface rendered in the desktop right pane and as
/// the mobile `/projects/<id>` route.
///
/// Drives [ProjectMobileDetailContent] from the composed
/// [projectDetailRecordProvider] (health, agent report, linked tasks), using
/// `skipLoadingOnReload: true` so a background refresh keeps the last rendered
/// data instead of flashing a spinner. The initial spinner only shows while the
/// [ProjectDetailController] is loading with no project yet.
///
/// Edits here are immediate-save inline pickers — category, target date, and
/// status each open a sheet/picker, mutate [ProjectDetailController], and call
/// `saveChanges()` right away (no explicit Save button). When the project has a
/// project agent it also exposes "refresh report" / "cancel scheduled wake"
/// actions wired to the project-agent service. Contrast with the form-style
/// `ProjectDetailPage`.
class ProjectDetailsPage extends ConsumerWidget {
  const ProjectDetailsPage({
    required this.projectId,
    super.key,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(projectDetailControllerProvider(projectId));
    final recordAsync = ref.watch(projectDetailRecordProvider(projectId));
    final currentTime = ref.watch(projectDetailNowProvider)();
    final agentAsync = ref.watch(projectAgentProvider(projectId));
    final agent = agentAsync.asData?.value;
    final identity = agent?.mapOrNull(agent: (value) => value);
    final isRefreshingReport =
        identity != null &&
        (ref.watch(agentIsRunningProvider(identity.agentId)).value ?? false);

    if (detailState.isLoading && detailState.project == null) {
      return Scaffold(
        backgroundColor: ShowcasePalette.page(context),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return recordAsync.when(
      skipLoadingOnReload: true,
      loading: () => Scaffold(
        backgroundColor: ShowcasePalette.page(context),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, stackTrace) => Scaffold(
        backgroundColor: ShowcasePalette.page(context),
        body: SafeArea(
          child: ErrorStateWidget(
            error: context.messages.commonError,
            mode: ErrorDisplayMode.inline,
          ),
        ),
      ),
      data: (record) {
        if (record == null) {
          return Scaffold(
            backgroundColor: ShowcasePalette.page(context),
            body: SafeArea(
              child: Center(child: Text(context.messages.projectNotFound)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ShowcasePalette.page(context),
          body: SafeArea(
            child: ProjectMobileDetailContent(
              record: record,
              currentTime: currentTime,
              onBack: () => _handleBack(context),
              onCategoryTap: () => _pickCategory(context, ref, record.project),
              onTargetDateTap: () =>
                  _pickTargetDate(context, ref, record.project),
              onStatusTap: () => _pickStatus(context, ref, record.project),
              onRefreshReport: identity == null
                  ? null
                  : () => ref
                        .read(projectAgentServiceProvider)
                        .triggerReanalysis(identity.agentId),
              onCancelScheduledReportWake: identity == null
                  ? null
                  : () => ref
                        .read(projectAgentServiceProvider)
                        .cancelScheduledWake(identity.agentId),
              isRefreshingReport: isRefreshingReport,
              onTaskTap: (summary) => beamToNamed(
                '/tasks/${summary.task.meta.id}',
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCategory(
    BuildContext context,
    WidgetRef ref,
    ProjectEntry project,
  ) async {
    final result = await showCategoryPicker(
      context: context,
      title: context.messages.habitCategoryLabel,
      currentCategoryId: project.meta.categoryId,
    );
    if (result == null) return;
    final controller = ref.read(
      projectDetailControllerProvider(projectId).notifier,
    );
    await (controller..updateCategoryId(result.categoryOrNull?.id))
        .saveChanges();
  }

  Future<void> _pickTargetDate(
    BuildContext context,
    WidgetRef ref,
    ProjectEntry project,
  ) async {
    final currentDate = project.data.targetDate;
    final firstDate = DateTime(2020);
    final lastDate = clock.now().add(const Duration(days: 365 * 5));
    final initialDate = currentDate ?? clock.now();
    final clampedInitial = initialDate.isBefore(firstDate)
        ? firstDate
        : initialDate.isAfter(lastDate)
        ? lastDate
        : initialDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) {
      return;
    }

    final controller = ref.read(
      projectDetailControllerProvider(projectId).notifier,
    );
    await (controller..updateTargetDate(picked)).saveChanges();
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    ProjectEntry project,
  ) async {
    final selected = await ModalUtils.showBottomSheet<ProjectStatus>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.messages.projectStatusChangeTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final kind in allProjectStatusKinds)
                Builder(
                  builder: (_) {
                    final option = buildProjectStatus(kind, DateTime(2000));
                    final isSelected =
                        option.runtimeType == project.data.status.runtimeType;
                    final (label, color, icon) = projectStatusAttributes(
                      context,
                      option,
                    );

                    return ListTile(
                      leading: Icon(icon, color: color),
                      title: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: color)
                          : null,
                      onTap: () {
                        if (isSelected) {
                          Navigator.of(sheetContext).pop();
                          return;
                        }
                        Navigator.of(sheetContext).pop(
                          buildProjectStatus(kind, clock.now()),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    final controller = ref.read(
      projectDetailControllerProvider(projectId).notifier,
    );
    await (controller..updateStatus(selected)).saveChanges();
  }

  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    beamToNamed('/projects');
  }
}
