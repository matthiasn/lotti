import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/ai/ui/widgets/inference_profile_picker_modal.dart';
import 'package:lotti/features/ai/ui/widgets/inference_provider_model_picker_modal.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Instance-level inference controls for the single Daily OS planner.
class DailyOsInferenceSetupSheet {
  const DailyOsInferenceSetupSheet._();

  static Future<void> show(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.dailyOsSettingsInstanceOverrideTitle,
      padding: EdgeInsets.zero,
      builder: (_) => _DailyOsInferenceSetupSheetBody(messenger: messenger),
    );
  }
}

class _DailyOsInferenceSetupSheetBody extends ConsumerStatefulWidget {
  const _DailyOsInferenceSetupSheetBody({required this.messenger});

  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_DailyOsInferenceSetupSheetBody> createState() =>
      _DailyOsInferenceSetupSheetBodyState();
}

class _DailyOsInferenceSetupSheetBodyState
    extends ConsumerState<_DailyOsInferenceSetupSheetBody> {
  bool _busy = false;

  Future<void> _persist(
    Future<void> Function() update, {
    required String successTitle,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await update();
      if (!mounted) return;
      ref
        ..invalidate(agentIdentityProvider(dailyOsPlannerAgentId))
        ..invalidate(agentResolvedSetupProvider(dailyOsPlannerAgentId))
        ..invalidate(dailyOsSetupStatusProvider);
      Navigator.of(context).pop();
      if (widget.messenger.mounted) {
        widget.messenger.showDesignSystemToast(
          tone: DesignSystemToastTone.success,
          title: successTitle,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Daily OS planner inference update failed',
        name: 'DailyOsInferenceSetupSheet',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseProfile(
    AgentConfig config,
    TaskAgentSetupOptions options,
  ) async {
    final setup = config.inferenceSetup;
    final hasProfileOverride = _hasProfileOverride(setup);
    final selectedId = await InferenceProfilePickerModal.show(
      context: context,
      profiles: options.profiles,
      selectedProfileId: hasProfileOverride ? setup?.baseProfileId : null,
      title: context.messages.dailyOsSettingsChooseProfileTitle,
    );
    if (selectedId == null || !mounted) return;
    final profile = options.profiles.firstWhereOrNull(
      (value) => value.id == selectedId,
    );
    if (hasProfileOverride &&
        selectedId == setup?.baseProfileId &&
        setup?.thinkingModelOverrideId == null) {
      return;
    }
    await _persist(
      () => ref
          .read(dayAgentServiceProvider)
          .updatePlannerProfileOverride(selectedId),
      successTitle: context.messages.dailyOsSettingsProfileChanged(
        profile?.name ?? selectedId,
      ),
    );
  }

  Future<void> _chooseModel(
    AgentConfig config,
    TaskAgentSetupOptions options,
  ) async {
    final baseProfileId =
        config.inferenceSetup?.baseProfileId ?? config.profileId;
    final profile = options.profiles.firstWhereOrNull(
      (value) => value.id == baseProfileId,
    );
    final selectedId = await InferenceProviderModelPickerModal.show(
      context: context,
      defaultModelId: profile?.thinkingModelId,
      selectedModelId:
          config.inferenceSetup?.thinkingModelOverrideId ??
          profile?.thinkingModelId,
      models: options.models,
      providers: options.providers,
      title: context.messages.dailyOsSettingsChooseModelTitle,
      defaultBadgeLabel: context.messages.taskAgentProfileDefaultBadge,
      autoSelectSingleCandidate: false,
    );
    if (selectedId == null || !mounted) return;
    final model = options.models.firstWhereOrNull(
      (value) => value.id == selectedId,
    );
    await _persist(
      () => ref
          .read(dayAgentServiceProvider)
          .updatePlannerThinkingModelOverride(selectedId),
      successTitle: context.messages.dailyOsSettingsModelChanged(
        model?.name ?? selectedId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final options = ref.watch(agentSetupOptionsProvider).value;
    final identity = ref
        .watch(agentIdentityProvider(dailyOsPlannerAgentId))
        .value
        ?.mapOrNull(agent: (value) => value);
    final config = identity?.config;
    final setup = config?.inferenceSetup;
    final overrideId = setup?.thinkingModelOverrideId;
    final hasProfileOverride = _hasProfileOverride(setup);
    final currentProfile = options?.profiles.firstWhereOrNull(
      (value) => value.id == setup?.baseProfileId,
    );
    final overrideModel = options?.models.firstWhereOrNull(
      (value) => value.id == overrideId,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Text(
            context.messages.dailyOsSettingsInstanceOverrideDescription,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        DesignSystemListItem(
          title: context.messages.dailyOsSettingsUseDefault,
          subtitle: context.messages.dailyOsSettingsUseDefaultDescription,
          leading: const Icon(Icons.account_tree_outlined),
          trailing: !hasProfileOverride && overrideId == null
              ? const Icon(Icons.check_rounded)
              : null,
          selected: !hasProfileOverride && overrideId == null,
          onTap: _busy || config == null
              ? null
              : () => _persist(
                  () => ref
                      .read(dayAgentServiceProvider)
                      .resetPlannerInferenceToDefault(),
                  successTitle: context.messages.dailyOsSettingsDefaultRestored,
                ),
          showDivider: true,
        ),
        DesignSystemListItem(
          title: hasProfileOverride
              ? currentProfile?.name ??
                    context.messages.dailyOsSettingsChooseProfileTitle
              : context.messages.dailyOsSettingsChooseProfileTitle,
          subtitle: hasProfileOverride
              ? context.messages.dailyOsSettingsProfileOverrideActive
              : context.messages.dailyOsSettingsChooseProfileDescription,
          leading: const Icon(Icons.schema_outlined),
          trailing: const Icon(Icons.chevron_right_rounded),
          selected: hasProfileOverride,
          onTap: _busy || config == null || options == null
              ? null
              : () => _chooseProfile(config, options),
          showDivider: true,
        ),
        DesignSystemListItem(
          title:
              overrideModel?.name ??
              context.messages.dailyOsSettingsChooseModelTitle,
          subtitle: overrideId == null
              ? context.messages.dailyOsSettingsChooseModelDescription
              : context.messages.dailyOsSettingsDirectOverrideActive,
          leading: const Icon(Icons.psychology_outlined),
          trailing: _busy
              ? SizedBox.square(
                  dimension: tokens.spacing.step5,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right_rounded),
          selected: overrideId != null,
          onTap: _busy || config == null || options == null
              ? null
              : () => _chooseModel(config, options),
        ),
        Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Text(
            context.messages.dailyOsSettingsDataDisclosure,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

bool _hasProfileOverride(AgentInferenceSetup? setup) =>
    setup?.origin == AgentInferenceSetupOrigin.user &&
    setup?.originEntityId != dayAgentTemplateId;
