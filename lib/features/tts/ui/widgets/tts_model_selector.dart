import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Selectable list of the available TTS models. Each row shows the model name,
/// a "Recommended" badge for the default, and a "Downloads once" hint (the
/// model is fetched from Hugging Face on first use). ≥44pt targets; the active
/// model carries a leading accent check + selected semantics.
class TtsModelSelector extends StatelessWidget {
  const TtsModelSelector({
    required this.modelId,
    required this.onChanged,
    this.models = kTtsModels,
    super.key,
  });

  final String modelId;
  final ValueChanged<String> onChanged;

  /// The selectable models. Defaults to the shipped catalog; injectable so
  /// the single-choice vs. multiple-choice badge behaviour is testable.
  final List<TtsModelOption> models;

  @override
  Widget build(BuildContext context) {
    // A "Recommended" badge only carries meaning when there's an actual
    // choice to recommend against. With a single model it's pure noise, so
    // we suppress it until a second model exists.
    final hasChoice = models.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final model in models)
          _ModelRow(
            model: model,
            selected: model.id == modelId,
            showRecommended: hasChoice && model.recommended,
            onTap: () => onChanged(model.id),
          ),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.selected,
    required this.showRecommended,
    required this.onTap,
  });

  final TtsModelOption model;
  final bool selected;
  final bool showRecommended;
  final VoidCallback onTap;

  static const double _minTarget = 44;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radii.s),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minTarget),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step2),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 20,
                      color: selected
                          ? ai.accent
                          : tokens.colors.text.lowEmphasis,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  model.displayName,
                                  style: tokens
                                      .typography
                                      .styles
                                      .body
                                      .bodyMedium
                                      .copyWith(
                                        color: tokens.colors.text.highEmphasis,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              if (showRecommended) ...[
                                SizedBox(width: tokens.spacing.step2),
                                _RecommendedBadge(),
                              ],
                            ],
                          ),
                          Text(
                            context.messages.speechSettingsModelDownloadsOnce,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: ai.accentSoft,
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        context.messages.speechSettingsRecommendedBadge,
        style: tokens.typography.styles.others.caption.copyWith(
          color: ai.accent,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
