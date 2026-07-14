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
import 'package:lotti/features/ai/ui/widgets/inference_selection_rows.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

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
      navigator: Navigator.of(
        context,
        rootNavigator: ModalUtils.shouldUseRootNavigatorForBottomSheet(context),
      ),
      taskMessenger: ScaffoldMessenger.of(context),
      errorTitle: context.messages.commonError,
    );

    return ModalUtils.showMultiPageModal<void>(
      context: context,
      pageIndexNotifier: pageIndex,
      pageListBuilder: (modalContext) {
        controller.bindModalRoute(modalContext);
        return [
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
            title: modalContext.messages.aiModelPickerByProviderLabel,
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
        ];
      },
    );
  }
}

List<String> _providerIdsForModels(TaskAgentSetupOptions options) {
  final configuredProviderIds = options.providers
      .map((value) => value.id)
      .toSet();
  final ids = <String>{};
  for (final model in options.models) {
    if (configuredProviderIds.contains(model.inferenceProviderId)) {
      ids.add(model.inferenceProviderId);
    }
  }
  if (ids.isNotEmpty) return ids.toList();
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
    required this.navigator,
    required this.taskMessenger,
    required this.errorTitle,
  });

  final ProviderContainer container;
  final String taskId;
  final String agentId;
  final NavigatorState navigator;
  final ScaffoldMessengerState taskMessenger;
  final String errorTitle;
  final busy = ValueNotifier<bool>(false);
  final confirmDisable = ValueNotifier<bool>(false);
  ModalRoute<dynamic>? _modalRoute;

  void bindModalRoute(BuildContext context) {
    _modalRoute ??= ModalRoute.of(context);
  }

  void _closeModalIfCurrent() {
    final route = _modalRoute;
    if (route?.isCurrent == true && navigator.mounted) navigator.pop();
  }

  Future<bool> _persist(
    Future<void> Function() action,
  ) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await action();
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
      if (taskMessenger.mounted) {
        taskMessenger.showDesignSystemToast(
          tone: DesignSystemToastTone.error,
          title: errorTitle,
        );
      }
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> _persistTerminalChoice(
    Future<void> Function() action, {
    required String successTitle,
  }) async {
    final persisted = await _persist(action);
    if (!persisted) return false;
    _closeModalIfCurrent();
    if (taskMessenger.mounted) {
      taskMessenger.showDesignSystemToast(
        tone: DesignSystemToastTone.success,
        title: successTitle,
      );
    }
    return true;
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
      final persisted = await _persist(action);
      if (persisted) _closeModalIfCurrent();
      return;
    }
    await _persistTerminalChoice(
      action,
      successTitle: messages.taskAgentProfileChangedToast(profile.name),
    );
  }

  Future<bool> chooseProfile(
    BuildContext context,
    AiConfigInferenceProfile profile,
  ) => _persistTerminalChoice(
    () => container
        .read(taskAgentServiceProvider)
        .updateAgentProfile(agentId: agentId, profileId: profile.id),
    successTitle: context.messages.taskAgentProfileChangedToast(profile.name),
  );

  Future<bool> chooseModel(
    BuildContext context,
    String modelId,
    TaskAgentSetupOptions options,
  ) {
    final model = options.models
        .where((value) => value.id == modelId)
        .firstOrNull;
    return _persistTerminalChoice(
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

  Future<void> clearOverride() => _persist(
    () => container
        .read(taskAgentServiceProvider)
        .updateAgentThinkingModelOverride(
          agentId: agentId,
          modelConfigId: null,
        ),
  );

  Future<void> updateAutomaticUpdates({
    required bool enabled,
  }) => _persist(
    () => container
        .read(taskAgentServiceProvider)
        .updateAutomaticUpdates(agentId: agentId, enabled: enabled),
  );

  Future<void> disable() async {
    final persisted = await _persist(
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
    if (persisted) _closeModalIfCurrent();
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
      builder: (context, busy, child) {
        final guardedChild = AbsorbPointer(
          absorbing: busy,
          child: busy ? ExcludeSemantics(child: child) : child,
        );
        if (!busy) return guardedChild;
        return Semantics(
          container: true,
          liveRegion: true,
          label: context.messages.taskAgentSavingSetup,
          child: guardedChild,
        );
      },
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
        .unwrapPrevious()
        .value
        ?.mapOrNull(agent: (value) => value);
    final setup = ref
        .watch(taskAgentResolvedSetupProvider(agentId))
        .unwrapPrevious()
        .value;
    final options = ref
        .watch(taskAgentSetupOptionsProvider)
        .unwrapPrevious()
        .value;
    final config = identity?.config;
    final currentProfile = options?.profiles
        .where(
          (profile) => profile.id == config?.inferenceSetup?.baseProfileId,
        )
        .firstOrNull;
    final resolvedProfile = setup?.profile;
    final resolvedModelName = resolvedProfile?.thinkingModel?.name;
    final modelRoute = resolvedProfile == null
        ? null
        : '${resolvedModelName ?? resolvedProfile.thinkingModelId} · '
              '${resolvedProfile.thinkingProvider.name}';
    final modelSource = config?.inferenceSetup?.thinkingModelOverrideId == null
        ? context.messages.taskAgentProfileDefaultBadge
        : context.messages.taskAgentDirectModelOverride;
    final modelDescription = modelRoute == null
        ? (setup?.status == AgentSetupResolutionStatus.disabled
              ? context.messages.taskAgentNoProfileSelected
              : context.messages.taskAgentSetupBroken)
        : '$modelRoute\n$modelSource';
    final automaticUpdates = config?.automaticUpdatesEnabledEffective ?? false;

    return _AgentBusyGuard(
      controller: controller,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step4,
            tokens.spacing.step5,
            tokens.spacing.step7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AgentSetupSection(
                label: context.messages.taskAgentCurrentSetupLabel,
                description: context.messages.taskAgentSetupChoiceHelp,
                child: DesignSystemGroupedList(
                  padding: EdgeInsets.zero,
                  filled: false,
                  children: [
                    DesignSystemSelectionRow(
                      key: const ValueKey('agent-choose-profile'),
                      title: context.messages.taskAgentInferenceProfileLabel,
                      subtitle:
                          currentProfile?.name ??
                          context.messages.taskAgentNoProfileSelected,
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
                      title: context.messages.taskAgentThinkingModelLabel,
                      subtitle: options != null && options.models.isEmpty
                          ? context.messages.taskAgentNoModelsAvailable
                          : modelDescription,
                      type: DesignSystemSelectionRowType.navigation,
                      leading: Icon(
                        Icons.psychology_outlined,
                        color: tokens.colors.text.mediumEmphasis,
                        size: tokens.spacing.step6,
                      ),
                      onTap:
                          config == null ||
                              options == null ||
                              options.models.isEmpty
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
                        onTap: controller.clearOverride,
                      ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.sectionGap),
              _AgentSetupSection(
                label: context.messages.taskAgentAutomationSection,
                child: DesignSystemGroupedList(
                  padding: EdgeInsets.zero,
                  filled: false,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(tokens.spacing.cardPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: tokens.spacing.step9,
                        ),
                        child: SettingsSwitchRow(
                          key: const Key('taskAgentAutomaticUpdatesCheckbox'),
                          title:
                              context.messages.taskAgentAutomaticUpdatesLabel,
                          subtitle:
                              config?.inferenceSetup?.mode ==
                                  AgentInferenceSetupMode.disabled
                              ? context
                                    .messages
                                    .taskAgentAutomaticUpdatesNeedsSetup
                              : context
                                    .messages
                                    .taskAgentAutomaticUpdatesSummary,
                          value: automaticUpdates,
                          enabled:
                              config?.inferenceSetup?.mode !=
                              AgentInferenceSetupMode.disabled,
                          onChanged: (value) =>
                              controller.updateAutomaticUpdates(enabled: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.step5),
              ValueListenableBuilder<bool>(
                valueListenable: controller.confirmDisable,
                builder: (context, visible, _) => visible
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DesignSystemButton(
                          key: const ValueKey('agent-disable'),
                          label: context.messages.taskAgentTurnOffSetup,
                          variant: DesignSystemButtonVariant.dangerTertiary,
                          size: DesignSystemButtonSize.medium,
                          leadingIcon: Icons.pause_circle_outline_rounded,
                          onPressed: () =>
                              controller.confirmDisable.value = true,
                        ),
                      ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: controller.confirmDisable,
                builder: (context, visible, _) {
                  if (!visible) return const SizedBox.shrink();
                  final title = context.messages.taskAgentDisableConfirmTitle;
                  final body = context.messages.taskAgentDisableConfirmBody;
                  return Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Focus(
                          autofocus: true,
                          child: Semantics(
                            key: const ValueKey(
                              'agent-disable-confirmation',
                            ),
                            container: true,
                            liveRegion: true,
                            label: '$title $body',
                            child: ExcludeSemantics(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    title,
                                    style: tokens
                                        .typography
                                        .styles
                                        .subtitle
                                        .subtitle2,
                                  ),
                                  SizedBox(height: tokens.spacing.step2),
                                  Text(
                                    body,
                                    style: tokens
                                        .typography
                                        .styles
                                        .body
                                        .bodyMedium
                                        .copyWith(
                                          color:
                                              tokens.colors.text.mediumEmphasis,
                                        ),
                                  ),
                                ],
                              ),
                            ),
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
                                onPressed: controller.disable,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentSetupSection extends StatelessWidget {
  const _AgentSetupSection({
    required this.label,
    required this.child,
    this.description,
  });

  final String label;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        if (description case final description?) ...[
          SizedBox(height: tokens.spacing.step1),
          Text(
            description,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step3),
        child,
      ],
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
    final options = ref
        .watch(taskAgentSetupOptionsProvider)
        .unwrapPrevious()
        .value;
    final config = ref
        .watch(agentIdentityProvider(agentId))
        .unwrapPrevious()
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
    final options = ref
        .watch(taskAgentSetupOptionsProvider)
        .unwrapPrevious()
        .value;
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
                  return InferenceProviderSelectionRow(
                    key: ValueKey('agent-provider-$providerId'),
                    provider: provider,
                    modelCount: modelCount,
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

class _AgentModelPage extends ConsumerStatefulWidget {
  const _AgentModelPage({
    required this.agentId,
    required this.controller,
    required this.selectedProviderId,
  });

  final String agentId;
  final _AgentSetupFlowController controller;
  final ValueNotifier<String?> selectedProviderId;

  @override
  ConsumerState<_AgentModelPage> createState() => _AgentModelPageState();
}

class _AgentModelPageState extends ConsumerState<_AgentModelPage> {
  String? _pendingModelId;

  @override
  Widget build(BuildContext context) {
    final options = ref
        .watch(taskAgentSetupOptionsProvider)
        .unwrapPrevious()
        .value;
    final config = ref
        .watch(agentIdentityProvider(widget.agentId))
        .unwrapPrevious()
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
        _pendingModelId ??
        config?.inferenceSetup?.thinkingModelOverrideId ??
        defaultModelId;

    return _AgentBusyGuard(
      controller: widget.controller,
      child: ValueListenableBuilder<String?>(
        valueListenable: widget.selectedProviderId,
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
                  InferenceModelSelectionRow(
                    key: ValueKey('agent-model-${model.id}'),
                    model: model,
                    providerType: provider?.inferenceProviderType,
                    isDefault: model.id == defaultModelId,
                    isSelected: model.id == selectedModelId,
                    defaultBadgeLabel:
                        context.messages.taskAgentProfileDefaultBadge,
                    onTap: () async {
                      if (_pendingModelId != null) return;
                      setState(() => _pendingModelId = model.id);
                      final persisted = await widget.controller.chooseModel(
                        context,
                        model.id,
                        options,
                      );
                      if (!persisted && mounted) {
                        setState(() => _pendingModelId = null);
                      }
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
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
