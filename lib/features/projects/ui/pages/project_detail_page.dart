import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_report_card.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';
import 'package:lotti/features/projects/ui/widgets/project_linked_tasks_section.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_picker.dart';
import 'package:lotti/features/projects/ui/widgets/project_target_date_field.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({
    required this.projectId,
    this.categoryId,
    super.key,
  });

  final String projectId;
  final String? categoryId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _syncTitleWithProject(String title) {
    if (_titleController.text != title) {
      _titleController.value = TextEditingValue(
        text: title,
        selection: TextSelection.collapsed(offset: title.length),
      );
    }
  }

  Future<void> _handleSave() async {
    final currentState = ref.read(
      projectDetailControllerProvider(widget.projectId),
    );
    if (!currentState.hasChanges || currentState.isSaving) return;

    final controller = ref.read(
      projectDetailControllerProvider(widget.projectId).notifier,
    );
    await controller.saveChanges();

    if (!mounted) return;

    final state = ref.read(
      projectDetailControllerProvider(widget.projectId),
    );
    if (state.error != null) return;

    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.saveSuccessful,
    );
    _handleBackNavigation();
  }

  void _handleBackNavigation() {
    final categoryId = widget.categoryId;
    if (categoryId != null && getIt.isRegistered<NavService>()) {
      getIt<NavService>().beamToNamed('/settings/categories/$categoryId');
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (getIt.isRegistered<NavService>()) {
      final navService = getIt<NavService>();
      if (navService.currentPath.startsWith('/settings/projects')) {
        navService.beamBack();
      }
    }
  }

  Future<void> _pickTargetDate() async {
    final controller = ref.read(
      projectDetailControllerProvider(widget.projectId).notifier,
    );
    final currentDate = ref
        .read(projectDetailControllerProvider(widget.projectId))
        .project
        ?.data
        .targetDate;

    final firstDate = DateTime(2020);
    final lastDate = DateTime.now().add(const Duration(days: 365 * 5));
    final initialDate = currentDate ?? DateTime.now();
    // Clamp to valid range so the date picker assertion doesn't fire
    // when an existing target date falls outside the bounds.
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
    if (picked != null) {
      controller.updateTargetDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      projectDetailControllerProvider(widget.projectId),
    );
    final messages = context.messages;
    final project = state.project;
    final healthMetrics = ref.watch(
      projectHealthMetricsProvider(widget.projectId),
    );

    if (project == null && !state.isLoading) {
      final isLoadFailure = state.error == ProjectDetailError.loadFailed;
      return Scaffold(
        appBar: AppBar(title: Text(messages.projectDetailTitle)),
        body: Center(
          child: Text(
            isLoadFailure
                ? messages.projectErrorLoadFailed
                : messages.projectNotFound,
          ),
        ),
      );
    }

    if (project != null && !state.hasChanges) {
      _syncTitleWithProject(project.data.title);
    }

    return PopScope(
      canPop: widget.categoryId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.categoryId != null) {
          _handleBackNavigation();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(
            LogicalKeyboardKey.keyS,
            meta: true,
          ): _handleSave,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _handleSave,
        },
        child: Scaffold(
          backgroundColor: context.colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                leading:
                    widget.categoryId != null || Navigator.of(context).canPop()
                    ? IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: _handleBackNavigation,
                        icon: const Icon(Icons.arrow_back),
                      )
                    : null,
                title: Text(
                  messages.projectDetailTitle,
                  style: appBarTextStyleNewLarge.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                pinned: true,
              ),
              if (state.error != null)
                SliverToBoxAdapter(
                  child: ErrorStateWidget(
                    error: _localizeError(messages, state.error!),
                    mode: ErrorDisplayMode.inline,
                  ),
                ),
              if (state.isLoading && project == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (project != null)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Status Section
                      LottiFormSection(
                        title: messages.projectStatusChangeTitle,
                        icon: Icons.flag_outlined,
                        children: [
                          ProjectStatusPicker(
                            currentStatus: project.data.status,
                            onStatusChanged: (status) {
                              ref
                                  .read(
                                    projectDetailControllerProvider(
                                      widget.projectId,
                                    ).notifier,
                                  )
                                  .updateStatus(status);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Title & Target Date Section
                      LottiFormSection(
                        title: messages.projectTitleLabel,
                        icon: Icons.folder_outlined,
                        children: [
                          LottiTextField(
                            controller: _titleController,
                            labelText: messages.projectTitleLabel,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (value) {
                              ref
                                  .read(
                                    projectDetailControllerProvider(
                                      widget.projectId,
                                    ).notifier,
                                  )
                                  .updateTitle(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          ProjectTargetDateField(
                            targetDate: project.data.targetDate,
                            onDatePicked: _pickTargetDate,
                            onCleared: () {
                              ref
                                  .read(
                                    projectDetailControllerProvider(
                                      widget.projectId,
                                    ).notifier,
                                  )
                                  .updateTargetDate(null);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (healthMetrics.asData?.value case final metrics?) ...[
                        LottiFormSection(
                          title: messages.projectHealthSectionTitle,
                          icon: Icons.monitor_heart_outlined,
                          children: [
                            ProjectHealthIndicator(metrics: metrics),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Agent Report
                      ProjectAgentReportCard(
                        projectId: widget.projectId,
                        projectTitle: project.data.title,
                        categoryId: project.meta.categoryId,
                      ),
                      const SizedBox(height: 24),

                      ChangeSetSummaryCard.project(projectId: widget.projectId),
                      const SizedBox(height: 24),

                      // Linked Tasks
                      ProjectLinkedTasksSection(tasks: state.linkedTasks),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(state),
        ),
      ),
    );
  }

  String _localizeError(AppLocalizations messages, ProjectDetailError error) {
    return switch (error) {
      ProjectDetailError.loadFailed => messages.projectErrorLoadFailed,
      ProjectDetailError.updateFailed => messages.projectErrorUpdateFailed,
      ProjectDetailError.titleRequired => messages.projectTitleRequired,
    };
  }

  Widget _buildBottomBar(ProjectDetailState state) {
    final messages = context.messages;
    return FormBottomBar(
      rightButtons: [
        LottiSecondaryButton(
          onPressed: _handleBackNavigation,
          label: messages.cancelButton,
        ),
        LottiPrimaryButton(
          onPressed: state.isSaving || !state.hasChanges ? null : _handleSave,
          label: messages.saveButton,
        ),
      ],
    );
  }
}
