import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/rating_question.dart';
import 'package:lotti/features/ratings/data/rating_catalogs.dart';
import 'package:lotti/features/ratings/state/rating_controller.dart';
import 'package:lotti/features/ratings/ui/rating_input_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Modal bottom sheet for rating any entity using a catalog-driven
/// question set.
///
/// Resolves the [catalogId] against [ratingCatalogRegistry] to determine
/// which questions to show. If the catalog is unknown (e.g. received via
/// sync from a newer client), the modal renders stored dimensions in
/// read-only mode without a save button.
class RatingModal extends ConsumerStatefulWidget {
  const RatingModal({
    required this.targetId,
    this.catalogId = 'session',
    super.key,
  });

  final String targetId;
  final String catalogId;

  static Future<void> show(
    BuildContext context,
    String targetId, {
    String catalogId = 'session',
    VoidCallback? onDismissed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      backgroundColor: colorScheme.surfaceContainerHigh,
      builder: (context) => RatingModal(
        targetId: targetId,
        catalogId: catalogId,
      ),
    ).whenComplete(() => onDismissed?.call());
  }

  @override
  ConsumerState<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends ConsumerState<RatingModal> {
  final Map<String, double?> _answers = {};
  late TextEditingController _noteController;
  bool _isSubmitting = false;
  bool _didPrePopulate = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _prePopulate(JournalEntity? existing) {
    if (_didPrePopulate || existing is! RatingEntry) return;
    _didPrePopulate = true;
    for (final dim in existing.data.dimensions) {
      _answers[dim.key] = dim.value;
    }
    if (existing.data.note != null) {
      _noteController.text = existing.data.note!;
    }
  }

  bool _canSubmit(List<RatingQuestion> catalog) {
    if (catalog.isEmpty) return false;
    return catalog.every((q) => _answers[q.key] != null);
  }

  Future<void> _submit() async {
    final messages = context.messages;
    final catalog = ratingCatalogRegistry[widget.catalogId]?.call(messages);
    if (catalog == null || _isSubmitting) return;
    if (!_canSubmit(catalog)) return;

    setState(() => _isSubmitting = true);

    try {
      final dimensions = catalog.map((question) {
        return RatingDimension(
          key: question.key,
          value: _answers[question.key]!,
          question: question.question,
          description: question.description,
          inputType: question.inputType,
          optionLabels: question.options?.map((o) => o.label).toList(),
          optionValues: question.options?.map((o) => o.value).toList(),
        );
      }).toList();

      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      final result = await ref
          .read(
            ratingControllerProvider(
              targetId: widget.targetId,
              catalogId: widget.catalogId,
            ).notifier,
          )
          .submitRating(dimensions, note: note);

      if (!mounted) return;

      if (result != null) {
        final navigator = Navigator.of(context);
        await HapticFeedback.heavyImpact();
        navigator.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.sessionRatingSaveError),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref
        .watch(ratingControllerProvider(
          targetId: widget.targetId,
          catalogId: widget.catalogId,
        ))
        .whenData(_prePopulate);

    final messages = context.messages;
    final catalog = ratingCatalogRegistry[widget.catalogId]?.call(messages);

    if (catalog == null) {
      return _buildReadOnlyView(context);
    }

    return _buildEditableView(context, catalog);
  }

  Widget _buildEditableView(
    BuildContext context,
    List<RatingQuestion> catalog,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dragHandle(context),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              context.messages.sessionRatingTitle,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic questions from catalog
            for (final question in catalog) ...[
              if (question.inputType == 'segmented' && question.options != null)
                RatingSegmentedInput(
                  label: question.question,
                  segments: [
                    for (final opt in question.options!)
                      (label: opt.label, value: opt.value),
                  ],
                  value: _answers[question.key],
                  onChanged: (v) => setState(() => _answers[question.key] = v),
                )
              else
                _buildTapBarRow(question),
              const SizedBox(height: AppTheme.spacingLarge),
            ],

            // Note field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: context.messages.sessionRatingNoteHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _close,
                    child: Text(context.messages.sessionRatingSkipButton),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _canSubmit(catalog) && !_isSubmitting ? _submit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.messages.sessionRatingSaveButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildTapBarRow(RatingQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.question,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        RatingTapBar(
          value: _answers[question.key],
          onChanged: (v) => setState(() => _answers[question.key] = v),
        ),
      ],
    );
  }

  /// Renders stored dimensions in read-only mode when the catalog is
  /// unknown. No save button — only a close button.
  Widget _buildReadOnlyView(BuildContext context) {
    final existing = ref
        .watch(ratingControllerProvider(
          targetId: widget.targetId,
          catalogId: widget.catalogId,
        ))
        .value;

    final dimensions = existing is RatingEntry
        ? existing.data.dimensions
        : <RatingDimension>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dragHandle(context),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              widget.catalogId,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Show each stored dimension read-only
            for (final dim in dimensions) ...[
              _ReadOnlyDimensionRow(dimension: dim),
              const SizedBox(height: AppTheme.spacingSmall),
            ],

            // Note
            if (existing is RatingEntry &&
                existing.data.note != null &&
                existing.data.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
                child: Text(
                  existing.data.note!,
                  style: context.textTheme.bodyMedium,
                ),
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _close,
                child: Text(context.messages.sessionRatingSkipButton),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
          ],
        ),
      ),
    );
  }

  Widget _dragHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A single dimension displayed read-only with its stored label and value.
class _ReadOnlyDimensionRow extends StatelessWidget {
  const _ReadOnlyDimensionRow({required this.dimension});

  final RatingDimension dimension;

  @override
  Widget build(BuildContext context) {
    final label = dimension.question ?? dimension.key;
    final colorScheme = context.colorScheme;

    // Segmented: show matching option label as text
    if (dimension.inputType == 'segmented' && dimension.optionLabels != null) {
      final optionText = _findOptionLabel(
        dimension.value,
        dimension.optionLabels!,
        values: dimension.optionValues,
      );

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
              optionText,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Default: progress bar
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: dimension.value.clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps a normalized value to the closest option label.
///
/// When [values] is provided, uses the actual stored values for matching.
/// Otherwise falls back to assuming evenly spaced values across 0.0-1.0
/// (e.g. 3 options → 0.0, 0.5, 1.0) for old data without stored values.
String _findOptionLabel(
  double value,
  List<String> labels, {
  List<double>? values,
}) {
  final count = labels.length;
  for (var i = 0; i < count; i++) {
    final expectedValue = values != null && i < values.length
        ? values[i]
        : (count == 1 ? 0.5 : i / (count - 1));
    if ((expectedValue - value).abs() < 0.01) {
      return labels[i];
    }
  }
  return '${(value * 100).round()}%';
}
