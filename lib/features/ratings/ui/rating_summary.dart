import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/rating_question.dart';
import 'package:lotti/features/ratings/data/rating_catalogs.dart';
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

    // Resolve catalog for label fallback (may be null for unknown catalogs)
    final catalog = ratingCatalogRegistry[data.catalogId]?.call(messages);

    return Padding(
      padding: const EdgeInsets.only(
        top: AppTheme.spacingSmall,
        bottom: AppTheme.spacingMedium,
      ),
      child: Column(
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

          // Note
          if (data.note != null && data.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
              child: Text(
                data.note!,
                style: context.textTheme.bodyMedium,
              ),
            ),

          // Edit button (only for known catalogs)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: messages.sessionRatingEditButton,
              onPressed: () => RatingModal.show(
                context,
                data.targetId,
                catalogId: data.catalogId,
              ),
            ),
          ),
        ],
      ),
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
    final label = _resolveLabel(dim, catalog);

    // Resolve inputType: stored first, then catalog lookup
    final inputType = _resolveInputType(dim, catalog);

    // Segmented: display as categorical text
    if (inputType == 'segmented') {
      final valueText = _resolveSegmentedLabel(
        dim,
        catalog: catalog,
        messages: messages,
      );

      if (valueText != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                valueText,
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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

/// Resolves the inputType for a dimension using the fallback chain:
/// stored inputType → catalog lookup → null (defaults to progress bar).
String? _resolveInputType(
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
String _resolveLabel(
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
  // Try stored option labels
  if (dim.optionLabels != null && dim.optionLabels!.isNotEmpty) {
    return _findOptionLabel(dim.value, dim.optionLabels!);
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

/// Maps a normalized value to the closest option label, assuming evenly
/// spaced values across 0.0-1.0 (e.g. 3 options → 0.0, 0.5, 1.0).
String _findOptionLabel(double value, List<String> labels) {
  final count = labels.length;
  for (var i = 0; i < count; i++) {
    final expectedValue = count == 1 ? 0.5 : i / (count - 1);
    if ((expectedValue - value).abs() < 0.01) {
      return labels[i];
    }
  }
  return '${(value * 100).round()}%';
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: context.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
