import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_status.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_card_action_menu.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

export 'package:lotti/features/ai/ui/settings/util/ai_provider_status.dart'
    show AiProviderCardStatus;

part 'ai_provider_card.dart';
part 'ai_model_card.dart';
part 'ai_profile_card.dart';

class _ProviderIconTile extends StatelessWidget {
  const _ProviderIconTile({
    required this.accent,
    required this.surface,
    required this.providerType,
    this.size,
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

/// Status row below the divider on a provider card. Left side: status
/// dot + label. Right side: secondary meta — model count + optional
/// "last used" for connected, the inline Fix link for invalid-key,
/// the Ollama-running hint for offline.
