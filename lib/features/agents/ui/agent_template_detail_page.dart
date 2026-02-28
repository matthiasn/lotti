import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_model_selector.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/template_token_usage_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
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
    extends ConsumerState<AgentTemplateDetailPage>
    with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _directivesController;
  String? _selectedModelId;
  bool _didSeedControllers = false;
  String? _seededVersionId;
  bool _isSaving = false;
  TabController? _tabController;

  static const _tabCount = 3;

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _directivesController = TextEditingController();
    if (widget.isCreateMode) {
      _selectedModelId = 'models/gemini-3-flash-preview';
    } else {
      _tabController = TabController(length: _tabCount, vsync: this)
        ..addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (_tabController != null && _tabController!.index != _currentTabIndex) {
      setState(() => _currentTabIndex = _tabController!.index);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _nameController.dispose();
    _directivesController.dispose();
    _tabController?.dispose();
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

    if (templateAsync.hasError && template == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 30,
              color: Theme.of(context).colorScheme.outline,
            ),
            onPressed: () => getIt<NavService>().beamBack(),
          ),
        ),
        body: Center(
          child: Text(
            context.messages.commonError,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (template == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 30,
              color: Theme.of(context).colorScheme.outline,
            ),
            onPressed: () => getIt<NavService>().beamBack(),
          ),
        ),
        body: Center(
          child: Text(context.messages.agentTemplateNotFound),
        ),
      );
    }

    // Seed controllers from loaded data. Re-seed when the active version
    // changes (e.g. after an evolution proposal is approved).
    if (!_didSeedControllers) {
      _nameController.text = template.displayName;
      _selectedModelId = template.modelId;
      if (activeVersion != null) {
        _directivesController.text = activeVersion.directives;
        _seededVersionId = activeVersion.id;
      }
      _didSeedControllers = true;
    } else if (activeVersion != null && activeVersion.id != _seededVersionId) {
      _directivesController.text = activeVersion.directives;
      _seededVersionId = activeVersion.id;
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

    final showBottomBar = widget.isCreateMode || _currentTabIndex == 0;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: widget.isCreateMode
          ? _buildCreateBody(context, title: title)
          : _buildEditBody(context, title: title),
      bottomNavigationBar: showBottomBar
          ? FormBottomBar(
              leftButton: widget.isCreateMode
                  ? null
                  : IconButton(
                      onPressed:
                          _isSaving ? null : () => _handleDelete(context),
                      icon: Icon(
                        Icons.delete_outline,
                        color: context.colorScheme.error,
                      ),
                      tooltip: context.messages.deleteButton,
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
            )
          : null,
    );
  }

  Widget _buildCreateBody(BuildContext context, {required String title}) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 30,
              color: Theme.of(context).colorScheme.outline,
            ),
            onPressed: () => getIt<NavService>().beamBack(),
          ),
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
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildEditBody(BuildContext context, {required String title}) {
    final templateId = widget.templateId!;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 30,
              color: Theme.of(context).colorScheme.outline,
            ),
            onPressed: () => getIt<NavService>().beamBack(),
          ),
          title: Text(
            title,
            style: appBarTextStyleNewLarge.copyWith(
              color: Theme.of(context).primaryColor,
            ),
          ),
          pinned: true,
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: context.messages.agentTemplateSettingsTab),
              Tab(text: context.messages.agentTemplateStatsTab),
              Tab(text: context.messages.agentTemplateReportsTab),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          // Settings tab
          _SettingsTabContent(
            formFields: _buildFormFields(context),
            templateId: templateId,
          ),
          // Stats tab
          _StatsTabContent(templateId: templateId),
          // Reports tab
          _ReportsTabContent(templateId: templateId),
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
        // Persist template-level fields (name, model).
        await templateService.updateTemplate(
          templateId: widget.templateId!,
          displayName: name,
          modelId: modelId,
        );

        // Create a new directive version.
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
          ..invalidate(agentTemplateProvider(widget.templateId!))
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
        SnackBar(content: Text(context.messages.commonError)),
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
              } on TemplateInUseException {
                if (!mounted || !pageContext.mounted) return;
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      pageContext.messages.agentTemplateDeleteHasInstances,
                    ),
                  ),
                );
              } catch (e, s) {
                developer.log(
                  'Delete failed',
                  name: 'AgentTemplateDetailPage',
                  error: e,
                  stackTrace: s,
                );
                if (!mounted || !pageContext.mounted) return;
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(pageContext.messages.commonError),
                  ),
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
///
/// Derives the "active" badge from the head pointer rather than from
/// each version's persisted status field, which can become stale.
class _VersionHistorySection extends ConsumerWidget {
  const _VersionHistorySection({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(templateVersionHistoryProvider(templateId));
    final activeVersionAsync =
        ref.watch(activeTemplateVersionProvider(templateId));
    final activeVersionId =
        activeVersionAsync.value?.mapOrNull(agentTemplateVersion: (v) => v.id);

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
              return Text(context.messages.agentTemplateNoVersions);
            }
            return Column(
              children: typed.map((version) {
                return _VersionTile(
                  version: version,
                  templateId: templateId,
                  isActive: version.id == activeVersionId,
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Text(context.messages.commonError),
        ),
      ],
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({
    required this.version,
    required this.templateId,
    required this.isActive,
  });

  final AgentTemplateVersionEntity version;
  final String templateId;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.colorScheme.surfaceContainerHigh,
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
                isActive
                    ? context.messages.agentTemplateStatusActive
                    : context.messages.agentTemplateStatusArchived,
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
              try {
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
              } catch (e, s) {
                developer.log(
                  'Rollback failed',
                  name: 'AgentTemplateDetailPage',
                  error: e,
                  stackTrace: s,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.messages.commonError),
                  ),
                );
              }
            },
            label: dialogContext.messages.agentTemplateRollbackAction,
          ),
        ],
      ),
    );
  }
}

/// Settings tab content — form fields, version history, evolve button.
class _SettingsTabContent extends StatelessWidget {
  const _SettingsTabContent({
    required this.formFields,
    required this.templateId,
  });

  final Widget formFields;
  final String templateId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        formFields,
        const SizedBox(height: 24),
        _VersionHistorySection(templateId: templateId),
        const SizedBox(height: 24),
        LottiSecondaryButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EvolutionChatPage(
                templateId: templateId,
              ),
            ),
          ),
          label: context.messages.agentTemplateEvolveAction,
          icon: Icons.auto_awesome,
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Stats tab content — aggregate token usage and per-instance breakdown.
class _StatsTabContent extends StatelessWidget {
  const _StatsTabContent({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TemplateTokenUsageSection(templateId: templateId),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Reports tab content — recent reports from all instances.
class _ReportsTabContent extends ConsumerWidget {
  const _ReportsTabContent({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(templateRecentReportsProvider(templateId));

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.messages.commonError,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.messages.agentTemplateReportsEmpty,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            if (report is! AgentReportEntity) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    formatAgentDateTime(report.createdAt),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AgentReportSection(content: report.content),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
