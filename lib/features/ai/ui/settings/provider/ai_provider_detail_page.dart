import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Detail page for a single inference provider.
///
/// Sketch (no Figma design exists for this page yet):
///
/// ```text
/// ┌─ AppBar ──────────────────────────────────────────────────┐
/// │ ←   Provider details                                  ✎   │
/// └───────────────────────────────────────────────────────────┘
/// ┌─ Header strip ────────────────────────────────────────────┐
/// │ [icon]  Google Gemini                                     │
/// │         Free tier · multimodal · audio transcription      │
/// │         • Connected                                       │
/// └───────────────────────────────────────────────────────────┘
/// ┌─ Connection ──────────────────────────────────────────────┐
/// │ API key      ••••••••8f3a                       [Edit]    │
/// │ Base URL     https://generativelanguage.googleapis.com    │
/// │ Display name Google Gemini                                │
/// └───────────────────────────────────────────────────────────┘
/// ┌─ Models · 3                              [+ Add model] ───┐
/// │ [AiModelCard] rows                                        │
/// └───────────────────────────────────────────────────────────┘
/// ┌─ Active profile ──────────────────────────────────────────┐
/// │ [AiProfileCard]                                           │
/// └───────────────────────────────────────────────────────────┘
/// ┌─ Danger zone ─────────────────────────────────────────────┐
/// │ [ Remove provider ]                                       │
/// └───────────────────────────────────────────────────────────┘
/// ```
///
/// Re-uses `AiModelCard` and `AiProfileCard` from the redesigned tab
/// bodies so models and profiles look the same here as on the main
/// page. The edit pencil and the `Edit` button on the connection card
/// both push `InferenceProviderEditPage(configId: ...)`; the Fix-flow
/// entry point uses [focusApiKey] to land the user on the API key
/// field after the form opens (the detail page is briefly visible
/// behind the form as it slides in).
class AiProviderDetailPage extends ConsumerStatefulWidget {
  const AiProviderDetailPage({
    required this.providerId,
    this.focusApiKey = false,
    super.key,
  });

  final String providerId;

  /// When `true`, the detail page immediately routes to
  /// `InferenceProviderEditPage(focusApiKey: true)` on first frame so
  /// the user lands on the API key field. Used by the provider card's
  /// "Fix" affordance (invalid-key status). The detail page itself
  /// stays in the navigation stack so the user returns here after
  /// editing.
  final bool focusApiKey;

  @override
  ConsumerState<AiProviderDetailPage> createState() =>
      _AiProviderDetailPageState();
}

class _AiProviderDetailPageState extends ConsumerState<AiProviderDetailPage> {
  static const _navigationService = AiSettingsNavigationService();
  static const _deleteService = AiConfigDeleteService();
  bool _focusFlowQueued = false;

  @override
  void initState() {
    super.initState();
    _focusFlowQueued = widget.focusApiKey;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final configAsync = ref.watch(aiConfigByIdProvider(widget.providerId));

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: messages.aiProviderDetailBackTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          messages.aiProviderDetailPageTitle,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        actions: [
          configAsync.maybeWhen(
            data: (config) {
              if (config is AiConfigInferenceProvider) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: messages.aiProviderDetailEditTooltip,
                  onPressed: () => _openEditForm(focusApiKey: false),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          SizedBox(width: tokens.spacing.step2),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step5),
            child: Text(
              messages.aiProviderDetailLoadError,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
        data: (config) {
          if (config is! AiConfigInferenceProvider) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step5),
                child: Text(
                  messages.aiProviderDetailMissingMessage,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            );
          }
          // Detail body needs the provider's models and the active
          // profile pool. Both are stream-backed so the page stays
          // live (e.g. after the user adds a model from the
          // "+ Add model" button or returns from the edit form).
          final modelsAsync = ref.watch(
            aiConfigByTypeControllerProvider(configType: AiConfigType.model),
          );
          final profilesAsync = ref.watch(inferenceProfileControllerProvider);

          final models = modelsAsync.maybeWhen(
            data: (rows) => rows
                .whereType<AiConfigModel>()
                .where((m) => m.inferenceProviderId == config.id)
                .toList(),
            orElse: () => const <AiConfigModel>[],
          );
          final activeProfile = profilesAsync.maybeWhen(
            data: (rows) => _pickActiveProfileForProvider(
              profiles: rows.whereType<AiConfigInferenceProfile>().toList(),
              providerModels: models,
            ),
            orElse: () => null,
          );

          // Fire the Fix-flow once per mount, after the data has
          // resolved — so the form opens with a populated controller
          // (the form fetches the config itself, but routing only
          // after `data` gives us a defensive "config exists" check).
          // Beam to the same path without `?focusApiKey=true` so a later
          // remount (panel swap, back-nav, hot reload) doesn't re-open
          // the edit form unprompted.
          if (_focusFlowQueued) {
            _focusFlowQueued = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              nav_service.beamToNamed(
                '/settings/ai/provider/${widget.providerId}',
              );
              _openEditForm(focusApiKey: true);
            });
          }

          return _DetailBody(
            provider: config,
            models: models,
            activeProfile: activeProfile,
            onAddModel: () => _navigationService.navigateToCreateModel(context),
            onEdit: () => _openEditForm(focusApiKey: false),
            onModelTap: _openModelEditForm,
            onProfileTap: _openProfileEditForm,
            onRemove: () => _confirmRemove(context, config),
          );
        },
      ),
    );
  }

  Future<void> _openEditForm({required bool focusApiKey}) async {
    await _navigationService.navigateToProviderEdit(
      context,
      providerId: widget.providerId,
      focusApiKey: focusApiKey,
    );
  }

  Future<void> _openModelEditForm(AiConfigModel model) async {
    await _navigationService.navigateToConfigEdit(context, model);
  }

  Future<void> _openProfileEditForm(AiConfigInferenceProfile profile) async {
    await _navigationService.navigateToConfigEdit(context, profile);
  }

  Future<void> _confirmRemove(
    BuildContext outerContext,
    AiConfigInferenceProvider provider,
  ) async {
    final removed = await _deleteService.deleteConfig(
      context: outerContext,
      ref: ref,
      config: provider,
    );
    if (!removed || !mounted) return;
    await Navigator.of(context).maybePop();
  }
}

/// Picks the inference profile that best represents the "active
/// profile for this provider". Heuristic:
/// 1. If any default-marked profile has at least one of its slots
///    pointing at a model owned by [providerModels], that's the
///    winner.
/// 2. Otherwise, the first profile whose slots reference one of
///    [providerModels].
/// 3. Returns null if no profile touches any of the provider's
///    models — keeps the active-profile section from showing a
///    misleading "active" tile for a provider that isn't actually
///    wired into any profile yet.
AiConfigInferenceProfile? _pickActiveProfileForProvider({
  required List<AiConfigInferenceProfile> profiles,
  required List<AiConfigModel> providerModels,
}) {
  if (providerModels.isEmpty || profiles.isEmpty) return null;
  final providerModelIds = providerModels.map((m) => m.providerModelId).toSet();

  bool touchesProvider(AiConfigInferenceProfile p) {
    final slots = <String?>[
      p.thinkingModelId,
      p.thinkingHighEndModelId,
      p.imageRecognitionModelId,
      p.transcriptionModelId,
      p.imageGenerationModelId,
    ];
    return slots.any(
      (slot) => slot != null && providerModelIds.contains(slot),
    );
  }

  final defaults = profiles.where((p) => p.isDefault).where(touchesProvider);
  if (defaults.isNotEmpty) return defaults.first;
  final anyMatching = profiles.where(touchesProvider);
  if (anyMatching.isNotEmpty) return anyMatching.first;
  return null;
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.provider,
    required this.models,
    required this.activeProfile,
    required this.onAddModel,
    required this.onEdit,
    required this.onModelTap,
    required this.onProfileTap,
    required this.onRemove,
  });

  final AiConfigInferenceProvider provider;
  final List<AiConfigModel> models;
  final AiConfigInferenceProfile? activeProfile;
  final VoidCallback onAddModel;
  final VoidCallback onEdit;
  final ValueChanged<AiConfigModel> onModelTap;
  final ValueChanged<AiConfigInferenceProfile> onProfileTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Pad the bottom by the height the app's bottom nav bar occupies
    // (zero on desktop, ~88pt on mobile with the home indicator) plus
    // the page's normal step6 gap, so the danger-zone card always
    // clears the nav bar on mobile instead of slipping behind it.
    final bottomInset = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step6 + bottomInset,
      ),
      children: [
        _HeaderStrip(provider: provider, modelCount: models.length),
        SizedBox(height: tokens.spacing.step5),
        _ConnectionSection(provider: provider, onEdit: onEdit),
        SizedBox(height: tokens.spacing.step6),
        _ModelsSection(
          provider: provider,
          models: models,
          onAddModel: onAddModel,
          onModelTap: onModelTap,
        ),
        SizedBox(height: tokens.spacing.step6),
        if (activeProfile != null)
          _ActiveProfileSection(
            profile: activeProfile!,
            providerType: provider.inferenceProviderType,
            models: models,
            onProfileTap: onProfileTap,
          ),
        if (activeProfile != null) SizedBox(height: tokens.spacing.step6),
        _DangerZoneSection(onRemove: onRemove),
      ],
    );
  }
}

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.provider, required this.modelCount});

  final AiConfigInferenceProvider provider;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final visual = aiProviderVisual(
      type: provider.inferenceProviderType,
      tokens: tokens,
      messages: messages,
    );
    final status = AiProviderCard.statusFor(
      provider: provider,
      modelCount: modelCount,
    );
    final displayName = provider.name.isNotEmpty
        ? provider.name
        : visual.displayName;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visual.surface,
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            child: Icon(
              aiProviderIcon(provider.inferenceProviderType),
              size: tokens.spacing.step6,
              color: visual.accent,
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (visual.tagline.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    visual.tagline,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.step3),
                _StatusPill(status: status, modelCount: modelCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.modelCount});

  final AiProviderCardStatus status;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final (dotColor, label, textColor) = switch (status) {
      AiProviderCardStatus.connected => (
        tokens.colors.alert.success.defaultColor,
        messages.aiProviderCardModelCount(modelCount),
        tokens.colors.text.highEmphasis,
      ),
      AiProviderCardStatus.invalidKey => (
        tokens.colors.alert.error.defaultColor,
        messages.aiProviderCardStatusInvalidKey,
        tokens.colors.alert.error.defaultColor,
      ),
      AiProviderCardStatus.offline => (
        tokens.colors.text.lowEmphasis,
        messages.aiProviderCardOllamaHint,
        tokens.colors.text.highEmphasis,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: textColor,
              fontWeight: tokens.typography.weight.semiBold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({required this.provider, required this.onEdit});

  final AiConfigInferenceProvider provider;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final requiresKey = !ProviderConfig.noApiKeyRequired.contains(
      provider.inferenceProviderType,
    );
    final rows = <_ConnectionRow>[
      if (requiresKey)
        _ConnectionRow(
          label: messages.aiProviderDetailApiKeyLabel,
          value: _maskApiKey(provider.apiKey),
          isMissing: provider.apiKey.trim().isEmpty,
        ),
      _ConnectionRow(
        label: messages.aiProviderDetailBaseUrlLabel,
        value: provider.baseUrl.isEmpty
            ? messages.aiProviderDetailValueUnset
            : provider.baseUrl,
        isMissing: provider.baseUrl.trim().isEmpty,
      ),
      _ConnectionRow(
        label: messages.aiProviderDetailDisplayNameLabel,
        value: provider.name.isEmpty
            ? messages.aiProviderDetailValueUnset
            : provider.name,
        isMissing: provider.name.trim().isEmpty,
      ),
    ];

    return _Section(
      title: messages.aiProviderDetailConnectionTitle,
      trailing: DesignSystemButton(
        label: messages.aiProviderDetailEditButton,
        variant: DesignSystemButtonVariant.secondary,
        leadingIcon: Icons.edit_outlined,
        onPressed: onEdit,
      ),
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.l),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: tokens.spacing.step3),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Masks an API key down to its trailing four characters. Returns an
/// empty string when the trimmed key is empty — [_ConnectionRow] then
/// substitutes the localized "Not set" placeholder.
String _maskApiKey(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length <= 4) return '•' * trimmed.length;
  final visible = trimmed.substring(trimmed.length - 4);
  return '•••• $visible';
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.label,
    required this.value,
    required this.isMissing,
  });

  final String label;
  final String value;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final shown = value.isEmpty ? messages.aiProviderDetailValueUnset : value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            shown,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: isMissing
                  ? tokens.colors.alert.warning.defaultColor
                  : tokens.colors.text.highEmphasis,
              fontFamily: isMissing ? null : 'Inconsolata',
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelsSection extends StatelessWidget {
  const _ModelsSection({
    required this.provider,
    required this.models,
    required this.onAddModel,
    required this.onModelTap,
  });

  final AiConfigInferenceProvider provider;
  final List<AiConfigModel> models;
  final VoidCallback onAddModel;
  final ValueChanged<AiConfigModel> onModelTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return _Section(
      title: messages.aiProviderDetailModelsTitle(models.length),
      trailing: DesignSystemButton(
        label: messages.aiProviderDetailAddModelButton,
        variant: DesignSystemButtonVariant.secondary,
        leadingIcon: Icons.add_rounded,
        onPressed: onAddModel,
      ),
      child: models.isEmpty
          ? _EmptySectionCard(
              message: messages.aiProviderDetailNoModelsMessage,
            )
          : Column(
              children: [
                for (var i = 0; i < models.length; i++) ...[
                  if (i > 0) SizedBox(height: tokens.spacing.step3),
                  AiModelCard(
                    model: models[i],
                    providerType: provider.inferenceProviderType,
                    onTap: () => onModelTap(models[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ActiveProfileSection extends StatelessWidget {
  const _ActiveProfileSection({
    required this.profile,
    required this.providerType,
    required this.models,
    required this.onProfileTap,
  });

  final AiConfigInferenceProfile profile;
  final InferenceProviderType providerType;
  final List<AiConfigModel> models;
  final ValueChanged<AiConfigInferenceProfile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final modelNamesById = <String, String>{
      for (final m in models) m.providerModelId: m.name,
    };
    return _Section(
      title: messages.aiProviderDetailActiveProfileTitle,
      child: AiProfileCard(
        profile: profile,
        isActive: profile.isDefault,
        providerTypeFor: () => providerType,
        modelLookup: (id) => modelNamesById[id],
        onTap: () => onProfileTap(profile),
      ),
    );
  }
}

class _DangerZoneSection extends StatelessWidget {
  const _DangerZoneSection({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return _Section(
      title: messages.aiProviderDetailDangerZoneTitle,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          color: tokens.colors.alert.error.defaultColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(tokens.radii.l),
          border: Border.all(
            color: tokens.colors.alert.error.defaultColor.withValues(
              alpha: 0.18,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    messages.aiProviderDetailRemoveTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    messages.aiProviderDetailRemoveDescription,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step4),
            DesignSystemButton(
              label: messages.aiProviderDetailRemoveButton,
              variant: DesignSystemButtonVariant.dangerSecondary,
              leadingIcon: Icons.delete_outline_rounded,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        child,
      ],
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step6,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
