import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/rating_question.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/ratings/data/rating_catalogs.dart';
import 'package:lotti/features/ratings/ui/rating_utils.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Read-only summary of a [RatingEntry], shown in the entry detail view.
///
/// Renders each dimension dynamically from stored metadata with a
/// fallback chain:
///   1. Stored `dimension.question` (captured at rating time)
///   2. Catalog lookup (if catalogId is registered)
///   3. Dimension `key` (last resort)
///
/// Displays an edit button to re-open the [RatingModal].
class RatingSummary extends StatelessWidget {
  const RatingSummary(this.ratingEntry, {super.key});

  final RatingEntry ratingEntry;

  @override
  Widget build(BuildContext context) {
    final data = ratingEntry.data;
    final messages = context.messages;
    final colorScheme = context.colorScheme;

    final tokens = context.designTokens;

    // Resolve catalog for label fallback (may be null for unknown catalogs)
    final catalog = ratingCatalogRegistry[data.catalogId]?.call(messages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final dim in data.dimensions)
          _buildDimensionRow(
            context,
            dim,
            catalog: catalog,
            colorScheme: colorScheme,
            messages: messages,
          ),

        // Note + edit on one baseline row: the free-text verdict fills the
        // left, the edit control sits at the trailing edge — so the pencil is
        // never orphaned in a dead band below the content.
        Row(
          children: [
            Expanded(
              child: (data.note != null && data.note!.isNotEmpty)
                  ? Text(
                      data.note!,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.edit_outlined,
                color: tokens.colors.text.mediumEmphasis,
              ),
              tooltip: messages.sessionRatingEditButton,
              onPressed: () => RatingModal.show(
                context,
                data.targetId,
                catalogId: data.catalogId,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDimensionRow(
    BuildContext context,
    RatingDimension dim, {
    required List<RatingQuestion>? catalog,
    required ColorScheme colorScheme,
    required AppLocalizations messages,
  }) {
    // Resolve label via fallback chain
    final label = resolveRatingLabel(dim, catalog);

    // Resolve inputType: stored first, then catalog lookup
    final inputType = resolveRatingInputType(dim, catalog);

    // Segmented: display as categorical text
    if (inputType == 'segmented') {
      final valueText = _resolveSegmentedLabel(
        dim,
        catalog: catalog,
        messages: messages,
      );

      if (valueText != null) {
        final tokens = context.designTokens;
        // Label and answer inline (quiet label + bold value) — not flung to
        // opposite edges — so the eye keeps them as one pair.
        return Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(label, style: _labelStyle(tokens))),
              SizedBox(width: tokens.spacing.step2),
              Text(valueText, style: _valueStyle(tokens)),
            ],
          ),
        );
      }
    }

    // Default: progress bar
    return _DimensionRow(
      label: label,
      value: dim.value,
      color: colorScheme.primary,
    );
  }
}

TextStyle _labelStyle(DsTokens tokens) =>
    tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

TextStyle _valueStyle(DsTokens tokens) =>
    tokens.typography.styles.subtitle.subtitle1.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Resolves the inputType for a dimension using the fallback chain:
/// stored inputType → catalog lookup → null (defaults to progress bar).
@visibleForTesting
String? resolveRatingInputType(
  RatingDimension dim,
  List<RatingQuestion>? catalog,
) {
  // 1. Stored inputType
  if (dim.inputType != null) return dim.inputType;

  // 2. Catalog lookup
  if (catalog != null) {
    for (final q in catalog) {
      if (q.key == dim.key) return q.inputType;
    }
  }

  return null;
}

/// Resolves the display label for a dimension using the fallback chain:
/// stored question → catalog lookup → dimension key.
@visibleForTesting
String resolveRatingLabel(
  RatingDimension dim,
  List<RatingQuestion>? catalog,
) {
  // 1. Stored question (captured at rating time)
  if (dim.question != null) return dim.question!;

  // 2. Catalog lookup
  if (catalog != null) {
    for (final q in catalog) {
      if (q.key == dim.key) return q.question;
    }
  }

  // 3. Dimension key as last resort
  return dim.key;
}

/// Resolves the display text for a segmented dimension value.
///
/// Tries stored optionLabels first, then catalog lookup, then returns null
/// to fall back to progress bar rendering.
String? _resolveSegmentedLabel(
  RatingDimension dim, {
  required List<RatingQuestion>? catalog,
  required AppLocalizations messages,
}) {
  // Try stored option labels (with stored values if available)
  if (dim.optionLabels != null && dim.optionLabels!.isNotEmpty) {
    return findOptionLabel(
      dim.value,
      dim.optionLabels!,
      values: dim.optionValues,
    );
  }

  // Try catalog lookup
  if (catalog != null) {
    for (final q in catalog) {
      if (q.key == dim.key && q.options != null) {
        for (final opt in q.options!) {
          if ((opt.value - dim.value).abs() < 0.01) {
            return opt.label;
          }
        }
      }
    }
  }

  return null;
}

/// A single dimension displayed as label + [LinearProgressIndicator].
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final percent = (value.clamp(0.0, 1.0) * 100).round();
    // Tight label→bar coupling (step1) inside a larger between-row gap
    // (cardItemSpacing) so each question + bar reads as one grouped unit.
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: _labelStyle(tokens))),
              // The numeric value next to the bar, so the score is not encoded
              // by bar length / colour alone (low-vision + clarity).
              Text('$percent%', style: _valueStyle(tokens)),
            ],
          ),
          SizedBox(height: tokens.spacing.step1),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.xs),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: context.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: tokens.spacing.step3,
            ),
          ),
        ],
      ),
    );
  }
}
