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
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/widgets/inference_provider_model_picker_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Adaptive task-agent setup flow presented as one multi-page Wolt route.
class AgentModelSheet {
  const AgentModelSheet._();

  static Future<void> show({
    required BuildContext context,
    required String taskId,
    required String agentId,
  }) {
    final pageIndex = ValueNotifier<int>(0);
    final selectedProviderId = ValueNotifier<String?>(null);
    final modelBackPage = ValueNotifier<int>(0);
    final controller = _AgentSetupFlowController(
      container: ProviderScope.containerOf(context),
      taskId: taskId,
      agentId: agentId,
      taskMessenger: ScaffoldMessenger.of(context),
    );

    return ModalUtils.showMultiPageModal<void>(
      context: context,
      pageIndexNotifier: pageIndex,
      pageListBuilder: (modalContext) => [
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.taskAgentSetupTitle,
          showCloseButton: true,
          padding: EdgeInsets.zero,
          child: _AgentSetupOverviewPage(
            agentId: agentId,
            controller: controller,
            onChooseProfile: () => pageIndex.value = 1,
            onChooseModel: (options) {
              final providerIds = _providerIdsForModels(options);
              if (providerIds.length == 1) {
                selectedProviderId.value = providerIds.single;
                modelBackPage.value = 0;
                pageIndex.value = 3;
              } else {
                modelBackPage.value = 2;
                pageIndex.value = 2;
              }
            },
          ),
        ),
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.taskAgentChooseProfile,
          showCloseButton: true,
          padding: EdgeInsets.zero,
          onTapBack: () => pageIndex.value = 0,
          child: _AgentProfilePage(
            agentId: agentId,
            controller: controller,
          ),
        ),
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.taskAgentModelPickerTitle,
          showCloseButton: true,
          padding: EdgeInsets.zero,
          onTapBack: () => pageIndex.value = 0,
          child: _AgentProviderPage(
            controller: controller,
            onProviderSelected: (providerId) {
              selectedProviderId.value = providerId;
              modelBackPage.value = 2;
              pageIndex.value = 3;
            },
          ),
        ),
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.taskAgentModelPickerTitle,
          showCloseButton: true,
          padding: EdgeInsets.zero,
          onTapBack: () => pageIndex.value = modelBackPage.value,
          child: _AgentModelPage(
            agentId: agentId,
            controller: controller,
            selectedProviderId: selectedProviderId,
          ),
        ),
      ],
    );
  }
}

List<String> _providerIdsForModels(TaskAgentSetupOptions options) {
  final configuredProviderIds = options.providers
      .map((value) => value.id)
      .toSet();
  final ids = <String>[];
  for (final model in options.models) {
    if (configuredProviderIds.contains(model.inferenceProviderId) &&
        !ids.contains(model.inferenceProviderId)) {
      ids.add(model.inferenceProviderId);
    }
  }
  if (ids.isNotEmpty) return ids;
  return options.models
      .map((model) => model.inferenceProviderId)
      .toSet()
      .toList();
}

class _AgentSetupFlowController {
  _AgentSetupFlowController({
    required this.container,
    required this.taskId,
    required this.agentId,
    required this.taskMessenger,
  });

  final ProviderContainer container;
  final String taskId;
  final String agentId;
  final ScaffoldMessengerState taskMessenger;
  final busy = ValueNotifier<bool>(false);
  final confirmDisable = ValueNotifier<bool>(false);

  Future<bool> _persist(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await action();
      if (!context.mounted) return false;
      container
        ..invalidate(agentIdentityProvider(agentId))
        ..invalidate(taskAgentResolvedSetupProvider(agentId));
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Task-agent setup update failed',
        name: 'AgentModelSheet',
        error: error,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> _persistTerminalChoice(
    BuildContext context,
    Future<void> Function() action, {
    required String successTitle,
  }) async {
    final persisted = await _persist(context, action);
    if (!persisted || !context.mounted) return;
    Navigator.of(context).pop();
    if (taskMessenger.mounted) {
      taskMessenger.showDesignSystemToast(
        tone: DesignSystemToastTone.success,
        title: successTitle,
      );
    }
  }

  Future<void> useCategoryDefault(
    BuildContext context,
    TaskAgentSetupOptions options,
  ) async {
    final messages = context.messages;
    final journalDb = container.read(journalDbProvider);
    final entity = await journalDb.journalEntityById(taskId);
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
    if (!context.mounted) return;
    Future<void> action() => container
        .read(taskAgentServiceProvider)
        .updateAgentInferenceSetup(
          agentId: agentId,
          setup: AgentInferenceSetup(
            mode: profileId == null
                ? AgentInferenceSetupMode.disabled
                : AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.categorySnapshot,
            baseProfileId: profileId,
            originEntityId: categoryId,
          ),
        );

    if (profile == null || model == null) {
      final persisted = await _persist(context, action);
      if (persisted && context.mounted) Navigator.of(context).pop();
      return;
    }
    await _persistTerminalChoice(
      context,
      action,
      successTitle: messages.taskAgentProfileChangedToast(profile.name),
    );
  }

  Future<void> chooseProfile(
    BuildContext context,
    AiConfigInferenceProfile profile,
  ) => _persistTerminalChoice(
    context,
    () => container
        .read(taskAgentServiceProvider)
        .updateAgentProfile(agentId: agentId, profileId: profile.id),
    successTitle: context.messages.taskAgentProfileChangedToast(profile.name),
  );

  Future<void> chooseModel(
    BuildContext context,
    String modelId,
    TaskAgentSetupOptions options,
  ) {
    final model = options.models
        .where((value) => value.id == modelId)
        .firstOrNull;
    return _persistTerminalChoice(
      context,
      () => container
          .read(taskAgentServiceProvider)
          .updateAgentThinkingModelOverride(
            agentId: agentId,
            modelConfigId: modelId,
          ),
      successTitle: context.messages.taskAgentSetupChangedToast(
        model?.name ?? modelId,
      ),
    );
  }

  Future<void> clearOverride(BuildContext context) => _persist(
    context,
    () => container
        .read(taskAgentServiceProvider)
        .updateAgentThinkingModelOverride(
          agentId: agentId,
          modelConfigId: null,
        ),
  );

  Future<void> updateAutomaticUpdates(
    BuildContext context, {
    required bool enabled,
  }) => _persist(
    context,
    () => container
        .read(taskAgentServiceProvider)
        .updateAutomaticUpdates(agentId: agentId, enabled: enabled),
  );

  Future<void> disable(BuildContext context) async {
    final persisted = await _persist(
      context,
      () => container
          .read(taskAgentServiceProvider)
          .updateAgentInferenceSetup(
            agentId: agentId,
            setup: const AgentInferenceSetup(
              mode: AgentInferenceSetupMode.disabled,
              origin: AgentInferenceSetupOrigin.user,
            ),
          ),
    );
    if (persisted && context.mounted) Navigator.of(context).pop();
  }
}

class _AgentBusyGuard extends StatelessWidget {
  const _AgentBusyGuard({required this.controller, required this.child});

  final _AgentSetupFlowController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.busy,
      builder: (context, busy, child) => AbsorbPointer(
        absorbing: busy,
        child: child,
      ),
      child: child,
    );
  }
}

class _AgentSetupOverviewPage extends ConsumerWidget {
  const _AgentSetupOverviewPage({
    required this.agentId,
    required this.controller,
    required this.onChooseProfile,
    required this.onChooseModel,
  });

  final String agentId;
  final _AgentSetupFlowController controller;
  final VoidCallback onChooseProfile;
  final ValueChanged<TaskAgentSetupOptions> onChooseModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final identity = ref
        .watch(agentIdentityProvider(agentId))
        .value
        ?.mapOrNull(agent: (value) => value);
    final setup = ref.watch(taskAgentResolvedSetupProvider(agentId)).value;
    final options = ref.watch(taskAgentSetupOptionsProvider).value;
    final config = identity?.config;
    final currentRoute = setup?.profile == null
        ? null
        : formatInferenceRouteIdentity(
            InferenceRouteSnapshot.fromResolvedProfile(setup!.profile!),
            viaLabel: context.messages.taskAgentRouteVia,
          );
    final currentProfile = options?.profiles
        .where(
          (profile) => profile.id == config?.inferenceSetup?.baseProfileId,
        )
        .firstOrNull;
    final profileContext = currentProfile == null
        ? null
        : '${currentProfile.name} · '
              '${config?.inferenceSetup?.thinkingModelOverrideId == null ? context.messages.taskAgentProfileDefaultBadge : context.messages.taskAgentDirectModelOverride}';
    final automaticUpdates = config?.automaticUpdatesEnabledEffective ?? false;

    return _AgentBusyGuard(
      controller: controller,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step4,
                tokens.spacing.step5,
                tokens.spacing.step5,
              ),
              child: Column(
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
                  if (profileContext != null) ...[
                    SizedBox(height: tokens.spacing.step2),
                    Text(
                      profileContext,
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
                ],
              ),
            ),
            DesignSystemSelectionRow(
              key: const ValueKey('agent-choose-profile'),
              title: context.messages.taskAgentChooseProfile,
              subtitle: currentProfile?.name,
              type: DesignSystemSelectionRowType.navigation,
              leading: Icon(
                Icons.account_tree_outlined,
                color: tokens.colors.text.mediumEmphasis,
                size: tokens.spacing.step6,
              ),
              onTap: options == null ? null : onChooseProfile,
            ),
            DesignSystemSelectionRow(
              key: const ValueKey('agent-choose-model'),
              title: context.messages.taskAgentChooseModel,
              subtitle: options != null && options.models.isEmpty
                  ? context.messages.taskAgentNoModelsAvailable
                  : null,
              type: DesignSystemSelectionRowType.navigation,
              leading: Icon(
                Icons.psychology_outlined,
                color: tokens.colors.text.mediumEmphasis,
                size: tokens.spacing.step6,
              ),
              onTap: config == null || options == null || options.models.isEmpty
                  ? null
                  : () => onChooseModel(options),
            ),
            if (config?.inferenceSetup?.thinkingModelOverrideId != null)
              DesignSystemSelectionRow(
                key: const ValueKey('agent-clear-override'),
                title: context.messages.taskAgentUseProfileDefault,
                type: DesignSystemSelectionRowType.action,
                leading: Icon(
                  Icons.undo_rounded,
                  color: tokens.colors.text.mediumEmphasis,
                  size: tokens.spacing.step6,
                ),
                onTap: () => controller.clearOverride(context),
              ),
            DesignSystemSelectionRow(
              key: const ValueKey('agent-disable'),
              title: context.messages.taskAgentNoAiSetup,
              subtitle: context.messages.taskAgentNoAiSetupDescription,
              type: DesignSystemSelectionRowType.action,
              leading: Icon(
                Icons.pause_circle_outline_rounded,
                color: tokens.colors.text.mediumEmphasis,
                size: tokens.spacing.step6,
              ),
              onTap: () => controller.confirmDisable.value = true,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: controller.confirmDisable,
              builder: (context, visible, _) {
                if (!visible) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step5,
                    tokens.spacing.step4,
                    tokens.spacing.step5,
                    tokens.spacing.step5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.messages.taskAgentDisableConfirmTitle,
                        style: tokens.typography.styles.subtitle.subtitle2,
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        context.messages.taskAgentDisableConfirmBody,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.mediumEmphasis,
                            ),
                      ),
                      SizedBox(height: tokens.spacing.step4),
                      Row(
                        children: [
                          Expanded(
                            child: DesignSystemButton(
                              label: MaterialLocalizations.of(
                                context,
                              ).cancelButtonLabel,
                              variant: DesignSystemButtonVariant.secondary,
                              size: DesignSystemButtonSize.medium,
                              fullWidth: true,
                              onPressed: () =>
                                  controller.confirmDisable.value = false,
                            ),
                          ),
                          SizedBox(width: tokens.spacing.step3),
                          Expanded(
                            child: DesignSystemButton(
                              label: context
                                  .messages
                                  .taskAgentDisableConfirmAction,
                              variant: DesignSystemButtonVariant.danger,
                              size: DesignSystemButtonSize.medium,
                              fullWidth: true,
                              onPressed: () => controller.disable(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: tokens.spacing.step9,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: DesignSystemCheckbox(
                        key: const Key('taskAgentAutomaticUpdatesCheckbox'),
                        value: automaticUpdates,
                        label: context.messages.taskAgentAutomaticUpdatesLabel,
                        labelMaxLines: null,
                        onChanged:
                            config?.inferenceSetup?.mode ==
                                AgentInferenceSetupMode.disabled
                            ? null
                            : (value) => controller.updateAutomaticUpdates(
                                context,
                                enabled: value ?? false,
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    config?.inferenceSetup?.mode ==
                            AgentInferenceSetupMode.disabled
                        ? context.messages.taskAgentAutomaticUpdatesNeedsSetup
                        : automaticUpdates
                        ? context
                              .messages
                              .taskAgentAutomaticUpdatesOnDescription
                        : context
                              .messages
                              .taskAgentAutomaticUpdatesOffDescription,
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
          ],
        ),
      ),
    );
  }
}

class _AgentProfilePage extends ConsumerWidget {
  const _AgentProfilePage({
    required this.agentId,
    required this.controller,
  });

  final String agentId;
  final _AgentSetupFlowController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final options = ref.watch(taskAgentSetupOptionsProvider).value;
    final config = ref
        .watch(agentIdentityProvider(agentId))
        .value
        ?.mapOrNull(agent: (value) => value)
        ?.config;
    final profiles =
        options?.profiles
            .where((profile) => isDesktop || !profile.desktopOnly)
            .toList() ??
        const <AiConfigInferenceProfile>[];

    return _AgentBusyGuard(
      controller: controller,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesignSystemSelectionRow(
              title: context.messages.taskAgentUseCategoryDefault,
              subtitle: context.messages.taskAgentUseCategoryDefaultDescription,
              subtitleMaxLines: null,
              type: DesignSystemSelectionRowType.action,
              leading: Icon(
                Icons.category_outlined,
                color: tokens.colors.text.mediumEmphasis,
                size: tokens.spacing.step6,
              ),
              onTap: options == null
                  ? null
                  : () => controller.useCategoryDefault(context, options),
            ),
            if (profiles.isEmpty)
              DesignSystemSelectionRow(
                title: context.messages.taskAgentNoProfilesAvailable,
                type: DesignSystemSelectionRowType.action,
                leading: Icon(
                  Icons.account_tree_outlined,
                  color: tokens.colors.text.mediumEmphasis,
                  size: tokens.spacing.step6,
                ),
                onTap: null,
              )
            else if (options != null)
              for (final profile in profiles)
                DesignSystemSelectionRow(
                  key: ValueKey('agent-profile-${profile.id}'),
                  title: profile.name,
                  subtitle: _profileRoute(context, profile, options),
                  subtitleMaxLines: null,
                  type: DesignSystemSelectionRowType.singleSelect,
                  selected: config?.inferenceSetup?.baseProfileId == profile.id,
                  leading: Icon(
                    Icons.account_tree_outlined,
                    color: tokens.colors.text.mediumEmphasis,
                    size: tokens.spacing.step6,
                  ),
                  onTap: () => controller.chooseProfile(context, profile),
                ),
          ],
        ),
      ),
    );
  }
}

class _AgentProviderPage extends ConsumerWidget {
  const _AgentProviderPage({
    required this.controller,
    required this.onProviderSelected,
  });

  final _AgentSetupFlowController controller;
  final ValueChanged<String> onProviderSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final options = ref.watch(taskAgentSetupOptionsProvider).value;
    if (options == null) return const SizedBox.shrink();
    final providerIds = _providerIdsForModels(options);

    return _AgentBusyGuard(
      controller: controller,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final providerId in providerIds)
              Builder(
                builder: (context) {
                  final provider = options.providers
                      .where((value) => value.id == providerId)
                      .firstOrNull;
                  final modelCount = options.models
                      .where(
                        (model) => model.inferenceProviderId == providerId,
                      )
                      .length;
                  final type = provider?.inferenceProviderType;
                  return DesignSystemSelectionRow(
                    key: ValueKey('agent-provider-$providerId'),
                    title: aiProviderDisplayName(
                      type: type,
                      messages: context.messages,
                    ),
                    subtitle: context.messages.aiModelPickerProviderModelCount(
                      modelCount,
                    ),
                    type: DesignSystemSelectionRowType.navigation,
                    leading: Icon(
                      aiProviderIcon(type),
                      color: aiProviderAccent(type: type, tokens: tokens),
                      size: tokens.spacing.step6,
                    ),
                    onTap: () => onProviderSelected(providerId),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AgentModelPage extends ConsumerWidget {
  const _AgentModelPage({
    required this.agentId,
    required this.controller,
    required this.selectedProviderId,
  });

  final String agentId;
  final _AgentSetupFlowController controller;
  final ValueNotifier<String?> selectedProviderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final options = ref.watch(taskAgentSetupOptionsProvider).value;
    final config = ref
        .watch(agentIdentityProvider(agentId))
        .value
        ?.mapOrNull(agent: (value) => value)
        ?.config;
    if (options == null) return const SizedBox.shrink();
    final profile = options.profiles
        .where(
          (value) => value.id == config?.inferenceSetup?.baseProfileId,
        )
        .firstOrNull;
    final defaultModelId = profile?.thinkingModelId;
    final selectedModelId =
        config?.inferenceSetup?.thinkingModelOverrideId ?? defaultModelId;

    return _AgentBusyGuard(
      controller: controller,
      child: ValueListenableBuilder<String?>(
        valueListenable: selectedProviderId,
        builder: (context, providerId, _) {
          if (providerId == null) return const SizedBox.shrink();
          final provider = options.providers
              .where((value) => value.id == providerId)
              .firstOrNull;
          final models =
              InferenceProviderModelPickerModal.orderModelsDefaultFirst(
                options.models
                    .where(
                      (model) => model.inferenceProviderId == providerId,
                    )
                    .toList(),
                defaultModelId,
              );
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final model in models)
                  DesignSystemSelectionRow(
                    key: ValueKey('agent-model-${model.id}'),
                    title: model.name,
                    subtitle: model.providerModelId.isEmpty
                        ? null
                        : model.providerModelId,
                    type: DesignSystemSelectionRowType.singleSelect,
                    selected: model.id == selectedModelId,
                    selectedLabel: model.id == defaultModelId
                        ? context.messages.taskAgentProfileDefaultBadge
                        : context.messages.designSystemSelectedLabel,
                    leading: Icon(
                      Icons.psychology_outlined,
                      color: aiProviderAccent(
                        type: provider?.inferenceProviderType,
                        tokens: tokens,
                      ),
                      size: tokens.spacing.step6,
                    ),
                    onTap: () => controller.chooseModel(
                      context,
                      model.id,
                      options,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _originLabel(BuildContext context, ResolvedAgentSetup? setup) {
  if (setup?.status == AgentSetupResolutionStatus.disabled) {
    return context.messages.taskAgentSetupOriginDisabled;
  }
  return switch (setup?.setupOrigin) {
    AgentInferenceSetupOrigin.user => context.messages.taskAgentSetupOriginUser,
    AgentInferenceSetupOrigin.categorySnapshot =>
      context.messages.taskAgentSetupOriginCategory,
    AgentInferenceSetupOrigin.templateSnapshot =>
      context.messages.taskAgentSetupOriginTemplate,
    AgentInferenceSetupOrigin.unknown ||
    null => context.messages.taskAgentSetupOriginLegacy,
  };
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
    viaLabel: context.messages.taskAgentRouteVia,
  );
}
