import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_item_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Groups feedback items by [FeedbackCategory] using
/// [ClassifiedFeedbackX.byCategory]. Each category shows an icon, count,
/// and items with sentiment-colored indicators.
class FeedbackCategoryBreakdown extends StatelessWidget {
  const FeedbackCategoryBreakdown({
    required this.feedback,
    super.key,
  });

  final ClassifiedFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final grouped = feedback.byCategory;
    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort categories by item count descending
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedEntries.map((entry) {
        return _CategoryGroup(
          category: entry.key,
          items: entry.value,
        );
      }).toList(),
    );
  }
}

class _CategoryGroup extends StatefulWidget {
  const _CategoryGroup({
    required this.category,
    required this.items,
  });

  final FeedbackCategory category;
  final List<ClassifiedFeedbackItem> items;

  @override
  State<_CategoryGroup> createState() => _CategoryGroupState();
}

class _CategoryGroupState extends State<_CategoryGroup> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Icon(
                  _categoryIcon(widget.category),
                  size: 18,
                  color: GameyColors.aiCyan,
                ),
                const SizedBox(width: 8),
                Text(
                  _categoryLabel(context, widget.category),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.items.length}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 6),
            ...widget.items.map((item) => FeedbackItemTile(item: item)),
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(FeedbackCategory category) {
    return switch (category) {
      FeedbackCategory.accuracy => Icons.verified_outlined,
      FeedbackCategory.communication => Icons.chat_outlined,
      FeedbackCategory.prioritization => Icons.sort_outlined,
      FeedbackCategory.tooling => Icons.build_outlined,
      FeedbackCategory.timeliness => Icons.schedule_outlined,
      FeedbackCategory.general => Icons.info_outlined,
    };
  }

  String _categoryLabel(BuildContext context, FeedbackCategory category) {
    final messages = context.messages;
    return switch (category) {
      FeedbackCategory.accuracy => messages.agentFeedbackCategoryAccuracy,
      FeedbackCategory.communication =>
        messages.agentFeedbackCategoryCommunication,
      FeedbackCategory.prioritization =>
        messages.agentFeedbackCategoryPrioritization,
      FeedbackCategory.tooling => messages.agentFeedbackCategoryTooling,
      FeedbackCategory.timeliness => messages.agentFeedbackCategoryTimeliness,
      FeedbackCategory.general => messages.agentFeedbackCategoryGeneral,
    };
  }
}
