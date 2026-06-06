part of 'ai_settings_cards.dart';

class AiProfileCard extends StatelessWidget {
  const AiProfileCard({
    required this.profile,
    required this.isActive,
    required this.providerTypeFor,
    required this.modelLookup,
    required this.onTap,
    this.menuActions = const [],
    super.key,
  });

  final AiConfigInferenceProfile profile;
  final bool isActive;

  /// Resolves the inference provider type that owns this profile, so
  /// the card can color its leading icon. The page wires this from a
  /// providerId → type map built from the providers list. May return
  /// null when none of the profile's skill slots reference a known
  /// model row — the card renders neutral chrome in that case.
  final InferenceProviderType? Function() providerTypeFor;

  /// Resolves a `providerModelId` to its display name. Returns null
  /// when the id doesn't match any known model row — those slots
  /// render in the warning tone so the user can spot dangling
  /// references.
  final String? Function(String providerModelId) modelLookup;

  final VoidCallback onTap;
  final List<AiCardMenuAction> menuActions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Resolve once — providerTypeFor walks four model slots, no point
    // re-running it for the header icon after the visual bundle.
    final providerType = providerTypeFor();
    final visual = aiProviderVisual(
      type: providerType,
      tokens: tokens,
      messages: messages,
    );
    final radius = BorderRadius.circular(tokens.radii.l);
    // The icon tile dimension matches the default `_ProviderIconTile`
    // size. Indenting the description by exactly this column + the
    // header gap keeps the description flush with the profile name
    // without hardcoding token-arithmetic literals further down.
    final iconColumn = tokens.spacing.step8;
    final iconGap = tokens.spacing.step3;

    final slots = <_ProfileSlot>[
      _ProfileSlot(
        icon: Icons.psychology_rounded,
        label: messages.aiCapabilityChipThinking,
        modelId: profile.thinkingModelId,
      ),
      _ProfileSlot(
        icon: Icons.image_outlined,
        label: messages.aiCapabilityChipImageRecognition,
        modelId: profile.imageRecognitionModelId,
      ),
      _ProfileSlot(
        icon: Icons.mic_none_rounded,
        label: messages.aiCapabilityChipTranscription,
        modelId: profile.transcriptionModelId,
      ),
      _ProfileSlot(
        icon: Icons.brush_outlined,
        label: messages.aiCapabilityChipImageGeneration,
        modelId: profile.imageGenerationModelId,
      ),
    ];

    final description = profile.description;
    final hasDescription = description != null && description.isNotEmpty;

    return Material(
      color: tokens.colors.background.level02,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: tokens.colors.surface.hover,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ProviderIconTile(
                    accent: visual.accent,
                    surface: visual.surface,
                    providerType: providerType,
                  ),
                  SizedBox(width: iconGap),
                  // `Expanded` (instead of `Flexible + Spacer`) claims
                  // every pixel between the icon and the trailing
                  // menu, so the `⋯` always pins to the card's right
                  // edge — matching the provider card and avoiding
                  // the "menu floats next to a long name" look.
                  Expanded(
                    child: Text(
                      profile.name,
                      style: tokens.typography.styles.subtitle.subtitle1
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          ),
                      softWrap: true,
                    ),
                  ),
                  if (isActive) ...[
                    SizedBox(width: tokens.spacing.step2),
                    DesignSystemBadge.filled(
                      label: messages.aiProfileCardActiveBadge,
                      tone: DesignSystemBadgeTone.success,
                    ),
                  ],
                  AiCardActionMenuButton(actions: menuActions),
                ],
              ),
              if (hasDescription) ...[
                SizedBox(height: tokens.spacing.step1),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: iconColumn + iconGap,
                  ),
                  child: Text(
                    description,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
              SizedBox(height: tokens.spacing.step3),
              for (final slot in slots)
                if (slot.modelId case final modelId? when modelId.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.step2),
                    child: _ProfileSlotRow(
                      slot: slot,
                      modelName: modelLookup(modelId),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSlot {
  const _ProfileSlot({
    required this.icon,
    required this.label,
    required this.modelId,
  });

  final IconData icon;
  final String label;
  final String? modelId;
}

class _ProfileSlotRow extends StatelessWidget {
  const _ProfileSlotRow({required this.slot, required this.modelName});

  final _ProfileSlot slot;
  final String? modelName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final resolved = modelName ?? messages.aiProfileSlotModelMissing;
    final caption = tokens.typography.styles.others.caption;
    return Row(
      // Top-align so the icon + slot label stay flush with the first
      // line of a wrapped model name on mobile widths.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(slot.icon, size: 14, color: tokens.colors.text.mediumEmphasis),
        SizedBox(width: tokens.spacing.step2),
        Text(
          slot.label,
          style: caption.copyWith(color: tokens.colors.text.mediumEmphasis),
        ),
        SizedBox(width: tokens.spacing.step2),
        Icon(
          Icons.arrow_forward_rounded,
          size: 12,
          color: tokens.colors.text.lowEmphasis,
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Text(
            resolved,
            style: caption.copyWith(
              color: modelName == null
                  ? tokens.colors.alert.warning.defaultColor
                  : tokens.colors.text.highEmphasis,
              fontWeight: tokens.typography.weight.semiBold,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

// `modelCapabilityLabels` lives in `ai_provider_visual.dart` so the
// FTUE preview modal and the redesigned Models tab share one source
// of truth for the capability-chip labelling.
