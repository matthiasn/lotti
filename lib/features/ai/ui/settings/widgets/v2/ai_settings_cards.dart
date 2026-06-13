import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

export 'package:lotti/features/ai/ui/settings/util/ai_provider_status.dart'
    show AiProviderCardStatus;
export 'package:lotti/features/ai/ui/settings/widgets/v2/ai_model_card.dart';
export 'package:lotti/features/ai/ui/settings/widgets/v2/ai_profile_card.dart';
export 'package:lotti/features/ai/ui/settings/widgets/v2/ai_provider_card.dart';

/// Small rounded square showing a provider-type icon in the provider
/// accent color over a tinted surface. Used as the leading badge on
/// provider cards, profile cards, and model rows — shared across the
/// three card libraries in this directory.
class AiProviderIconTile extends StatelessWidget {
  const AiProviderIconTile({
    required this.accent,
    required this.surface,
    required this.providerType,
    this.size,
    super.key,
  });

  final Color accent;
  final Color surface;
  final InferenceProviderType? providerType;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dim = size ?? tokens.spacing.step8;
    return Container(
      width: dim,
      height: dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Icon(
        aiProviderIcon(providerType),
        size: dim * 0.5,
        color: accent,
      ),
    );
  }
}
