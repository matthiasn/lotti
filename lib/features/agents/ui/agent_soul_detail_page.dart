import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/form/lotti_text_field.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

/// Detail page for creating or editing a soul document.
///
/// - **Create mode** (`soulId == null`): form for name + 4 directives.
/// - **Edit mode** (`soulId != null`): tabbed layout with Settings and Info
///   tabs. Settings contains the editable form; Info shows version history
///   and assigned templates.
class AgentSoulDetailPage extends ConsumerStatefulWidget {
  const AgentSoulDetailPage({
    this.soulId,
    super.key,
  });

  final String? soulId;

  bool get isCreateMode => soulId == null;

  @override
  ConsumerState<AgentSoulDetailPage> createState() =>
      _AgentSoulDetailPageState();
}

class _AgentSoulDetailPageState extends ConsumerState<AgentSoulDetailPage>
    with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _voiceDirectiveController;
  late TextEditingController _toneBoundsController;
  late TextEditingController _coachingStyleController;
  late TextEditingController _antiSycophancyController;
  bool _didSeedControllers = false;
  String? _seededVersionId;
  bool _isSaving = false;
  TabController? _tabController;

  // Original values for dirty-state tracking.
  String _originalName = '';
  String _originalVoiceDirective = '';
  String _originalToneBounds = '';
  String _originalCoachingStyle = '';
  String _originalAntiSycophancy = '';

  bool get _isDirty =>
      _nameController.text != _originalName ||
      _voiceDirectiveController.text != _originalVoiceDirective ||
      _toneBoundsController.text != _originalToneBounds ||
      _coachingStyleController.text != _originalCoachingStyle ||
      _antiSycophancyController.text != _originalAntiSycophancy;

  static const _tabCount = 2;

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _voiceDirectiveController = TextEditingController();
    _toneBoundsController = TextEditingController();
    _coachingStyleController = TextEditingController();
    _antiSycophancyController = TextEditingController();
    if (!widget.isCreateMode) {
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
    _voiceDirectiveController.dispose();
    _toneBoundsController.dispose();
    _coachingStyleController.dispose();
    _antiSycophancyController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCreateMode) {
      return _buildScaffold(context, soul: null, activeVersion: null);
    }

    final soulAsync = ref.watch(soulDocumentProvider(widget.soulId!));
    final activeVersionAsync = ref.watch(
      activeSoulVersionProvider(widget.soulId!),
    );

    final soul = soulAsync.value?.mapOrNull(soulDocument: (e) => e);
    final activeVersion = activeVersionAsync.value?.mapOrNull(
      soulDocumentVersion: (v) => v,
    );

    if (soulAsync.isLoading && soul == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (soulAsync.hasError && soul == null) {
      return Scaffold(
        appBar: AppBar(leading: agentBackButton(context)),
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

    if (soul == null) {
      return Scaffold(
        appBar: AppBar(leading: agentBackButton(context)),
        body: Center(
          child: Text(context.messages.agentSoulNotFound),
        ),
      );
    }

    // Seed controllers from loaded data. Re-seed when the active version
    // changes (e.g. after a rollback or evolution proposal approval).
    if (!_didSeedControllers) {
      _nameController.text = soul.displayName;
      if (activeVersion != null) {
        _voiceDirectiveController.text = activeVersion.voiceDirective;
        _toneBoundsController.text = activeVersion.toneBounds;
        _coachingStyleController.text = activeVersion.coachingStyle;
        _antiSycophancyController.text = activeVersion.antiSycophancyPolicy;
        _seededVersionId = activeVersion.id;
      }
      _snapshotOriginals();
      _didSeedControllers = true;
    } else if (activeVersion != null && activeVersion.id != _seededVersionId) {
      _nameController.text = soul.displayName;
      _voiceDirectiveController.text = activeVersion.voiceDirective;
      _toneBoundsController.text = activeVersion.toneBounds;
      _coachingStyleController.text = activeVersion.coachingStyle;
      _antiSycophancyController.text = activeVersion.antiSycophancyPolicy;
      _seededVersionId = activeVersion.id;
      _snapshotOriginals();
    }

    return _buildScaffold(context, soul: soul, activeVersion: activeVersion);
  }

  void _snapshotOriginals() {
    _originalName = _nameController.text;
    _originalVoiceDirective = _voiceDirectiveController.text;
    _originalToneBounds = _toneBoundsController.text;
    _originalCoachingStyle = _coachingStyleController.text;
    _originalAntiSycophancy = _antiSycophancyController.text;
  }

  Widget _buildScaffold(
    BuildContext context, {
    required SoulDocumentEntity? soul,
    required SoulDocumentVersionEntity? activeVersion,
  }) {
    final title = widget.isCreateMode
        ? context.messages.agentSoulCreateTitle
        : context.messages.agentSoulDetailTitle;

    final saveEnabled =
        !_isSaving &&
        _nameController.text.trim().isNotEmpty &&
        _voiceDirectiveController.text.trim().isNotEmpty;

    final showBottomBar = widget.isCreateMode || _currentTabIndex == 0;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: widget.isCreateMode
          ? _buildCreateBody(context, title: title)
          : _buildEditBody(context, title: title),
      bottomNavigationBar: showBottomBar
          ? FormBottomBar(
              rightButtons: widget.isCreateMode
                  ? [
                      LottiSecondaryButton(
                        onPressed: () => navigateBackFromAgent(context),
                        label: context.messages.cancelButton,
                      ),
                      LottiPrimaryButton(
                        onPressed: saveEnabled
                            ? () => _handleSave(context)
                            : null,
                        label: context.messages.createButton,
                      ),
                    ]
                  : _isDirty
                  ? [
                      LottiSecondaryButton(
                        onPressed: () => navigateBackFromAgent(context),
                        label: context.messages.cancelButton,
                      ),
                      LottiPrimaryButton(
                        onPressed: saveEnabled
                            ? () => _handleSave(context)
                            : null,
                        label: context.messages.agentTemplateSaveNewVersion,
                      ),
                    ]
                  : [],
            )
          : null,
    );
  }

  Widget _buildCreateBody(BuildContext context, {required String title}) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          leading: agentBackButton(context),
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
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          leading: agentBackButton(context),
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
              Tab(text: context.messages.agentSoulSettingsTab),
              Tab(text: context.messages.agentSoulInfoTab),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          // Settings tab
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFormFields(context),
              const SizedBox(height: 16),
            ],
          ),
          // Info tab
          _InfoTabContent(
            soulId: widget.soulId!,
            onDelete: () => _handleDelete(context),
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
          labelText: context.messages.agentSoulDisplayNameLabel,
          autofocus: widget.isCreateMode,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        LottiTextArea(
          controller: _voiceDirectiveController,
          labelText: context.messages.agentSoulVoiceDirectiveLabel,
          minLines: 4,
          maxLines: null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        LottiTextArea(
          controller: _toneBoundsController,
          labelText: context.messages.agentSoulToneBoundsLabel,
          maxLines: null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        LottiTextArea(
          controller: _coachingStyleController,
          labelText: context.messages.agentSoulCoachingStyleLabel,
          maxLines: null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        LottiTextArea(
          controller: _antiSycophancyController,
          labelText: context.messages.agentSoulAntiSycophancyLabel,
          maxLines: null,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    setState(() => _isSaving = true);

    try {
      final soulService = ref.read(soulDocumentServiceProvider);
      final name = _nameController.text.trim();
      final voice = _voiceDirectiveController.text.trim();
      final tone = _toneBoundsController.text.trim();
      final coaching = _coachingStyleController.text.trim();
      final antiSycophancy = _antiSycophancyController.text.trim();

      if (widget.isCreateMode) {
        await soulService.createSoul(
          displayName: name,
          voiceDirective: voice,
          toneBounds: tone,
          coachingStyle: coaching,
          antiSycophancyPolicy: antiSycophancy,
          authoredBy: 'user',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentSoulCreatedSuccess),
          ),
        );
        ref.invalidate(allSoulDocumentsProvider);
        Navigator.of(context).pop();
      } else {
        await soulService.updateSoulAndCreateVersion(
          soulId: widget.soulId!,
          displayName: name,
          voiceDirective: voice,
          toneBounds: tone,
          coachingStyle: coaching,
          antiSycophancyPolicy: antiSycophancy,
          authoredBy: 'user',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentSoulVersionSaved),
          ),
        );
        _snapshotOriginals();
        ref.invalidate(allSoulDocumentsProvider);
      }
    } catch (e, s) {
      developer.log(
        'Failed to save soul',
        name: 'AgentSoulDetailPage',
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
        title: Text(dialogContext.messages.agentSoulDeleteConfirmTitle),
        content: Text(dialogContext.messages.agentSoulDeleteConfirmBody),
        actions: [
          LottiTertiaryButton(
            onPressed: () => Navigator.pop(dialogContext),
            label: dialogContext.messages.cancelButton,
          ),
          LottiTertiaryButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final soulService = ref.read(soulDocumentServiceProvider);
                await soulService.deleteSoul(widget.soulId!);
                if (!mounted || !pageContext.mounted) return;
                ref.invalidate(allSoulDocumentsProvider);
                Navigator.of(pageContext).pop();
              } catch (e, s) {
                developer.log(
                  'Delete failed',
                  name: 'AgentSoulDetailPage',
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

/// Info tab: version history + assigned templates + delete action.
class _InfoTabContent extends ConsumerWidget {
  const _InfoTabContent({
    required this.soulId,
    required this.onDelete,
  });

  final String soulId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _VersionHistorySection(soulId: soulId),
        const SizedBox(height: 24),
        _AssignedTemplatesSection(soulId: soulId),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: context.colorScheme.error,
            ),
            label: Text(
              context.messages.deleteButton,
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _VersionHistorySection extends ConsumerWidget {
  const _VersionHistorySection({required this.soulId});

  final String soulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(soulVersionHistoryProvider(soulId));
    final activeVersionAsync = ref.watch(activeSoulVersionProvider(soulId));
    final activeVersionId = activeVersionAsync.value?.mapOrNull(
      soulDocumentVersion: (v) => v.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentSoulVersionHistoryTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        historyAsync.when(
          data: (versions) {
            final typed = versions
                .whereType<SoulDocumentVersionEntity>()
                .toList();
            if (typed.isEmpty) {
              return Text(context.messages.agentTemplateNoVersions);
            }
            return Column(
              children: typed.map((version) {
                return _VersionTile(
                  version: version,
                  soulId: soulId,
                  isActive: version.id == activeVersionId,
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(context.messages.commonError),
        ),
      ],
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({
    required this.version,
    required this.soulId,
    required this.isActive,
  });

  final SoulDocumentVersionEntity version;
  final String soulId;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: ListTile(
        title: Text(
          context.messages.agentSoulVersionLabel(version.version),
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
                tooltip: context.messages.agentSoulRollbackAction,
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
        title: Text(dialogContext.messages.agentSoulRollbackAction),
        content: Text(
          dialogContext.messages.agentSoulRollbackConfirm(version.version),
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
                final soulService = ref.read(soulDocumentServiceProvider);
                await soulService.rollbackToVersion(
                  soulId: soulId,
                  versionId: version.id,
                );
              } catch (e, s) {
                developer.log(
                  'Rollback failed',
                  name: 'AgentSoulDetailPage',
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
            label: dialogContext.messages.agentSoulRollbackAction,
          ),
        ],
      ),
    );
  }
}

class _AssignedTemplatesSection extends ConsumerWidget {
  const _AssignedTemplatesSection({required this.soulId});

  final String soulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateIdsAsync = ref.watch(templatesUsingSoulProvider(soulId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentSoulAssignedTemplatesTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        templateIdsAsync.when(
          data: (templateIds) {
            if (templateIds.isEmpty) {
              return Text(
                context.messages.agentTemplateNoneAssigned,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: templateIds.map((templateId) {
                return _AssignedTemplateTile(templateId: templateId);
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(context.messages.commonError),
        ),
      ],
    );
  }
}

class _AssignedTemplateTile extends ConsumerWidget {
  const _AssignedTemplateTile({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateAsync = ref.watch(agentTemplateProvider(templateId));

    final displayName =
        templateAsync.value?.mapOrNull(
          agentTemplate: (t) => t.displayName,
        ) ??
        templateId;

    return Card(
      color: context.colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: ListTile(
        leading: Icon(
          Icons.smart_toy_outlined,
          size: 20,
          color: context.colorScheme.onSurfaceVariant,
        ),
        title: Text(displayName),
      ),
    );
  }
}
