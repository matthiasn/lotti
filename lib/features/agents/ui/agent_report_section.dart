import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// Displays the contents of an agent report.
///
/// Renders title, TLDR, status/priority badges, achieved/remaining item lists,
/// checklist progress, learnings, and last-updated timestamp. Missing fields
/// are handled gracefully by not rendering the corresponding section.
class AgentReportSection extends StatelessWidget {
  const AgentReportSection({
    required this.content,
    super.key,
  });

  final Map<String, Object?> content;

  @override
  Widget build(BuildContext context) {
    final title = content['title'] as String?;
    final tldr = content['tldr'] as String?;
    final status = content['status'] as String?;
    final priority = content['priority'] as String?;
    final achieved = _castStringList(content['achieved']);
    final remaining = _castStringList(content['remaining']);
    final learnings = content['learnings'] as String?;
    final lastUpdated = content['lastUpdated'] as String?;
    final checklist = content['checklist'] as Map<String, Object?>?;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
        vertical: AppTheme.spacingSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (title != null) const SizedBox(height: AppTheme.spacingSmall),
            if (status != null || priority != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
                child: Wrap(
                  spacing: AppTheme.spacingSmall,
                  children: [
                    if (status != null)
                      _BadgeChip(
                        // TODO(l10n): localize status label
                        label: status,
                        color: context.colorScheme.primary,
                      ),
                    if (priority != null)
                      _BadgeChip(
                        // TODO(l10n): localize priority label
                        label: priority,
                        color: context.colorScheme.tertiary,
                      ),
                  ],
                ),
              ),
            if (tldr != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
                child: Text(
                  tldr,
                  style: context.textTheme.bodyMedium,
                ),
              ),
            if (achieved.isNotEmpty) ...[
              // TODO(l10n): localize "Achieved" heading
              _SectionHeading(
                label: 'Achieved',
                color: context.colorScheme.primary,
              ),
              ...achieved.map(_BulletItem.new),
              const SizedBox(height: AppTheme.spacingSmall),
            ],
            if (remaining.isNotEmpty) ...[
              // TODO(l10n): localize "Remaining" heading
              _SectionHeading(
                label: 'Remaining',
                color: context.colorScheme.secondary,
              ),
              ...remaining.map(_BulletItem.new),
              const SizedBox(height: AppTheme.spacingSmall),
            ],
            if (checklist != null) _ChecklistProgress(checklist: checklist),
            if (learnings != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacingSmall,
                ),
                child: Text(
                  learnings,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacingMedium,
                ),
                child: Text(
                  // TODO(l10n): localize "Updated:" prefix
                  'Updated: $lastUpdated',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _castStringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXSmall),
      child: Text(
        label,
        style: context.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingMedium,
        bottom: AppTheme.spacingXSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 6,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistProgress extends StatelessWidget {
  const _ChecklistProgress({required this.checklist});

  final Map<String, Object?> checklist;

  @override
  Widget build(BuildContext context) {
    final done = (checklist['done'] as num?)?.toInt() ?? 0;
    final total = (checklist['total'] as num?)?.toInt() ?? 0;
    if (total == 0) return const SizedBox.shrink();

    final progress = done / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // TODO(l10n): localize "Checklist" label and progress text
            'Checklist: $done / $total',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXSmall),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  context.colorScheme.outline.withValues(alpha: 0.2),
              color: context.colorScheme.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
