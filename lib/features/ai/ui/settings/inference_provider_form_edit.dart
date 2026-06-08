part of 'inference_provider_edit_page.dart';

// Edit-mode form widgets: provider type, available models, AI setup.

/// Read-only field used to surface the currently-selected provider type
/// inside the form. Tapping anywhere on the field opens the provider
/// type modal. Implemented as a styled box (no `TextEditingController`)
/// so we don't allocate a new controller per build the way an
/// `AbsorbPointer(AiTextField(...))` pattern would.
class _ProviderTypeField extends StatelessWidget {
  const _ProviderTypeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
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

class _EmbeddedProviderHint extends StatelessWidget {
  const _EmbeddedProviderHint({required this.providerType});

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
class _AvailableModelsSection extends ConsumerWidget {
  const _AvailableModelsSection({
    required this.providerId,
    required this.providerType,
  });

  final String providerId;
  final InferenceProviderType providerType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final knownModels = knownModelsByProvider[providerType] ?? [];

    if (knownModels.isEmpty) {
      return const SizedBox.shrink();
    }

    // Watch all configured models to check which are already added
    final allModelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );

    return allModelsAsync.when(
      data: (allModels) {
        // Get models already configured for this provider
        final existingModelIds = allModels
            .whereType<AiConfigModel>()
            .where((m) => m.inferenceProviderId == providerId)
            .map((m) => m.providerModelId)
            .toSet();

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
                  final isAdded = existingModelIds.contains(
                    knownModel.providerModelId,
                  );
                  return Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.step4),
                    child: _KnownModelTile(
                      knownModel: knownModel,
                      providerId: providerId,
                      isAdded: isAdded,
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

/// Tile displaying a known model with an add button or "Added" indicator.
class _KnownModelTile extends ConsumerStatefulWidget {
  const _KnownModelTile({
    required this.knownModel,
    required this.providerId,
    required this.isAdded,
  });

  final KnownModel knownModel;
  final String providerId;
  final bool isAdded;

  @override
  ConsumerState<_KnownModelTile> createState() => _KnownModelTileState();
}

class _KnownModelTileState extends ConsumerState<_KnownModelTile> {
  bool _isAdding = false;

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
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  IconData _getModelIcon() {
    // Check for image generation capability
    if (widget.knownModel.outputModalities.contains(Modality.image)) {
      return Icons.palette_rounded;
    }
    // Check for audio input (transcription)
    if (widget.knownModel.inputModalities.contains(Modality.audio)) {
      return Icons.mic_rounded;
    }
    // Reasoning model
    if (widget.knownModel.isReasoningModel) {
      return Icons.psychology_alt_rounded;
    }
    // Default
    return Icons.smart_toy_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final inputModalities = widget.knownModel.inputModalities
        .map((m) => m.displayName(context))
        .join(', ');
    final outputModalities = widget.knownModel.outputModalities
        .map((m) => m.displayName(context))
        .join(', ');

    return Container(
      decoration: BoxDecoration(
        color: widget.isAdded
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.1)
            : context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: widget.isAdded
              ? context.colorScheme.primary.withValues(alpha: 0.3)
              : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model icon
            Container(
              width: tokens.spacing.step8,
              height: tokens.spacing.step8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isAdded
                      ? [
                          context.colorScheme.primary.withValues(alpha: 0.2),
                          context.colorScheme.primary.withValues(alpha: 0.1),
                        ]
                      : [
                          context.colorScheme.surfaceContainerHighest,
                          context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.7),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(
                _getModelIcon(),
                size: tokens.spacing.step6,
                color: widget.isAdded
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),

            SizedBox(width: tokens.spacing.step4),

            // Model info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.knownModel.name,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                fontWeight: tokens.typography.weight.semiBold,
                                color: context.colorScheme.onSurface,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isAdded) ...[
                        SizedBox(width: tokens.spacing.step3),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.step3,
                            vertical: tokens.spacing.step1,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primary,
                            borderRadius: BorderRadius.circular(tokens.radii.s),
                          ),
                          child: Text(
                            messages.aiSettingsAddedLabel,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: context.colorScheme.onPrimary,
                                  fontWeight: tokens.typography.weight.semiBold,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: tokens.spacing.step2),

                  // Description
                  Text(
                    widget.knownModel.description,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: tokens.spacing.step3),

                  // Modalities
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step2,
                    children: [
                      _ModalityChip(
                        label: messages.apiKeyKnownModelInputLabel(
                          inputModalities,
                        ),
                        icon: Icons.input_rounded,
                      ),
                      _ModalityChip(
                        label: messages.apiKeyKnownModelOutputLabel(
                          outputModalities,
                        ),
                        icon: Icons.output_rounded,
                      ),
                      if (widget.knownModel.isReasoningModel)
                        _ModalityChip(
                          label: messages.aiSettingsReasoningLabel,
                          icon: Icons.psychology_alt_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: tokens.spacing.step3),

            // Add button
            if (!widget.isAdded)
              IconButton(
                onPressed: _isAdding ? null : _addModel,
                icon: _isAdding
                    ? SizedBox(
                        width: tokens.spacing.step6,
                        height: tokens.spacing.step6,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colorScheme.primary,
                        ),
                      )
                    : Container(
                        width: tokens.spacing.step7,
                        height: tokens.spacing.step7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colorScheme.primaryContainer,
                              context.colorScheme.primaryContainer.withValues(
                                alpha: 0.7,
                              ),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: tokens.spacing.step3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: tokens.spacing.step5,
                          color: context.colorScheme.primary,
                        ),
                      ),
                tooltip: messages.aiSettingsAddModelTooltip,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
