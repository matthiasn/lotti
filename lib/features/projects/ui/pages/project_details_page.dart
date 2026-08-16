import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_picker.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';

typedef ProjectTaskCreator = Future<Task?> Function(String projectId);
typedef ProjectTaskAgentAssigner = Future<void> Function(Task task);
typedef ProjectAgentSubscriptionsRestorer = Future<void> Function();
typedef ProjectAgentsForProjectResolver =
    Future<List<AgentIdentityEntity>> Function(String projectId);

/// Injectable task-creation seam used by the project detail action.
final projectTaskCreatorProvider = Provider<ProjectTaskCreator>(
  (ref) =>
      (projectId) => createTask(projectId: projectId),
  name: 'projectTaskCreatorProvider',
);

/// Captures the task-agent service before task creation crosses an async gap.
final projectTaskAgentAssignerProvider = Provider<ProjectTaskAgentAssigner>(
  (ref) {
    final service = ref.watch(taskAgentServiceProvider);
    return (task) => autoAssignCategoryAgentWith(service, task);
  },
  name: 'projectTaskAgentAssignerProvider',
);

/// Captures the project-agent service in a callback that remains safe to call
/// if the detail widget is disposed while a project deletion is in flight.
final projectAgentSubscriptionsRestorerProvider =
    Provider<ProjectAgentSubscriptionsRestorer>(
      (ref) => ref.watch(projectAgentServiceProvider).restoreSubscriptions,
      name: 'projectAgentSubscriptionsRestorerProvider',
    );

/// Resolves every live project agent at deletion time, including duplicate
/// identities that can briefly coexist after concurrent provisioning.
final projectAgentsForProjectResolverProvider =
    Provider<ProjectAgentsForProjectResolver>(
      (ref) =>
          ref.watch(projectAgentServiceProvider).getProjectAgentsForProject,
      name: 'projectAgentsForProjectResolverProvider',
    );

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
    final agent = agentAsync.value;
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
              onEdit: () => beamToNamed('/projects/$projectId/edit'),
              onArchive: record.project.data.status is ProjectArchived
                  ? null
                  : () => _archiveProject(context, ref),
              onDelete: () => _deleteProject(
                context,
                ref,
                record.project,
              ),
              onAddTask: () => _addTask(context, ref),
              onRefreshReport: identity == null
                  ? null
                  : () => ref
                        .read(projectAgentServiceProvider)
                        .triggerReanalysis(identity.agentId),
              onCancelScheduledReportWake: identity == null
                  ? null
                  : () async {
                      await _cancelScheduledReportWake(
                        context,
                        ref,
                        identity.agentId,
                      );
                    },
              hasProjectAgent: identity != null,
              isRefreshingReport: isRefreshingReport,
              isSaving: detailState.isSaving,
              onTaskTap: (summary) => beamToNamed(
                '/tasks/${summary.task.meta.id}',
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelScheduledReportWake(
    BuildContext context,
    WidgetRef ref,
    String agentId,
  ) async {
    try {
      await ref.read(projectAgentServiceProvider).cancelScheduledWake(agentId);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to cancel project agent scheduled wake',
        name: 'ProjectDetailsPage',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.commonError,
      );
    }
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
    if (result == null || !context.mounted) return;
    final controller = ref.read(
      projectDetailControllerProvider(projectId).notifier,
    )..updateCategoryId(result.categoryOrNull?.id);
    await _saveInlineUpdate(context, ref, controller);
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

    final result = await showDesignSystemDatePicker(
      context: context,
      title: context.messages.projectTargetDateLabel,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      allowClear: currentDate != null,
    );

    if (result == null || !context.mounted) return;

    final controller = ref.read(
      projectDetailControllerProvider(projectId).notifier,
    )..updateTargetDate(result.cleared ? null : result.date);
    await _saveInlineUpdate(context, ref, controller);
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    ProjectEntry project,
  ) async {
    final selected = await showProjectStatusPickerModal(
      context: context,
      currentStatus: project.data.status,
    );

    if (selected == null || !context.mounted) {
      return;
    }

    final controller = ref.read(
      projectDetailControllerProvider(projectId).notifier,
    )..updateStatus(selected);
    await _saveInlineUpdate(context, ref, controller);
  }

  Future<void> _archiveProject(BuildContext context, WidgetRef ref) async {
    final controller =
        ref.read(
          projectDetailControllerProvider(projectId).notifier,
        )..updateStatus(
          buildProjectStatus(ProjectStatusKind.archived, clock.now()),
        );
    final saved = await _saveInlineUpdate(context, ref, controller);
    if (saved && context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.projectArchiveSuccess,
      );
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    ProjectEntry project,
  ) async {
    final repository = ref.read(projectRepositoryProvider);
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.projectDeleteConfirmTitle,
      message: context.messages.projectDeleteConfirmBody,
      confirmLabel: context.messages.projectActionDelete,
    );
    if (!confirmed || !context.mounted) return;

    late final List<AgentIdentityEntity> projectAgents;
    try {
      projectAgents = await ref.read(
        projectAgentsForProjectResolverProvider,
      )(project.id);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to resolve project agents before deleting their project',
        name: 'ProjectDetailsPage',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectDeleteFailed,
      );
      return;
    }

    final agentService = projectAgents.isEmpty
        ? null
        : ref.read(agentServiceProvider);
    final restoreProjectAgentSubscriptions = projectAgents.isEmpty
        ? null
        : ref.read(projectAgentSubscriptionsRestorerProvider);
    final retiredAgentLifecycles = <String, AgentLifecycle>{};
    for (final projectAgent in projectAgents) {
      final projectAgentId = projectAgent.agentId;
      final liveAgentService = agentService!;
      try {
        liveAgentService.abortRunningWake(projectAgentId);
        final retired = await liveAgentService.destroyAgent(projectAgentId);
        if (retired) {
          retiredAgentLifecycles[projectAgentId] = projectAgent.lifecycle;
        }
        if (!retired) {
          developer.log(
            'Project agent was already absent while deleting its project',
            name: 'ProjectDetailsPage',
          );
        }
      } catch (error, stackTrace) {
        developer.log(
          'Failed to stop and retire project agent while deleting its project',
          name: 'ProjectDetailsPage',
          error: error,
          stackTrace: stackTrace,
        );
        try {
          final persistedAgent = await liveAgentService.getAgent(
            projectAgentId,
          );
          if (persistedAgent?.lifecycle == AgentLifecycle.destroyed &&
              restoreProjectAgentSubscriptions != null) {
            retiredAgentLifecycles[projectAgentId] = projectAgent.lifecycle;
          }
        } catch (recoveryError, recoveryStackTrace) {
          developer.log(
            'Failed to restore project agent after retirement failed',
            name: 'ProjectDetailsPage',
            error: recoveryError,
            stackTrace: recoveryStackTrace,
          );
        }
        await _restoreRetiredProjectAgents(
          agentService: liveAgentService,
          agentLifecycles: retiredAgentLifecycles,
          restoreSubscriptions: restoreProjectAgentSubscriptions,
        );
        if (!context.mounted) return;
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.projectDeleteFailed,
        );
        return;
      }
    }

    var deleted = false;
    try {
      deleted = await repository.deleteProject(
        project,
        deletedAt: clock.now(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to soft-delete project',
        name: 'ProjectDetailsPage',
        error: error,
        stackTrace: stackTrace,
      );
    }
    var projectStillExists = false;
    if (!deleted) {
      try {
        projectStillExists =
            await repository.getProjectById(project.id) != null;
        deleted = !projectStillExists;
      } catch (error, stackTrace) {
        developer.log(
          'Failed to verify project tombstone after deletion failed',
          name: 'ProjectDetailsPage',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (!deleted &&
        projectStillExists &&
        agentService != null &&
        restoreProjectAgentSubscriptions != null) {
      await _restoreRetiredProjectAgents(
        agentService: agentService,
        agentLifecycles: retiredAgentLifecycles,
        restoreSubscriptions: restoreProjectAgentSubscriptions,
      );
    }
    if (!context.mounted) return;
    if (!deleted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectDeleteFailed,
      );
      return;
    }

    if (!context.mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.projectDeleteSuccess,
    );
    _handleBack(context);
  }

  Future<void> _restoreRetiredProjectAgents({
    required AgentService agentService,
    required Map<String, AgentLifecycle> agentLifecycles,
    required ProjectAgentSubscriptionsRestorer? restoreSubscriptions,
  }) async {
    if (restoreSubscriptions == null || agentLifecycles.isEmpty) return;
    var restoredAnyActiveAgent = false;
    for (final MapEntry(key: agentId, value: lifecycle)
        in agentLifecycles.entries) {
      try {
        final restored = await _restoreRetiredProjectAgent(
          agentService: agentService,
          agentId: agentId,
          lifecycle: lifecycle,
        );
        restoredAnyActiveAgent |=
            restored && lifecycle == AgentLifecycle.active;
        if (!restored) {
          developer.log(
            'Project agent disappeared while restoring a failed deletion',
            name: 'ProjectDetailsPage',
          );
        }
      } catch (error, stackTrace) {
        developer.log(
          'Failed to restore project agent after project deletion failed',
          name: 'ProjectDetailsPage',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (restoredAnyActiveAgent) await restoreSubscriptions();
  }

  Future<bool> _restoreRetiredProjectAgent({
    required AgentService agentService,
    required String agentId,
    required AgentLifecycle lifecycle,
  }) async {
    try {
      final restored = await agentService.restoreAgentLifecycle(
        agentId,
        lifecycle,
      );
      if (!restored) return false;
    } catch (error, stackTrace) {
      final persistedAgent = await agentService.getAgent(agentId);
      if (persistedAgent?.lifecycle != lifecycle) rethrow;
      developer.log(
        'Project agent lifecycle restore committed before its sync flush failed',
        name: 'ProjectDetailsPage',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final createProjectTask = ref.read(projectTaskCreatorProvider);
    final assignTaskAgent = ref.read(projectTaskAgentAssignerProvider);
    final task = await createProjectTask(projectId);
    if (task == null) {
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.commonError,
      );
      return;
    }
    try {
      await assignTaskAgent(task);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to assign category agent to project task',
        name: 'ProjectDetailsPage',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.commonError,
      );
    }
    if (!context.mounted) return;
    beamToNamed('/tasks/${task.meta.id}');
  }

  Future<bool> _saveInlineUpdate(
    BuildContext context,
    WidgetRef ref,
    ProjectDetailController controller,
  ) async {
    await controller.saveChanges();
    if (!context.mounted) return false;
    final detailState = ref.read(projectDetailControllerProvider(projectId));
    if (detailState.error == null) return true;

    controller.discardChanges();
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.projectErrorUpdateFailed,
    );
    return false;
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
