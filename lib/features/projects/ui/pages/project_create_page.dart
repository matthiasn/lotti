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
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/ui/widgets/project_target_date_field.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

class ProjectCreatePage extends ConsumerStatefulWidget {
  const ProjectCreatePage({
    this.categoryId,
    super.key,
  });

  final String? categoryId;

  @override
  ConsumerState<ProjectCreatePage> createState() => _ProjectCreatePageState();
}

class _ProjectCreatePageState extends ConsumerState<ProjectCreatePage> {
  late final TextEditingController _titleController;
  DateTime? _targetDate;
  bool _isSaving = false;

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

  Future<void> _handleCreate() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.projectTitleRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Capture services before any async gap so they remain valid even if
    // the page is unmounted during an in-flight await.
    final repository = ref.read(projectRepositoryProvider);
    final templateService = ref.read(agentTemplateServiceProvider);
    final agentService = ref.read(projectAgentServiceProvider);
    final categoryId = widget.categoryId;

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
        // Uses pre-captured services so this works even after unmounting.
        await _provisionProjectAgent(
          templateService: templateService,
          agentService: agentService,
          projectId: created.meta.id,
          displayName: title,
          categoryId: categoryId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.messages.saveSuccessful),
              backgroundColor: successColor,
            ),
          );
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.projectErrorCreateFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to create project',
        name: 'ProjectCreatePage',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.projectErrorCreateFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
  /// even if the page was unmounted during the preceding async gap (e.g.,
  /// the user closed the page while `createProject` was in-flight).
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
        name: 'ProjectCreatePage',
        error: e,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleCreate,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleCreate,
      },
      child: Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                messages.projectCreateTitle,
                style: appBarTextStyleNewLarge.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              pinned: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  LottiFormSection(
                    title: messages.projectTitleLabel,
                    icon: Icons.folder_outlined,
                    children: [
                      LottiTextField(
                        controller: _titleController,
                        labelText: messages.projectTitleLabel,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      ProjectTargetDateField(
                        targetDate: _targetDate,
                        onDatePicked: _pickTargetDate,
                        onCleared: () => setState(() => _targetDate = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: FormBottomBar(
          rightButtons: [
            LottiSecondaryButton(
              onPressed: () => Navigator.of(context).pop(),
              label: messages.cancelButton,
            ),
            LottiPrimaryButton(
              onPressed: _isSaving ? null : _handleCreate,
              label: messages.createButton,
            ),
          ],
        ),
      ),
    );
  }
}
