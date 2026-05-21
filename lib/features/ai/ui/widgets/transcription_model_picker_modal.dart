import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Bottom-sheet picker for choosing which model handles one
/// transcription run, overriding the inference profile's slot for
/// that single invocation. Default model is rendered first with a
/// "(default)" badge and a check; alternatives below are tappable
/// just the same — one tap on any row resolves the modal with that
/// model's id.
///
/// When the user has zero or one speech-capable model configured the
/// picker is degenerate (no choice to make), so [show] short-circuits
/// and returns either the lone model id or null without rendering the
/// modal. This keeps the "1 click for default" promise in the common
/// single-model setup.
class TranscriptionModelPickerModal extends StatelessWidget {
  const TranscriptionModelPickerModal({
    required this.defaultModelId,
    required this.speechCapableModels,
    super.key,
  });

  /// The model id the active profile points to for this entry — used
  /// to mark which row is the default. May be `null` if the profile's
  /// transcription slot is empty or points to a deleted model; in
  /// that case no row gets the badge.
  final String? defaultModelId;

  /// Every model the user has configured whose `inputModalities`
  /// includes [Modality.audio]. The caller filters; the modal trusts
  /// the list.
  final List<AiConfigModel> speechCapableModels;

  /// Opens the picker and resolves with the chosen model's id. Three
  /// shapes for the return value:
  ///
  ///   - `String` non-null  — the user picked a model (including
  ///     tapping the default).
  ///   - `null`             — the user dismissed the sheet (close X,
  ///     swipe, barrier tap, back nav).
  ///   - short-circuit      — when [speechCapableModels] has 0 or 1
  ///     entries the modal is not shown; the function returns
  ///     immediately with the lone model id (or null if empty). This
  ///     guarantees the popup-menu transcribe flow stays one-tap on
  ///     setups with a single speech-capable model.
  static Future<String?> show({
    required BuildContext context,
    required String? defaultModelId,
    required List<AiConfigModel> speechCapableModels,
  }) async {
    if (speechCapableModels.isEmpty) return null;
    if (speechCapableModels.length == 1) {
      return speechCapableModels.first.id;
    }
    return ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.aiTranscriptionPickerTitle,
      builder: (_) => TranscriptionModelPickerModal(
        defaultModelId: defaultModelId,
        speechCapableModels: speechCapableModels,
      ),
    );
  }

  /// Splits the list so the default appears first when it exists in
  /// [speechCapableModels]. When the default is missing (stale id /
  /// no profile slot) the list renders as-is, with no row marked.
  List<AiConfigModel> _orderedModels() {
    final defaultId = defaultModelId;
    if (defaultId == null) return speechCapableModels;
    final defaultModel = speechCapableModels
        .where((m) => m.id == defaultId)
        .firstOrNull;
    if (defaultModel == null) return speechCapableModels;
    return [
      defaultModel,
      ...speechCapableModels.where((m) => m.id != defaultId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ordered = _orderedModels();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.spacing.step3),
            _ModelRow(
              model: ordered[i],
              isDefault: ordered[i].id == defaultModelId,
              onTap: () => Navigator.of(context).pop(ordered[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.isDefault,
    required this.onTap,
  });

  final AiConfigModel model;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final radius = BorderRadius.circular(tokens.radii.l);
    final borderColor = isDefault
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
        : tokens.colors.decorative.level01;
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: radius,
          border: Border.all(color: borderColor),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: tokens.spacing.step3,
                        runSpacing: tokens.spacing.step1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            model.name,
                            style: tokens.typography.styles.subtitle.subtitle1
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                  fontWeight: tokens.typography.weight.semiBold,
                                ),
                          ),
                          if (isDefault)
                            DesignSystemBadge.filled(
                              label: messages.aiTranscriptionPickerDefaultBadge,
                            ),
                        ],
                      ),
                      if (model.providerModelId.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          model.providerModelId,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                if (isDefault)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: tokens.spacing.step6,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
