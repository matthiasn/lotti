import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Generic bottom-sheet picker for choosing which model handles one
/// per-invocation inference run, overriding the inference profile's
/// slot for that single call. Used today by the transcription and
/// image-analysis popup paths; future per-slot overrides plug in the
/// same way by passing the relevant pre-filtered model list and the
/// localised title + default-badge strings.
///
/// Default model is rendered first with the supplied badge and a
/// check; alternatives below are tappable just the same — one tap on
/// any row resolves the modal with that model's id.
///
/// When the caller passes zero or one model the picker is degenerate
/// (no choice to make), so [show] short-circuits and returns either
/// the lone model id or null without rendering the modal. This keeps
/// the "1 click for default" promise in the common single-model
/// setup.
class InferenceModelPickerModal extends StatelessWidget {
  const InferenceModelPickerModal({
    required this.defaultModelId,
    required this.models,
    required this.defaultBadgeLabel,
    super.key,
  });

  /// The model id the active profile points to for this entry — used
  /// to mark which row is the default. May be `null` if the profile's
  /// slot is empty or points to a deleted model; in that case no row
  /// gets the badge.
  final String? defaultModelId;

  /// Every model the caller wants the user to be able to pick. The
  /// caller filters by modality + slot; the modal trusts the list.
  final List<AiConfigModel> models;

  /// Localised label for the "(default)" badge. Passed in rather than
  /// read from l10n keys so the same picker serves any slot kind that
  /// has its own badge string.
  final String defaultBadgeLabel;

  /// Opens the picker and resolves with the chosen model's id. Three
  /// shapes for the return value:
  ///
  ///   - `String` non-null  — the user picked a model (including
  ///     tapping the default).
  ///   - `null`             — the user dismissed the sheet (close X,
  ///     swipe, barrier tap, back nav).
  ///   - short-circuit      — when [models] has 0 or 1 entries the
  ///     modal is not shown; the function returns immediately with
  ///     the lone model id (or null if empty). This guarantees the
  ///     popup-menu flow stays one-tap on setups with a single
  ///     slot-capable model.
  static Future<String?> show({
    required BuildContext context,
    required String? defaultModelId,
    required List<AiConfigModel> models,
    required String title,
    required String defaultBadgeLabel,
  }) async {
    if (models.isEmpty) return null;
    if (models.length == 1) return models.first.id;
    return ModalUtils.showSinglePageModal<String>(
      context: context,
      title: title,
      builder: (_) => InferenceModelPickerModal(
        defaultModelId: defaultModelId,
        models: models,
        defaultBadgeLabel: defaultBadgeLabel,
      ),
    );
  }

  /// Splits the list so the default appears first when it exists in
  /// [models]. When the default is missing (stale id / no profile
  /// slot) the list renders as-is, with no row marked.
  ///
  /// Pure ordering function (no `BuildContext`, no instance state) so it
  /// can be property-tested directly. Invariants: the multiset of
  /// elements is preserved; if [defaultModelId] matches an element, that
  /// element is at index 0 and the rest keep their original relative
  /// order; otherwise the list is returned unchanged.
  @visibleForTesting
  static List<AiConfigModel> orderModels(
    List<AiConfigModel> models,
    String? defaultModelId,
  ) {
    if (defaultModelId == null) return models;
    final defaultModel = models
        .where((m) => m.id == defaultModelId)
        .firstOrNull;
    if (defaultModel == null) return models;
    return [
      defaultModel,
      ...models.where((m) => m.id != defaultModelId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ordered = orderModels(models, defaultModelId);
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
              defaultBadgeLabel: defaultBadgeLabel,
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
    required this.defaultBadgeLabel,
    required this.onTap,
  });

  final AiConfigModel model;
  final bool isDefault;
  final String defaultBadgeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
                            DesignSystemBadge.filled(label: defaultBadgeLabel),
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
