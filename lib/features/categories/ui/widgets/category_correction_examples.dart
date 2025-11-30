import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Warning threshold for number of correction examples (token budget concern).
/// Shows a warning when this threshold is exceeded.
const int kCorrectionExamplesWarningThreshold = 400;

/// Maximum examples that will be used in AI prompts.
/// Storage remains unbounded, but only this many are injected.
const int kMaxCorrectionExamplesForPrompt = 500;

/// A widget for displaying and managing checklist correction examples.
///
/// This widget displays a read-only list of correction examples with:
/// - Warning banner when threshold is exceeded
/// - Swipe-to-delete for individual examples
/// - Empty state message when no examples exist
///
/// Note: Deletions update the pending state but are NOT auto-persisted.
/// The user must tap the Save button to persist changes. This matches
/// the speech dictionary and other category settings behavior.
class CategoryCorrectionExamples extends StatelessWidget {
  const CategoryCorrectionExamples({
    required this.examples,
    required this.onDelete,
    super.key,
  });

  /// The current correction examples, or null if empty.
  final List<ChecklistCorrectionExample>? examples;

  /// Called when an example should be deleted.
  /// The parent should update state and enable the Save button.
  final ValueChanged<ChecklistCorrectionExample> onDelete;

  @override
  Widget build(BuildContext context) {
    final examplesList = examples ?? [];
    final count = examplesList.length;
    final showWarning = count > kCorrectionExamplesWarningThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          context.messages.correctionExamplesSectionTitle,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.messages.correctionExamplesSectionDescription,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // Warning banner if threshold exceeded
        if (showWarning) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.correctionExamplesWarning(
                      count,
                      kMaxCorrectionExamplesForPrompt,
                    ),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Examples list or empty state
        if (examplesList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: context.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.messages.correctionExamplesEmpty,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // List of examples with swipe-to-delete
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: context.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: examplesList.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: context.colorScheme.outline.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) {
                  final example = examplesList[index];
                  return _CorrectionExampleTile(
                    example: example,
                    onDelete: () => onDelete(example),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _CorrectionExampleTile extends StatelessWidget {
  const _CorrectionExampleTile({
    required this.example,
    required this.onDelete,
  });

  final ChecklistCorrectionExample example;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMd().add_jm();
    final capturedAtText = example.capturedAt != null
        ? dateFormat.format(example.capturedAt!)
        : null;

    return Dismissible(
      key: ValueKey('${example.before}-${example.after}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: context.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: context.colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Before -> After
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: context.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: '"${example.before}"',
                          style: TextStyle(
                            color: context.colorScheme.error
                                .withValues(alpha: 0.8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        TextSpan(
                          text: ' → ',
                          style: TextStyle(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: '"${example.after}"',
                          style: TextStyle(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Captured date (if available)
            if (capturedAtText != null) ...[
              const SizedBox(height: 4),
              Text(
                capturedAtText,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
