import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/rating_question.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/helpers.dart';
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

        // Note + edit on one row, left-grouped so the edit pencil sits right
        // next to the note instead of stranded at the far edge. The last rating
        // row already carries the inter-block gap, so NO extra leading space is
        // added here (an extra step on top doubled the gap above the note and
        // made it read as an orphaned second headline). The verdict is a quiet
        // caption (medium-emphasis), not a bold white headline.
        Row(
          children: [
            if (data.note != null && data.note!.isNotEmpty) ...[
              Flexible(
                child: Text(
                  data.note!,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              // A clear gap so the edit target is not flush against the note
              // text (a mis-tap hazard for imprecise taps).
              SizedBox(width: tokens.spacing.step3),
            ],
            // Full 48px tap target (no compact density) so the edit affordance
            // is comfortably tappable and reads as a real control.
            IconButton(
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
            const Spacer(),
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
        // Render through the shared value-line widget so the categorical answer
        // parses with the exact same "quiet Label: bold value" colon grammar as
        // every other card (Duration:, Weight:, Coverage:) — the prompt's
        // trailing ellipsis is stripped so "This work felt…" reads as
        // "This work felt: Just right".
        return Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
          child: EntryTextWidget(
            '${_stripTrailingPunctuation(label)}: $valueText',
            padding: EdgeInsets.zero,
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

/// Strips trailing sentence punctuation (ellipsis, period, question/exclamation
/// mark) from a rating prompt so a statement- or question-style label joins the
/// colon value-line grammar cleanly — "This work felt…" becomes "This work felt"
/// and "How did the work feel?" becomes "How did the work feel" before the
/// ": value" is appended.
String _stripTrailingPunctuation(String label) {
  var out = label.trimRight();
  while (out.isNotEmpty &&
      (out.endsWith('…') ||
          out.endsWith('.') ||
          out.endsWith('?') ||
          out.endsWith('!'))) {
    out = out.substring(0, out.length - 1).trimRight();
  }
  return out;
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
