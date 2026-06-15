import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/ui/widgets/project_target_date_field.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Upper bound on the form's height as a fraction of the viewport.
///
/// The form fields live in a scroll view so a soft keyboard, landscape phone,
/// or large accessibility text size shrinks the scroll area instead of
/// overflowing the sheet. Mirrors the established create-modal sizing used by
/// `CategoryCreateModal`.
const double _modalMaxHeightFraction = 0.9;

/// Opens the responsive project-creation overlay.
///
/// Reuses [ModalUtils.showSinglePageModal], which renders a draggable bottom
/// sheet on narrow (mobile) layouts and a centered dialog on wide (desktop)
/// ones — the switch happens automatically at the modal page breakpoint, so
/// callers do not branch on platform or screen size themselves.
///
/// Resolves to the freshly created [ProjectEntry] when a project is saved, or
/// `null` when the overlay is dismissed (Cancel, the close button, the scrim,
/// or back). [categoryId] preselects a category for the new project.
Future<ProjectEntry?> showProjectCreateModal({
  required BuildContext context,
  String? categoryId,
}) {
  return ModalUtils.showSinglePageModal<ProjectEntry>(
    context: context,
    title: context.messages.projectCreateTitle,
    builder: (modalContext) => ProjectCreateForm(categoryId: categoryId),
  );
}

/// The project-creation form rendered inside [showProjectCreateModal].
///
/// Collects a title, optional category, and optional target date, then persists
/// the project through [ProjectRepository] and provisions a project agent when a
/// matching template exists. On success it pops the enclosing modal with the
/// created [ProjectEntry]; on failure it surfaces a toast and stays open.
class ProjectCreateForm extends ConsumerStatefulWidget {
  const ProjectCreateForm({
    this.categoryId,
    super.key,
  });

  final String? categoryId;

  @override
  ConsumerState<ProjectCreateForm> createState() => _ProjectCreateFormState();
}

class _ProjectCreateFormState extends ConsumerState<ProjectCreateForm> {
  late final TextEditingController _titleController;
  DateTime? _targetDate;
  String? _categoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _categoryId = widget.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectTitleRequired,
      );
      return;
    }

    setState(() => _isSaving = true);

    // Capture services before any async gap so provisioning still completes
    // even if the modal is dismissed during an in-flight await.
    final repository = ref.read(projectRepositoryProvider);
    final templateService = ref.read(agentTemplateServiceProvider);
    final agentService = ref.read(projectAgentServiceProvider);
    final categoryId = _categoryId;

    try {
      final now = DateTime.now();
      final meta = await getIt<PersistenceLogic>().createMetadata(
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
      );

      final project =
          JournalEntity.project(
                meta: meta,
                data: ProjectData(
                  title: title,
                  status: ProjectStatus.open(
                    id: uuid.v1(),
                    createdAt: now,
                    utcOffset: now.timeZoneOffset.inMinutes,
                  ),
                  dateFrom: now,
                  dateTo: now,
                  targetDate: _targetDate,
                ),
              )
              as ProjectEntry;

      final created = await repository.createProject(project: project);

      if (created != null) {
        // Provision a project agent if a projectAgent template exists.
        // Uses pre-captured services so this works even after the modal closes.
        await _provisionProjectAgent(
          templateService: templateService,
          agentService: agentService,
          projectId: created.meta.id,
          displayName: title,
          categoryId: categoryId,
        );

        // The freshly-created project appears in the projects list
        // immediately on close (the list watches `projectsOverviewProvider`),
        // which is enough confirmation on its own. The created project is
        // returned to the caller for any follow-up (e.g. navigation).
        //
        // Guard on `mounted`: if the user dismissed the modal while the create
        // was in-flight, the agent was still provisioned above, but popping a
        // stale navigator could close an unrelated route — so skip it.
        if (mounted) {
          Navigator.of(context).pop(created);
        }
      } else if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.projectErrorCreateFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to create project',
        name: 'ProjectCreateForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.projectErrorCreateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickTargetDate() async {
    final today = DateTime.now();
    final baseDate = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? baseDate,
      firstDate: baseDate,
      lastDate: DateTime(baseDate.year + 5, baseDate.month, baseDate.day),
    );
    if (!mounted || picked == null) return;
    setState(() => _targetDate = picked);
  }

  /// Finds the first available projectAgent template and provisions an agent.
  ///
  /// Accepts pre-captured service references so that provisioning succeeds
  /// even if the modal was closed during the preceding async gap (e.g., the
  /// user dismissed it while `createProject` was in-flight).
  ///
  /// Prefers category-scoped templates when a category ID is available,
  /// falling back to the global template list — consistent with the
  /// task-agent flow in `task_agent_report_section.dart`.
  /// Silently skips if no template exists — agent creation is non-fatal.
  Future<void> _provisionProjectAgent({
    required AgentTemplateService templateService,
    required ProjectAgentService agentService,
    required String projectId,
    required String displayName,
    required String? categoryId,
  }) async {
    try {
      // Prefer category-scoped templates; fall back to global templates if
      // category lookup fails or yields no projectAgent template.
      var categoryTemplates = <AgentTemplateEntity>[];
      if (categoryId != null) {
        try {
          categoryTemplates = await templateService.listTemplatesForCategory(
            categoryId,
          );
        } catch (_) {
          // Continue with global fallback.
        }
      }
      var projectTemplate = categoryTemplates
          .where((t) => t.kind == AgentTemplateKind.projectAgent)
          .firstOrNull;
      if (projectTemplate == null) {
        final globalTemplates = await templateService.listTemplates();
        projectTemplate = globalTemplates
            .where(
              (t) =>
                  t.kind == AgentTemplateKind.projectAgent &&
                  t.categoryIds.isEmpty,
            )
            .firstOrNull;
      }
      if (projectTemplate == null) return;

      await agentService.createProjectAgent(
        projectId: projectId,
        templateId: projectTemplate.id,
        displayName: displayName,
        allowedCategoryIds: {?categoryId},
      );
    } catch (e, s) {
      developer.log(
        'Failed to provision project agent',
        name: 'ProjectCreateForm',
        error: e,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleCreate,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleCreate,
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * _modalMaxHeightFraction,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LottiTextField(
                      controller: _titleController,
                      labelText: messages.projectTitleLabel,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: tokens.spacing.step5),
                    CategoryField(
                      categoryId: _categoryId,
                      onSave: (category) =>
                          setState(() => _categoryId = category?.id),
                    ),
                    SizedBox(height: tokens.spacing.step5),
                    ProjectTargetDateField(
                      targetDate: _targetDate,
                      onDatePicked: _pickTargetDate,
                      onCleared: () => setState(() => _targetDate = null),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DesignSystemButton(
                  label: messages.cancelButton,
                  variant: DesignSystemButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                SizedBox(width: tokens.spacing.step4),
                DesignSystemButton(
                  label: messages.createButton,
                  onPressed: _isSaving ? null : _handleCreate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
