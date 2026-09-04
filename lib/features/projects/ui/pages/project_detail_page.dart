import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_picker.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';

/// Full-screen, form-style project editor used by the Projects-owned
/// `/projects/<id>/edit` route and settings/category entry points.
///
/// Edits go through [ProjectDetailController]: title, description, category,
/// status, and target date mutate the controller's pending project, and the
/// nearby action row's Save button persists them (also bound to Cmd/Ctrl+S). On a
/// successful save it shows a success toast and navigates back. Cancel and
/// system-back exits discard the shared controller draft before navigation so
/// the underlying desktop detail cannot retain or later persist canceled data.
///
/// When [returnPath] is supplied, successful saves and explicit back actions
/// beam there first. Otherwise, when [categoryId] is non-null the page came
/// from a category screen, so back navigation beams to that category instead
/// of a plain `pop`, and [PopScope] is locked (`canPop: false`) to route the
/// gesture through the same handler.
///
/// This is the desktop/settings editor; the read-first mobile/desktop detail
/// surface is `ProjectDetailsPage`.
class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({
    required this.projectId,
    this.categoryId,
    this.returnPath,
    super.key,
  });

  final String projectId;
  final String? categoryId;
  final String? returnPath;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _syncControllersWithProject(
    ProjectEntry project, {
    required bool syncTitle,
    required bool syncDescription,
  }) {
    final title = project.data.title;
    if (syncTitle && _titleController.text != title) {
      _titleController.value = TextEditingValue(
        text: title,
        selection: TextSelection.collapsed(offset: title.length),
      );
    }
    final description = project.entryText?.plainText ?? '';
    if (syncDescription && _descriptionController.text != description) {
      _descriptionController.value = TextEditingValue(
        text: description,
        selection: TextSelection.collapsed(offset: description.length),
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
    _handleBackNavigation(discardChanges: false);
  }

  void _discardPendingChanges() {
    final controller = ref.read(
      projectDetailControllerProvider(widget.projectId).notifier,
    );
    final state = ref.read(
      projectDetailControllerProvider(widget.projectId),
    );
    if (!state.isSaving && state.hasChanges) controller.discardChanges();
  }

  void _handleBackNavigation({bool discardChanges = true}) {
    final state = ref.read(
      projectDetailControllerProvider(widget.projectId),
    );
    if (state.isSaving) return;
    if (discardChanges) _discardPendingChanges();
    final returnPath = widget.returnPath;
    if (returnPath != null && getIt.isRegistered<NavService>()) {
      getIt<NavService>().beamToNamed(returnPath);
      return;
    }

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

    final result = await showDesignSystemDatePicker(
      context: context,
      title: context.messages.projectTargetDateLabel,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      allowClear: currentDate != null,
    );
    if (!mounted || result == null) return;
    controller.updateTargetDate(result.cleared ? null : result.date);
  }

  Future<void> _pickStatus() async {
    final state = ref.read(
      projectDetailControllerProvider(widget.projectId),
    );
    final currentStatus = state.project?.data.status;
    if (currentStatus == null) return;

    final selected = await showProjectStatusPickerModal(
      context: context,
      currentStatus: currentStatus,
    );
    if (!mounted || selected == null) return;
    ref
        .read(projectDetailControllerProvider(widget.projectId).notifier)
        .updateStatus(selected);
  }

  Future<void> _pickCategory() async {
    final project = ref
        .read(projectDetailControllerProvider(widget.projectId))
        .project;
    if (project == null) return;

    final result = await showCategoryPicker(
      context: context,
      title: context.messages.habitCategoryLabel,
      currentCategoryId: project.meta.categoryId,
    );
    if (!mounted || result == null) return;
    ref
        .read(projectDetailControllerProvider(widget.projectId).notifier)
        .updateCategoryId(result.categoryOrNull?.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      projectDetailControllerProvider(widget.projectId),
    );
    final messages = context.messages;
    final project = state.project;
    final detailController = ref.read(
      projectDetailControllerProvider(widget.projectId).notifier,
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

    if (project != null) {
      _syncControllersWithProject(
        project,
        syncTitle: !detailController.isTitleDirty,
        syncDescription: !detailController.isDescriptionDirty,
      );
    }

    return PopScope(
      canPop:
          !state.isSaving &&
          widget.categoryId == null &&
          widget.returnPath == null,
      onPopInvokedWithResult: (didPop, _) {
        if (state.isSaving) return;
        if (didPop) {
          _discardPendingChanges();
        } else if (widget.categoryId != null || widget.returnPath != null) {
          _handleBackNavigation();
        }
      },
      child: AppCommandScope(
        handlers: {
          AppCommandId.save: AppCommandHandler(
            isEnabled: () => state.hasChanges && !state.isSaving,
            invoke: (_) => _handleSave(),
          ),
        },
        child: Scaffold(
          backgroundColor: ShowcasePalette.page(context),
          body: SafeArea(
            child: DetailContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.categoryId != null ||
                      widget.returnPath != null ||
                      Navigator.of(context).canPop())
                    Padding(
                      padding: EdgeInsets.only(
                        top: context.designTokens.spacing.step3,
                      ),
                      child: DesignSystemBackControl(
                        foregroundColor: ShowcasePalette.highText(context),
                        onTap: state.isSaving ? null : _handleBackNavigation,
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: context.designTokens.spacing.step4,
                        bottom: context.designTokens.spacing.step6,
                      ),
                      child: Column(
                        children: [
                          _ProjectEditorContent(
                            state: state,
                            titleController: _titleController,
                            descriptionController: _descriptionController,
                            onTitleChanged: (value) => ref
                                .read(
                                  projectDetailControllerProvider(
                                    widget.projectId,
                                  ).notifier,
                                )
                                .updateTitle(value),
                            onDescriptionChanged: (value) => ref
                                .read(
                                  projectDetailControllerProvider(
                                    widget.projectId,
                                  ).notifier,
                                )
                                .updateDescription(value),
                            onCategoryTap: _pickCategory,
                            onStatusTap: _pickStatus,
                            onTargetDateTap: _pickTargetDate,
                            localizedError: state.error == null
                                ? null
                                : _localizeError(messages, state.error!),
                          ),
                          SizedBox(
                            height: context.designTokens.spacing.step4,
                          ),
                          _buildActions(state),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildActions(ProjectDetailState state) {
    final messages = context.messages;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: context.designTokens.spacing.step2,
        children: [
          DesignSystemButton(
            label: messages.cancelButton,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: state.isSaving ? null : _handleBackNavigation,
          ),
          DesignSystemButton(
            label: messages.saveButton,
            onPressed: state.isSaving || !state.hasChanges ? null : _handleSave,
          ),
        ],
      ),
    );
  }
}

class _ProjectEditorContent extends StatelessWidget {
  const _ProjectEditorContent({
    required this.state,
    required this.titleController,
    required this.descriptionController,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onCategoryTap,
    required this.onStatusTap,
    required this.onTargetDateTap,
    required this.localizedError,
  });

  final ProjectDetailState state;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onCategoryTap;
  final VoidCallback onStatusTap;
  final VoidCallback onTargetDateTap;
  final String? localizedError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final project = state.project;

    if (state.isLoading && project == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (project == null) return const SizedBox.shrink();

    final (statusLabel, statusColor, statusIcon) = projectStatusAttributes(
      context,
      project.data.status,
    );
    final targetDate = project.data.targetDate;
    final category = getIt<EntitiesCacheService>().getCategoryById(
      project.meta.categoryId,
    );
    final categoryColor = colorFromCssHex(
      category?.color ?? defaultCategoryColorHex,
    );
    final targetDateLabel = targetDate == null
        ? messages.projectTargetDateLabel
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(targetDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            messages.projectDetailTitle,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: ShowcasePalette.highText(context),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        if (localizedError case final error?) ...[
          ErrorStateWidget(error: error, mode: ErrorDisplayMode.inline),
          SizedBox(height: tokens.spacing.step4),
        ],
        DesignSystemSectionCard(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.step5,
                  tokens.spacing.step3,
                  tokens.spacing.step5,
                  tokens.spacing.step4,
                ),
                child: DesignSystemTextInput(
                  controller: titleController,
                  label: messages.projectTitleLabel,
                  leadingIcon: LottiIcons.folder,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: onTitleChanged,
                  enabled: !state.isSaving,
                ),
              ),
              const DesignSystemDivider(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.step5,
                  tokens.spacing.step4,
                  tokens.spacing.step5,
                  tokens.spacing.step4,
                ),
                child: DesignSystemTextarea(
                  controller: descriptionController,
                  label: messages.projectShowcaseDescriptionTitle,
                  growWithContent: true,
                  enabled: !state.isSaving,
                  onChanged: onDescriptionChanged,
                ),
              ),
              const DesignSystemDivider(),
              DesignSystemSelectionRow(
                title: messages.habitCategoryLabel,
                subtitle:
                    category?.name ?? messages.taskCategoryUnassignedLabel,
                type: DesignSystemSelectionRowType.navigation,
                leading: Icon(
                  category?.icon?.iconData ?? LottiIcons.folder,
                  color: categoryColor,
                ),
                onTap: state.isSaving ? null : onCategoryTap,
              ),
              const DesignSystemDivider(),
              DesignSystemSelectionRow(
                title: messages.projectStatusChangeTitle,
                subtitle: statusLabel,
                type: DesignSystemSelectionRowType.navigation,
                leading: Icon(statusIcon, color: statusColor),
                onTap: state.isSaving ? null : onStatusTap,
              ),
              const DesignSystemDivider(),
              DesignSystemSelectionRow(
                title: messages.projectTargetDateLabel,
                subtitle: targetDateLabel,
                type: DesignSystemSelectionRowType.navigation,
                leading: Icon(
                  LottiIcons.today,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                onTap: state.isSaving ? null : onTargetDateTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
