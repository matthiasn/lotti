import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_model_selector.dart';
import 'package:lotti/features/agents/ui/agent_one_on_one_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/form/lotti_text_field.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

/// Detail page for creating or editing an agent template.
///
/// - **Create mode** (`templateId == null`): empty form, save creates template.
/// - **Edit mode** (`templateId != null`): populated form, save creates new
///   version. Shows version history and active instances.
class AgentTemplateDetailPage extends ConsumerStatefulWidget {
  const AgentTemplateDetailPage({
    this.templateId,
    super.key,
  });

  final String? templateId;

  bool get isCreateMode => templateId == null;

  @override
  ConsumerState<AgentTemplateDetailPage> createState() =>
      _AgentTemplateDetailPageState();
}

class _AgentTemplateDetailPageState
    extends ConsumerState<AgentTemplateDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _directivesController;
  String? _selectedModelId;
  bool _didSeedControllers = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _directivesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _directivesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCreateMode) {
      return _buildScaffold(context, template: null, activeVersion: null);
    }

    final templateAsync = ref.watch(agentTemplateProvider(widget.templateId!));
    final activeVersionAsync =
        ref.watch(activeTemplateVersionProvider(widget.templateId!));

    final template = templateAsync.value?.mapOrNull(agentTemplate: (e) => e);
    final activeVersion =
        activeVersionAsync.value?.mapOrNull(agentTemplateVersion: (v) => v);

    if (templateAsync.isLoading && template == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (template == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Template not found')),
      );
    }

    // Seed controllers once from loaded data.
    if (!_didSeedControllers) {
      _nameController.text = template.displayName;
      _selectedModelId = template.modelId;
      if (activeVersion != null) {
        _directivesController.text = activeVersion.directives;
      }
      _didSeedControllers = true;
    }

    return _buildScaffold(
      context,
      template: template,
      activeVersion: activeVersion,
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required AgentTemplateEntity? template,
    required AgentTemplateVersionEntity? activeVersion,
  }) {
    final title = widget.isCreateMode
        ? context.messages.agentTemplateCreateTitle
        : context.messages.agentTemplateEditTitle;

    final saveEnabled = !_isSaving &&
        _nameController.text.trim().isNotEmpty &&
        (_selectedModelId?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              title,
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
                _buildFormFields(context),
                if (!widget.isCreateMode && widget.templateId != null) ...[
                  const SizedBox(height: 24),
                  _VersionHistorySection(templateId: widget.templateId!),
                  const SizedBox(height: 24),
                  _ActiveInstancesSection(templateId: widget.templateId!),
                  const SizedBox(height: 24),
                  LottiSecondaryButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AgentOneOnOnePage(
                          templateId: widget.templateId!,
                        ),
                      ),
                    ),
                    label: context.messages.agentTemplateEvolveAction,
                    icon: Icons.auto_awesome,
                  ),
                ],
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: FormBottomBar(
        leftButton: widget.isCreateMode
            ? null
            : LottiTertiaryButton(
                onPressed: _isSaving ? null : () => _handleDelete(context),
                icon: Icons.delete_outline,
                label: context.messages.deleteButton,
                isDestructive: true,
              ),
        rightButtons: [
          LottiSecondaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: context.messages.cancelButton,
          ),
          LottiPrimaryButton(
            onPressed: saveEnabled ? () => _handleSave(context) : null,
            label: widget.isCreateMode
                ? context.messages.createButton
                : context.messages.agentTemplateSaveNewVersion,
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LottiTextField(
          controller: _nameController,
          labelText: context.messages.agentTemplateDisplayNameLabel,
          autofocus: widget.isCreateMode,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        AgentModelSelector(
          currentModelId: _selectedModelId,
          onModelSelected: (id) => setState(() => _selectedModelId = id),
        ),
        const SizedBox(height: 16),
        LottiTextArea(
          controller: _directivesController,
          labelText: context.messages.agentTemplateDirectivesLabel,
          hintText: context.messages.agentTemplateDirectivesHint,
          minLines: 4,
          maxLines: 12,
        ),
      ],
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    setState(() => _isSaving = true);

    try {
      final templateService = ref.read(agentTemplateServiceProvider);
      final name = _nameController.text.trim();
      final modelId = _selectedModelId ?? '';
      final directives = _directivesController.text.trim();

      if (widget.isCreateMode) {
        await templateService.createTemplate(
          displayName: name,
          kind: AgentTemplateKind.taskAgent,
          modelId: modelId,
          directives: directives,
          authoredBy: 'user',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentTemplateCreatedSuccess),
          ),
        );
        ref.invalidate(agentTemplatesProvider);
        Navigator.of(context).pop();
      } else {
        await templateService.createVersion(
          templateId: widget.templateId!,
          directives: directives,
          authoredBy: 'user',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentTemplateVersionSaved),
          ),
        );
        ref
          ..invalidate(agentTemplatesProvider)
          ..invalidate(activeTemplateVersionProvider(widget.templateId!))
          ..invalidate(templateVersionHistoryProvider(widget.templateId!));
      }
    } catch (e, s) {
      developer.log(
        'Failed to save template',
        name: 'AgentTemplateDetailPage',
        error: e,
        stackTrace: s,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleDelete(BuildContext context) {
    final pageContext = context;
    showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.messages.deleteButton),
        content: Text(dialogContext.messages.agentTemplateDeleteConfirm),
        actions: [
          LottiTertiaryButton(
            onPressed: () => Navigator.pop(dialogContext),
            label: dialogContext.messages.cancelButton,
          ),
          LottiTertiaryButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final templateService = ref.read(agentTemplateServiceProvider);
                await templateService.deleteTemplate(widget.templateId!);
                if (!mounted || !pageContext.mounted) return;
                ref.invalidate(agentTemplatesProvider);
                Navigator.of(pageContext).pop();
              } on Exception catch (e) {
                if (!mounted || !pageContext.mounted) return;
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      pageContext.messages.agentTemplateDeleteHasInstances,
                    ),
                  ),
                );
                developer.log(
                  'Delete failed',
                  name: 'AgentTemplateDetailPage',
                  error: e,
                );
              }
            },
            label: dialogContext.messages.deleteButton,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

/// Expandable section showing version history for a template.
class _VersionHistorySection extends ConsumerWidget {
  const _VersionHistorySection({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(templateVersionHistoryProvider(templateId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentTemplateVersionHistoryTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        historyAsync.when(
          data: (versions) {
            final typed =
                versions.whereType<AgentTemplateVersionEntity>().toList();
            if (typed.isEmpty) {
              return const Text('No versions');
            }
            return Column(
              children: typed.map((version) {
                return _VersionTile(
                  version: version,
                  templateId: templateId,
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(e.toString()),
        ),
      ],
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({
    required this.version,
    required this.templateId,
  });

  final AgentTemplateVersionEntity version;
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = version.status == AgentTemplateVersionStatus.active;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: ListTile(
        title: Text(
          context.messages.agentTemplateVersionLabel(version.version),
        ),
        subtitle: Text(formatAgentDateTime(version.createdAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSmall,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? context.colorScheme.primaryContainer
                    : context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
              ),
              child: Text(
                isActive ? 'Active' : 'Archived',
                style: context.textTheme.labelSmall,
              ),
            ),
            if (!isActive) ...[
              const SizedBox(width: AppTheme.spacingSmall),
              IconButton(
                icon: const Icon(Icons.restore, size: 20),
                tooltip: context.messages.agentTemplateRollbackAction,
                onPressed: () => _handleRollback(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleRollback(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.messages.agentTemplateRollbackAction),
        content: Text(
          dialogContext.messages.agentTemplateRollbackConfirm(version.version),
        ),
        actions: [
          LottiTertiaryButton(
            onPressed: () => Navigator.pop(dialogContext),
            label: dialogContext.messages.cancelButton,
          ),
          LottiPrimaryButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final templateService = ref.read(agentTemplateServiceProvider);
              await templateService.rollbackToVersion(
                templateId: templateId,
                versionId: version.id,
              );
              ref
                ..invalidate(
                  activeTemplateVersionProvider(templateId),
                )
                ..invalidate(
                  templateVersionHistoryProvider(templateId),
                );
            },
            label: dialogContext.messages.agentTemplateRollbackAction,
          ),
        ],
      ),
    );
  }
}

/// Section showing agents that use this template.
class _ActiveInstancesSection extends ConsumerWidget {
  const _ActiveInstancesSection({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We use FutureBuilder directly since there's no dedicated provider
    // for this reverse lookup.
    final templateService = ref.watch(agentTemplateServiceProvider);

    return FutureBuilder<List<AgentIdentityEntity>>(
      future: templateService.getAgentsForTemplate(templateId),
      builder: (context, snapshot) {
        final agents = snapshot.data ?? [];
        if (agents.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.agentTemplateActiveInstancesTitle,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              context.messages.agentTemplateInstanceCount(agents.length),
              style: context.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
