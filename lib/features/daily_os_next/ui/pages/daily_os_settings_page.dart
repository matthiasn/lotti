import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/inference_profile_picker_modal.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

/// Mobile route wrapper for the shared Daily OS settings body.
class DailyOsSettingsPage extends StatelessWidget {
  const DailyOsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleAppBar(title: context.messages.dailyOsSettingsTitle),
      body: const SingleChildScrollView(child: DailyOsSettingsBody()),
    );
  }
}

/// Default inference and personalization settings for Daily OS.
class DailyOsSettingsBody extends ConsumerStatefulWidget {
  const DailyOsSettingsBody({super.key});

  @override
  ConsumerState<DailyOsSettingsBody> createState() =>
      _DailyOsSettingsBodyState();
}

class _DailyOsSettingsBodyState extends ConsumerState<DailyOsSettingsBody> {
  late final TextEditingController _nameController;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(dailyOsPreferencesControllerProvider).userName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseDefaultProfile(
    TaskAgentSetupOptions options,
    String? selectedProfileId,
  ) async {
    if (_savingProfile) return;
    final profileId = await InferenceProfilePickerModal.show(
      context: context,
      profiles: options.profiles,
      selectedProfileId: selectedProfileId,
      title: context.messages.dailyOsSettingsChooseProfileTitle,
    );
    if (profileId == null || profileId == selectedProfileId || !mounted) {
      return;
    }
    final profile = options.profiles.firstWhereOrNull(
      (value) => value.id == profileId,
    );
    setState(() => _savingProfile = true);
    try {
      await ref
          .read(dayAgentServiceProvider)
          .updateDefaultInferenceProfile(profileId);
      if (!mounted) return;
      ref
        ..invalidate(agentTemplateProvider(dayAgentTemplateId))
        ..invalidate(agentResolvedSetupProvider)
        ..invalidate(dailyOsSetupStatusProvider);
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.dailyOsSettingsProfileChanged(
          profile?.name ?? profileId,
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Daily OS default profile update failed',
        name: 'DailyOsSettingsBody',
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
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final optionsAsync = ref.watch(agentSetupOptionsProvider);
    final templateAsync = ref.watch(agentTemplateProvider(dayAgentTemplateId));
    final options = optionsAsync.value;
    final template = templateAsync.value?.mapOrNull(
      agentTemplate: (value) => value,
    );
    final selectedProfileId = template?.profileId;
    final selectedProfile = options?.profiles.firstWhereOrNull(
      (value) => value.id == selectedProfileId,
    );
    final route = options == null || selectedProfile == null
        ? null
        : _profileRoute(selectedProfile, options);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.dailyOsSettingsSubtitle,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          _SectionTitle(
            icon: Icons.psychology_outlined,
            title: context.messages.dailyOsSettingsInferenceTitle,
          ),
          SizedBox(height: tokens.spacing.step3),
          DesignSystemGroupedList(
            padding: EdgeInsets.zero,
            children: [
              DesignSystemListItem(
                key: const Key('daily_os_default_profile'),
                title:
                    selectedProfile?.name ??
                    context.messages.dailyOsSettingsDefaultProfileMissing,
                subtitle:
                    route?.label ??
                    context.messages.dailyOsSettingsDefaultProfileDescription,
                subtitleMaxLines: null,
                leading: const SettingsIcon(icon: Icons.account_tree_outlined),
                trailing: _savingProfile
                    ? SizedBox.square(
                        dimension: tokens.spacing.step5,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : SettingsIcon.trailingChevron(tokens),
                onTap: options == null || options.profiles.isEmpty
                    ? null
                    : () => _chooseDefaultProfile(
                        options,
                        selectedProfileId,
                      ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          _Disclosure(route: route),
          SizedBox(height: tokens.spacing.sectionGap),
          _SectionTitle(
            icon: Icons.person_outline_rounded,
            title: context.messages.settingsAboutDailyOsPersonalizationTitle,
          ),
          SizedBox(height: tokens.spacing.step3),
          DesignSystemTextInput(
            key: const Key('daily_os_user_name_field'),
            controller: _nameController,
            label: context.messages.settingsAboutDailyOsUserNameLabel,
            helperText: context.messages.settingsAboutDailyOsUserNameHelper,
            leadingIcon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            onChanged: ref
                .read(dailyOsPreferencesControllerProvider.notifier)
                .setUserName,
          ),
        ],
      ),
    );
  }

  _DailyOsRoute? _profileRoute(
    AiConfigInferenceProfile profile,
    TaskAgentSetupOptions options,
  ) {
    final model = options.models.firstWhereOrNull(
      (value) =>
          value.id == profile.thinkingModelId ||
          value.providerModelId == profile.thinkingModelId,
    );
    if (model == null) return null;
    final provider = options.providers.firstWhereOrNull(
      (value) => value.id == model.inferenceProviderId,
    );
    if (provider == null) return null;
    final label = formatInferenceRouteIdentity(
      InferenceRouteSnapshot(
        modelConfigId: model.id,
        providerModelId: model.providerModelId,
        modelName: model.name,
        publisherName: model.publisher,
        servingProviderConfigId: provider.id,
        servingProviderType: provider.inferenceProviderType,
        servingProviderName: provider.name,
        runtimeSettings: const <String, Object?>{},
      ),
      viaLabel: context.messages.taskAgentRouteVia,
    );
    return _DailyOsRoute(label: label, provider: provider);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Icon(icon, color: tokens.colors.interactive.enabled),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            title,
            style: tokens.typography.styles.subtitle.subtitle2,
          ),
        ),
      ],
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.route});

  final _DailyOsRoute? route;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final route = this.route;
    final configuredHost = route == null
        ? null
        : Uri.tryParse(route.provider.baseUrl)?.host;
    final configuredEndpoint = route == null
        ? null
        : configuredHost?.isNotEmpty ?? false
        ? configuredHost!
        : route.provider.baseUrl.trim().isNotEmpty
        ? route.provider.baseUrl
        : route.provider.name;
    final endpointText = route == null
        ? null
        : dailyOsInferenceEndpointKind(route.provider) ==
              DailyOsInferenceEndpointKind.onDevice
        ? context.messages.dailyOsSettingsLocalDisclosure
        : context.messages.dailyOsSettingsRemoteDisclosure(
            route.provider.name,
            configuredEndpoint!,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              color: tokens.colors.text.mediumEmphasis,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                [
                  context.messages.dailyOsSettingsDataDisclosure,
                  ?endpointText,
                ].join(' '),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyOsRoute {
  const _DailyOsRoute({required this.label, required this.provider});

  final String label;
  final AiConfigInferenceProvider provider;
}
