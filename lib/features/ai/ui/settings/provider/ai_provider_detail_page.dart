import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_widgets.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:lotti/features/ai/ui/settings/util/active_profile.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_settings_back_nav.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;

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
    // All three watches sit at the top of `build` so Riverpod's
    // dependency graph is stable across loading / error / data
    // transitions — calling `ref.watch` inside a `.when(data: ...)`
    // callback would cause the controllers to be dropped and
    // re-subscribed every time the AsyncValue changes state.
    final configAsync = ref.watch(aiConfigByIdProvider(widget.providerId));
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );
    final profilesAsync = ref.watch(inferenceProfileControllerProvider);

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: messages.aiProviderDetailBackTooltip,
          onPressed: () => popAiSettingsDetail(context),
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
          // `modelsAsync` and `profilesAsync` are watched at the top
          // of `build`; we project them lazily here because we want to
          // render the detail body even while those streams are still
          // resolving (empty lists in that case — the body shows the
          // empty-section card for models and hides the active-profile
          // section).
          final models = modelsAsync.maybeWhen(
            data: (rows) => rows
                .whereType<AiConfigModel>()
                .where((m) => m.inferenceProviderId == config.id)
                .toList(),
            orElse: () => const <AiConfigModel>[],
          );
          final allModels = modelsAsync.maybeWhen(
            data: (rows) => rows.whereType<AiConfigModel>().toList(),
            orElse: () => const <AiConfigModel>[],
          );
          final activeProfile = profilesAsync.maybeWhen(
            data: (rows) => pickActiveProfileForProvider(
              profiles: rows.whereType<AiConfigInferenceProfile>().toList(),
              providerModels: models,
            ),
            orElse: () => null,
          );

          // Fire the Fix-flow once per mount, after the data has
          // resolved — so the form opens with a populated controller
          // (the form fetches the config itself, but routing only
          // after `data` gives us a defensive "config exists" check).
          if (_focusFlowQueued) {
            _focusFlowQueued = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // On desktop the page is URL-driven; clear the
              // `?focusApiKey=true` query so a later remount (panel
              // swap, back-nav, hot reload) doesn't re-open the edit
              // form unprompted. Skipped when the page was mounted
              // directly (mobile/test) — there's no URL to clean.
              final desktopRoute = getIt<nav_service.NavService>()
                  .desktopSelectedSettingsRoute
                  .value;
              if (desktopRoute?.queryParameters['focusApiKey'] == 'true') {
                nav_service.beamToNamed(
                  '/settings/ai/provider/${widget.providerId}',
                );
              }
              _openEditForm(focusApiKey: true);
            });
          }

          return DetailBody(
            provider: config,
            models: models,
            allModels: allModels,
            activeProfile: activeProfile,
            onAddModel: () => _navigationService.navigateToCreateModel(
              context,
              preselectedProviderId: widget.providerId,
            ),
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
    await popAiSettingsDetail(context);
  }
}
