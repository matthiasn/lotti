import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/ui/widgets/inference_provider_model_picker_modal.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class AgentModelSheet {
  const AgentModelSheet._();

  static Future<void> show({
    required BuildContext context,
    required String taskId,
    required String agentId,
  }) {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.taskAgentSetupTitle,
      padding: EdgeInsets.zero,
      builder: (_) => _AgentModelSheetBody(taskId: taskId, agentId: agentId),
    );
  }
}

class _AgentModelSheetBody extends ConsumerStatefulWidget {
  const _AgentModelSheetBody({required this.taskId, required this.agentId});

  final String taskId;
  final String agentId;

  @override
  ConsumerState<_AgentModelSheetBody> createState() =>
      _AgentModelSheetBodyState();
}

class _AgentModelSheetBodyState extends ConsumerState<_AgentModelSheetBody> {
  bool _busy = false;

  String _originLabel(BuildContext context, ResolvedAgentSetup? setup) {
    if (setup?.status == AgentSetupResolutionStatus.disabled) {
      return context.messages.taskAgentSetupOriginDisabled;
    }
    return switch (setup?.setupOrigin) {
      AgentInferenceSetupOrigin.user =>
        context.messages.taskAgentSetupOriginUser,
      AgentInferenceSetupOrigin.categorySnapshot =>
        context.messages.taskAgentSetupOriginCategory,
      AgentInferenceSetupOrigin.templateSnapshot =>
        context.messages.taskAgentSetupOriginTemplate,
      AgentInferenceSetupOrigin.unknown ||
      null => context.messages.taskAgentSetupOriginLegacy,
    };
  }

  Future<void> _persist(
    Future<void> Function() action, {
    String? modelName,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref
        ..invalidate(agentIdentityProvider(widget.agentId))
        ..invalidate(taskAgentResolvedSetupProvider(widget.agentId));
      if (modelName == null) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.taskAgentSetupChangedToast(modelName),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Task-agent setup update failed',
        name: 'AgentModelSheet',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.commonError,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useCategoryDefault(TaskAgentSetupOptions options) async {
    final journalDb = ref.read(journalDbProvider);
    final entity = await journalDb.journalEntityById(widget.taskId);
    final categoryId = entity is Task ? entity.categoryId : null;
    final category = categoryId == null
        ? null
        : await journalDb.getCategoryById(categoryId);
    final profileId = category?.defaultProfileId;
    final profile = options.profiles
        .where((value) => value.id == profileId)
        .firstOrNull;
    final model = profile == null
        ? null
        : options.models
              .where((value) => value.id == profile.thinkingModelId)
              .firstOrNull;
    await _persist(
      () => ref
          .read(taskAgentServiceProvider)
          .updateAgentInferenceSetup(
            agentId: widget.agentId,
            setup: AgentInferenceSetup(
              mode: profileId == null
                  ? AgentInferenceSetupMode.disabled
                  : AgentInferenceSetupMode.configured,
              origin: AgentInferenceSetupOrigin.categorySnapshot,
              baseProfileId: profileId,
              originEntityId: categoryId,
            ),
          ),
      modelName: model?.name,
    );
  }

  Future<void> _chooseProfile(
    AiConfigInferenceProfile profile,
    TaskAgentSetupOptions options,
  ) async {
    final model = options.models
        .where((value) => value.id == profile.thinkingModelId)
        .firstOrNull;
    await _persist(
      () => ref
          .read(taskAgentServiceProvider)
          .updateAgentProfile(agentId: widget.agentId, profileId: profile.id),
      modelName: model?.name ?? profile.thinkingModelId,
    );
  }

  String _profileRoute(
    BuildContext context,
    AiConfigInferenceProfile profile,
    TaskAgentSetupOptions options,
  ) {
    final model = options.models
        .where((value) => value.id == profile.thinkingModelId)
        .firstOrNull;
    if (model == null) return context.messages.taskAgentSetupBroken;
    final provider = options.providers
        .where((value) => value.id == model.inferenceProviderId)
        .firstOrNull;
    if (provider == null) return context.messages.taskAgentSetupBroken;
    return formatInferenceRouteIdentity(
      InferenceRouteSnapshot(
        modelConfigId: model.id,
        providerModelId: model.providerModelId,
        modelName: model.name,
        publisherName: model.publisher,
        servingProviderConfigId: provider.id,
        servingProviderType: provider.inferenceProviderType,
        servingProviderName: provider.name,
        runtimeSettings: const {},
      ),
    );
  }

  Future<void> _chooseModel(
    AgentConfig config,
    TaskAgentSetupOptions options,
  ) async {
    final profileId = config.inferenceSetup?.baseProfileId;
    final profile = options.profiles
        .where((value) => value.id == profileId)
        .firstOrNull;
    final selectedId = await InferenceProviderModelPickerModal.show(
      context: context,
      defaultModelId: profile?.thinkingModelId,
      models: options.models,
      providers: options.providers,
      title: context.messages.taskAgentModelPickerTitle,
      defaultBadgeLabel: context.messages.taskAgentProfileDefaultBadge,
    );
    if (selectedId == null || !mounted) return;
    final model = options.models
        .where((value) => value.id == selectedId)
        .firstOrNull;
    await _persist(
      () => ref
          .read(taskAgentServiceProvider)
          .updateAgentThinkingModelOverride(
            agentId: widget.agentId,
            modelConfigId: selectedId,
          ),
      modelName: model?.name ?? selectedId,
    );
  }

  Future<void> _disableSetup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.messages.taskAgentDisableConfirmTitle),
        content: Text(context.messages.taskAgentDisableConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.messages.taskAgentDisableConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _persist(
      () => ref
          .read(taskAgentServiceProvider)
          .updateAgentInferenceSetup(
            agentId: widget.agentId,
            setup: const AgentInferenceSetup(
              mode: AgentInferenceSetupMode.disabled,
              origin: AgentInferenceSetupOrigin.user,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final identity = ref
        .watch(agentIdentityProvider(widget.agentId))
        .value
        ?.mapOrNull(agent: (value) => value);
    final setup = ref
        .watch(taskAgentResolvedSetupProvider(widget.agentId))
        .value;
    final options = ref.watch(taskAgentSetupOptionsProvider).value;
    final currentRoute = setup?.profile == null
        ? null
        : formatInferenceRouteIdentity(
            InferenceRouteSnapshot.fromResolvedProfile(setup!.profile!),
          );
    final config = identity?.config;
    final currentProfile = options?.profiles
        .where(
          (profile) => profile.id == config?.inferenceSetup?.baseProfileId,
        )
        .firstOrNull;
    final currentProfileContext = currentProfile == null
        ? null
        : '${currentProfile.name} · '
              '${config?.inferenceSetup?.thinkingModelOverrideId == null ? context.messages.taskAgentProfileDefaultBadge : context.messages.taskAgentDirectModelOverride}';
    final effectiveAutomaticUpdates =
        config?.automaticUpdatesEnabledEffective ?? false;
    final profiles =
        options?.profiles
            .where((profile) => isDesktop || !profile.desktopOnly)
            .toList() ??
        const <AiConfigInferenceProfile>[];

    return AbsorbPointer(
      absorbing: _busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step4,
          tokens.spacing.step5,
          tokens.spacing.step7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.messages.taskAgentCurrentSetupLabel,
              style: tokens.typography.styles.subtitle.subtitle2,
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              currentRoute ??
                  (setup?.status == AgentSetupResolutionStatus.disabled
                      ? context.messages.taskAgentNoProfileSelected
                      : context.messages.taskAgentSetupBroken),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: currentRoute == null
                    ? tokens.colors.alert.error.defaultColor
                    : tokens.colors.text.highEmphasis,
              ),
            ),
            if (currentProfileContext != null) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                currentProfileContext,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.step2),
            Text(
              _originLabel(context, setup),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step5),
            DesignSystemListItem(
              title: context.messages.taskAgentUseCategoryDefault,
              subtitle: context.messages.taskAgentUseCategoryDefaultDescription,
              subtitleMaxLines: null,
              leading: const Icon(Icons.category_outlined),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: options == null
                  ? null
                  : () => _useCategoryDefault(options),
              showDivider: true,
            ),
            if (profiles.isEmpty)
              DesignSystemListItem(
                title: context.messages.taskAgentNoProfilesAvailable,
                leading: const Icon(Icons.account_tree_outlined),
              )
            else if (options != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step4,
                  vertical: tokens.spacing.step2,
                ),
                child: Text(
                  context.messages.taskAgentChooseProfile,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              for (final profile in profiles)
                DesignSystemListItem(
                  title: profile.name,
                  subtitle: _profileRoute(context, profile, options),
                  subtitleMaxLines: null,
                  leading: const Icon(Icons.account_tree_outlined),
                  trailing: config?.inferenceSetup?.baseProfileId == profile.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => _chooseProfile(profile, options),
                  showDivider: true,
                ),
            ],
            DesignSystemListItem(
              title: context.messages.taskAgentChooseModel,
              subtitle: options != null && options.models.isEmpty
                  ? context.messages.taskAgentNoModelsAvailable
                  : null,
              leading: const Icon(Icons.psychology_outlined),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: config == null || options == null || options.models.isEmpty
                  ? null
                  : () => _chooseModel(config, options),
              showDivider: true,
            ),
            if (config?.inferenceSetup?.thinkingModelOverrideId != null)
              DesignSystemListItem(
                title: context.messages.taskAgentUseProfileDefault,
                leading: const Icon(Icons.undo_rounded),
                onTap: () => _persist(
                  () => ref
                      .read(taskAgentServiceProvider)
                      .updateAgentThinkingModelOverride(
                        agentId: widget.agentId,
                        modelConfigId: null,
                      ),
                ),
                showDivider: true,
              ),
            DesignSystemListItem(
              title: context.messages.taskAgentNoAiSetup,
              subtitle: context.messages.taskAgentNoAiSetupDescription,
              subtitleMaxLines: null,
              leading: const Icon(Icons.pause_circle_outline_rounded),
              onTap: _disableSetup,
              showDivider: true,
            ),
            SizedBox(height: tokens.spacing.step5),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: SizedBox(
                width: double.infinity,
                child: DesignSystemCheckbox(
                  key: const Key('taskAgentAutomaticUpdatesCheckbox'),
                  value: effectiveAutomaticUpdates,
                  label: context.messages.taskAgentAutomaticUpdatesLabel,
                  labelMaxLines: null,
                  onChanged:
                      config?.inferenceSetup?.mode ==
                          AgentInferenceSetupMode.disabled
                      ? null
                      : (value) => _persist(
                          () => ref
                              .read(taskAgentServiceProvider)
                              .updateAutomaticUpdates(
                                agentId: widget.agentId,
                                enabled: value ?? false,
                              ),
                        ),
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              config?.inferenceSetup?.mode == AgentInferenceSetupMode.disabled
                  ? context.messages.taskAgentAutomaticUpdatesNeedsSetup
                  : effectiveAutomaticUpdates
                  ? context.messages.taskAgentAutomaticUpdatesOnDescription
                  : context.messages.taskAgentAutomaticUpdatesOffDescription,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              context.messages.taskAgentSetupPersistenceDescription,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
