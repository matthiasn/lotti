import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/omlx_inference_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:uuid/uuid.dart';

// Edit-mode form widgets: provider type, available models, AI setup.

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final meliousInferenceRepositoryProvider =
    Provider.autoDispose<MeliousInferenceRepository>((ref) {
      final repository = MeliousInferenceRepository();
      ref.onDispose(repository.close);
      return repository;
    });

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final omlxInferenceRepositoryProvider =
    Provider.autoDispose<OmlxInferenceRepository>((ref) {
      final repository = OmlxInferenceRepository();
      ref.onDispose(repository.close);
      return repository;
    });

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final mistralInferenceRepositoryProvider =
    Provider.autoDispose<MistralInferenceRepository>((ref) {
      final repository = MistralInferenceRepository();
      ref.onDispose(repository.close);
      return repository;
    });

// Riverpod 3 keeps the concrete provider-family type internal, so this family
// has to rely on inference to remain callable and invalidatable.
// ignore: specify_nonobvious_property_types
final _dynamicKnownModelsProvider = FutureProvider.autoDispose
    .family<List<KnownModel>, String>((
      ref,
      providerId,
    ) async {
      final meliousRepository = ref.watch(meliousInferenceRepositoryProvider);
      final omlxRepository = ref.watch(omlxInferenceRepositoryProvider);
      final mistralRepository = ref.watch(mistralInferenceRepositoryProvider);
      final repository = ref.read(aiConfigRepositoryProvider);
      final config = await repository.getConfigById(providerId);
      if (config is! AiConfigInferenceProvider) {
        return const <KnownModel>[];
      }

      final baseUrl = config.baseUrl.trim().isEmpty
          ? ProviderConfig.getDefaultBaseUrl(config.inferenceProviderType)
          : config.baseUrl.trim();

      return switch (config.inferenceProviderType) {
        InferenceProviderType.melious => meliousRepository.listModels(
          baseUrl: baseUrl,
          apiKey: config.apiKey,
        ),
        InferenceProviderType.omlx => omlxRepository.listModels(
          baseUrl: baseUrl,
          apiKey: config.apiKey,
        ),
        InferenceProviderType.mistral => mistralRepository.listModels(
          baseUrl: baseUrl,
          apiKey: config.apiKey,
        ),
        _ => const <KnownModel>[],
      };
    }, retry: (_, _) => null);

/// Read-only field used to surface the currently-selected provider type
/// inside the form. Tapping anywhere on the field opens the provider
/// type modal. Implemented as a styled box (no `TextEditingController`)
/// so we don't allocate a new controller per build the way an
/// `AbsorbPointer(AiTextField(...))` pattern would.
class ProviderTypeField extends StatelessWidget {
  const ProviderTypeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);
    return Semantics(
      button: true,
      label: label,
      value: value,
      // Wrap the InkWell in a `Material` so the splash paints above
      // the field's opaque surface fill — without it, the
      // `Container.color` inside the InkWell would obscure the ripple.
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: radius,
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: tokens.spacing.step6,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: tokens.spacing.step4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                                fontWeight: tokens.typography.weight.semiBold,
                              ),
                        ),
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          value,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: context.colorScheme.onSurface,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: context.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmbeddedProviderHint extends StatelessWidget {
  const EmbeddedProviderHint({required this.providerType, super.key});

  final InferenceProviderType providerType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final visual = aiProviderVisual(
      type: providerType,
      tokens: tokens,
      messages: context.messages,
    );
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: visual.accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.memory_rounded, color: visual.accent),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              context.messages.aiProviderEmbeddedRuntimeHint,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section showing available known models that can be added to this provider.
class AvailableModelsSection extends ConsumerWidget {
  const AvailableModelsSection({
    required this.providerId,
    required this.providerType,
    super.key,
  });

  final String providerId;
  final InferenceProviderType providerType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

    if (ProviderConfig.supportsDynamicCatalog(providerType)) {
      return _DynamicAvailableModelsSection(providerId: providerId);
    }

    final knownModels = knownModelsByProvider[providerType] ?? [];

    if (knownModels.isEmpty) {
      return const SizedBox.shrink();
    }

    // Watch all configured models to check which are already added
    final allModelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(AiConfigType.model),
    );

    return allModelsAsync.when(
      data: (allModels) {
        // Map each already-configured model id to its saved config id so a
        // tile can both show its "Added" state and offer a remove control.
        final existingConfigs = _configsByModelId(allModels, providerId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: tokens.spacing.step4),
            AiFormSection(
              title: messages.apiKeyAvailableModelsTitle,
              icon: Icons.psychology_rounded,
              description: messages.apiKeyAvailableModelsDescription,
              children: [
                ...knownModels.map((knownModel) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.step4),
                    child: _KnownModelTile(
                      key: ValueKey(knownModel.providerModelId),
                      knownModel: knownModel,
                      providerId: providerId,
                      addedConfig: existingConfigs[knownModel.providerModelId],
                    ),
                  );
                }),
              ],
            ),
          ],
        );
      },
      loading: () => Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step6),
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _DynamicAvailableModelsSection extends ConsumerStatefulWidget {
  const _DynamicAvailableModelsSection({
    required this.providerId,
  });

  final String providerId;

  @override
  ConsumerState<_DynamicAvailableModelsSection> createState() =>
      _DynamicAvailableModelsSectionState();
}

class _DynamicAvailableModelsSectionState
    extends ConsumerState<_DynamicAvailableModelsSection> {
  static const _inlineModelLimit = 8;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final catalogAsync = ref.watch(
      _dynamicKnownModelsProvider(widget.providerId),
    );
    final allModelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(AiConfigType.model),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: tokens.spacing.step4),
        // Plain token header — a peer of the installed "Models · N" section
        // title, not the heavier iconed AiFormSection card, so the primary
        // installed list is not visually outranked by the catalog below it.
        _DynamicCatalogHeader(
          title: messages.apiKeyAvailableModelsTitle,
          description: messages.apiKeyDynamicModelsDescription,
        ),
        SizedBox(height: tokens.spacing.step4),
        allModelsAsync.when(
          skipLoadingOnReload: true,
          data: (allModels) {
            final existingConfigs = _configsByModelId(
              allModels,
              widget.providerId,
            );

            return catalogAsync.when(
              skipLoadingOnReload: true,
              data: (knownModels) {
                if (knownModels.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(tokens.spacing.step4),
                    child: Text(
                      messages.aiConfigNoModelsAvailable,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                final sortedModels = [...knownModels]
                  ..sort((a, b) => a.name.compareTo(b.name));
                final filteredModels = _filterDynamicModels(
                  sortedModels,
                  _searchQuery,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AiSettingsSearchBar(
                      key: const ValueKey('dynamic-model-catalog-search'),
                      controller: _searchController,
                      hintText: messages.aiProfileModelPickerSearchHint,
                      isCompact: true,
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      onClear: () {
                        setState(() => _searchQuery = '');
                      },
                    ),
                    SizedBox(height: tokens.spacing.step4),
                    if (filteredModels.isEmpty)
                      _DynamicModelsNoMatches(tokens: tokens)
                    else if (filteredModels.length <= _inlineModelLimit)
                      _DynamicModelsColumn(
                        models: filteredModels,
                        existingConfigs: existingConfigs,
                        providerId: widget.providerId,
                      )
                    else
                      _DynamicModelsScrollableList(
                        models: filteredModels,
                        existingConfigs: existingConfigs,
                        providerId: widget.providerId,
                      ),
                  ],
                );
              },
              loading: () => _DynamicModelsLoading(tokens: tokens),
              error: (error, _) => _DynamicModelsError(
                providerId: widget.providerId,
                error: error,
              ),
            );
          },
          loading: () => _DynamicModelsLoading(tokens: tokens),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Plain section header for the dynamic model catalog — a title + supporting
/// line styled to sit as a peer of the token-based "Models · N" section title,
/// instead of the legacy iconed [AiFormSection] card.
class _DynamicCatalogHeader extends StatelessWidget {
  const _DynamicCatalogHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: colors.text.highEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          description,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

/// Maps each model already configured for [providerId] to its saved config,
/// keyed by `providerModelId`. Tiles use this both to show the "Added" state
/// and to remove the configured model again (through [AiConfigDeleteService]).
Map<String, AiConfigModel> _configsByModelId(
  List<AiConfig> allModels,
  String providerId,
) {
  return {
    for (final model in allModels.whereType<AiConfigModel>())
      if (model.inferenceProviderId == providerId) model.providerModelId: model,
  };
}

List<KnownModel> _filterDynamicModels(
  List<KnownModel> models,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return models;
  return models
      .where((model) {
        final haystack = [
          model.name,
          model.providerModelId,
          model.description,
          ...model.inputModalities.map((modality) => modality.name),
          ...model.outputModalities.map((modality) => modality.name),
          if (model.isReasoningModel) 'thinking reasoning',
          if (model.supportsFunctionCalling) 'tools function calling',
        ].join(' ').toLowerCase();
        return haystack.contains(normalizedQuery);
      })
      .toList(growable: false);
}

class _DynamicModelsNoMatches extends StatelessWidget {
  const _DynamicModelsNoMatches({required this.tokens});

  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Text(
        context.messages.filterSelectionNoMatches,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DynamicModelsColumn extends StatelessWidget {
  const _DynamicModelsColumn({
    required this.models,
    required this.existingConfigs,
    required this.providerId,
  });

  final List<KnownModel> models;
  final Map<String, AiConfigModel> existingConfigs;
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      children: [
        ...models.map((knownModel) {
          return Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step4),
            child: _KnownModelTile(
              key: ValueKey(knownModel.providerModelId),
              knownModel: knownModel,
              providerId: providerId,
              addedConfig: existingConfigs[knownModel.providerModelId],
            ),
          );
        }),
      ],
    );
  }
}

class _DynamicModelsScrollableList extends StatelessWidget {
  const _DynamicModelsScrollableList({
    required this.models,
    required this.existingConfigs,
    required this.providerId,
  });

  final List<KnownModel> models;
  final Map<String, AiConfigModel> existingConfigs;
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      key: const ValueKey('dynamic-model-catalog-scrollable-list'),
      height: tokens.spacing.step13 * 3,
      child: ListView.separated(
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: models.length,
        separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.step4),
        itemBuilder: (context, index) {
          final knownModel = models[index];
          return _KnownModelTile(
            key: ValueKey(knownModel.providerModelId),
            knownModel: knownModel,
            providerId: providerId,
            addedConfig: existingConfigs[knownModel.providerModelId],
          );
        },
      ),
    );
  }
}

class _DynamicModelsLoading extends StatelessWidget {
  const _DynamicModelsLoading({required this.tokens});

  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _DynamicModelsError extends ConsumerWidget {
  const _DynamicModelsError({
    required this.providerId,
    required this.error,
  });

  final String providerId;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: context.colorScheme.error.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.colorScheme.error,
            size: tokens.spacing.step6,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              '${messages.aiConfigFailedToLoadModelsGeneric}\n'
              '${_dynamicModelsErrorDetail(error)}',
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: context.colorScheme.onErrorContainer,
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          IconButton(
            onPressed: () =>
                ref.invalidate(_dynamicKnownModelsProvider(providerId)),
            tooltip: messages.aiProviderConnectionRetryButton,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

String _dynamicModelsErrorDetail(Object error) {
  final detail = switch (error) {
    MeliousInferenceException(
      :final message,
      :final statusCode,
    ) =>
      statusCode == null ? message : '$message (HTTP $statusCode)',
    OmlxInferenceException(
      :final message,
      :final statusCode,
    ) =>
      statusCode == null ? message : '$message (HTTP $statusCode)',
    ArgumentError(:final message) => message?.toString() ?? error.toString(),
    _ => error.toString(),
  };

  const maxLength = 280;
  return detail.length > maxLength
      ? '${detail.substring(0, maxLength)}...'
      : detail;
}

/// Tile displaying a catalog model with an add button, or — once installed —
/// an "Added" badge plus a remove control so the action stays reversible.
class _KnownModelTile extends ConsumerStatefulWidget {
  const _KnownModelTile({
    required this.knownModel,
    required this.providerId,
    required this.addedConfig,
    super.key,
  });

  final KnownModel knownModel;
  final String providerId;

  /// The saved config when this model is already installed, else `null`.
  /// Non-null drives the "Added" state and powers the remove control.
  final AiConfigModel? addedConfig;

  @override
  ConsumerState<_KnownModelTile> createState() => _KnownModelTileState();
}

class _KnownModelTileState extends ConsumerState<_KnownModelTile> {
  bool _isAdding = false;
  bool _isRemoving = false;

  Future<void> _addModel() async {
    if (_isAdding) return;

    setState(() {
      _isAdding = true;
    });

    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      final modelId = const Uuid().v4();
      final config = widget.knownModel.toAiConfigModel(
        id: modelId,
        inferenceProviderId: widget.providerId,
      );
      await repository.saveConfig(config);
    } catch (error, stackTrace) {
      // Keep the raw, potentially sensitive error out of the UI: log it for
      // diagnostics and show a localized generic message instead.
      developer.log(
        'Failed to add Mistral model ${widget.knownModel.providerModelId}',
        name: 'KnownModelTile',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showDesignSystemToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.aiSettingsAddModelErrorTitle,
          description: context.messages.aiSettingsAddModelErrorDescription,
          replaceCurrent: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  Future<void> _removeModel() async {
    final config = widget.addedConfig;
    if (_isRemoving || config == null) return;

    setState(() {
      _isRemoving = true;
    });

    try {
      // Route through the shared delete service so removal gets the same
      // confirmation modal, undo toast, and error feedback as every other
      // model deletion in settings — instead of a silent raw delete.
      await const AiConfigDeleteService().deleteConfig(
        context: context,
        ref: ref,
        config: config,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
        });
      }
    }
  }

  IconData _getModelIcon() {
    final id = widget.knownModel.providerModelId.toLowerCase();
    // Image generation (text -> image).
    if (widget.knownModel.outputModalities.contains(Modality.image)) {
      return Icons.palette_rounded;
    }
    // Audio transcription.
    if (widget.knownModel.inputModalities.contains(Modality.audio)) {
      return Icons.mic_rounded;
    }
    // OCR / document reading.
    if (id.contains('ocr')) {
      return Icons.document_scanner_rounded;
    }
    // Code-focused models (covers `codestral`, which contains `code`).
    if (id.contains('code')) {
      return Icons.code_rounded;
    }
    // Reasoning / thinking.
    if (widget.knownModel.isReasoningModel) {
      return Icons.psychology_alt_rounded;
    }
    // Vision (image input).
    if (widget.knownModel.inputModalities.contains(Modality.image)) {
      return Icons.image_search_rounded;
    }
    return Icons.smart_toy_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final isAdded = widget.addedConfig != null;
    final accent = colors.interactive.enabled;

    // Same capability vocabulary + chip component as the installed
    // AiModelCard, so the catalog and the configured-model list read as one
    // system instead of two competing chip languages.
    final capabilityLabels = modelCapabilityLabels(
      messages: messages,
      isReasoning: widget.knownModel.isReasoningModel,
      inputModalities: widget.knownModel.inputModalities,
      outputModalities: widget.knownModel.outputModalities,
    );

    return Container(
      decoration: BoxDecoration(
        color: isAdded
            ? accent.withValues(alpha: 0.10)
            : colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: isAdded
              ? accent.withValues(alpha: 0.40)
              : colors.decorative.level01,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flat, token-styled capability icon tile (no gradient/glow).
            Container(
              width: tokens.spacing.step8,
              height: tokens.spacing.step8,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isAdded
                    ? accent.withValues(alpha: 0.16)
                    : colors.background.level03,
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(
                _getModelIcon(),
                size: tokens.spacing.step6,
                color: isAdded ? accent : colors.text.mediumEmphasis,
              ),
            ),

            SizedBox(width: tokens.spacing.step4),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.knownModel.name,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                fontWeight: tokens.typography.weight.semiBold,
                                color: colors.text.highEmphasis,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdded) ...[
                        SizedBox(width: tokens.spacing.step3),
                        // Success tone separates the installed STATUS from the
                        // secondary-tone capability chips below it.
                        DesignSystemBadge.filled(
                          label: messages.aiSettingsAddedLabel,
                          tone: DesignSystemBadgeTone.success,
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: tokens.spacing.step1),

                  // Monospace provider model id — the stable identifier, shown
                  // the same way as on the installed AiModelCard.
                  Text(
                    widget.knownModel.providerModelId,
                    style: monoMetaStyle(
                      tokens,
                      colors,
                      color: colors.text.mediumEmphasis,
                    ),
                    softWrap: true,
                  ),

                  if (widget.knownModel.description.isNotEmpty) ...[
                    SizedBox(height: tokens.spacing.step2),
                    Text(
                      widget.knownModel.description,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: colors.text.mediumEmphasis,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (capabilityLabels.isNotEmpty) ...[
                    SizedBox(height: tokens.spacing.step3),
                    Wrap(
                      spacing: tokens.spacing.step2,
                      runSpacing: tokens.spacing.step2,
                      children: [
                        for (final label in capabilityLabels)
                          DesignSystemBadge.filled(
                            label: label,
                            tone: DesignSystemBadgeTone.secondary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(width: tokens.spacing.step3),

            // Trailing control always answers "what next": add when the model
            // is not installed, remove (reversible) once it is.
            _TileTrailingAction(
              isAdded: isAdded,
              isBusy: isAdded ? _isRemoving : _isAdding,
              onAdd: _addModel,
              onRemove: _removeModel,
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular add / remove affordance on a catalog tile. Flat token-tinted
/// circle wrapped in an [IconButton] so it keeps the 48px Material hit area.
class _TileTrailingAction extends StatelessWidget {
  const _TileTrailingAction({
    required this.isAdded,
    required this.isBusy,
    required this.onAdd,
    required this.onRemove,
  });

  final bool isAdded;
  final bool isBusy;
  final Future<void> Function() onAdd;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final accent = colors.interactive.enabled;
    // The remove control reads as a quiet, neutral action; add stays accented.
    final tint = isAdded ? colors.text.mediumEmphasis : accent;

    return IconButton(
      onPressed: isBusy ? null : (isAdded ? onRemove : onAdd),
      tooltip: isAdded
          ? messages.aiSettingsRemoveModelTooltip
          : messages.aiSettingsAddModelTooltip,
      style: IconButton.styleFrom(padding: EdgeInsets.zero),
      icon: isBusy
          ? SizedBox(
              width: tokens.spacing.step6,
              height: tokens.spacing.step6,
              child: CircularProgressIndicator(strokeWidth: 2, color: tint),
            )
          : Container(
              width: tokens.spacing.step7,
              height: tokens.spacing.step7,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAdded ? Icons.remove_rounded : Icons.add_rounded,
                size: tokens.spacing.step5,
                color: tint,
              ),
            ),
    );
  }
}
