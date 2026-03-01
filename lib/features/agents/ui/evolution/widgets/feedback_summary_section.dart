import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_category_breakdown.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_item_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Renders [ClassifiedFeedback] grouped by sentiment (negative first, then
/// positive, then neutral). Supports toggling between sentiment and category
/// views via a [SegmentedButton].
class FeedbackSummarySection extends StatefulWidget {
  const FeedbackSummarySection({
    required this.feedback,
    super.key,
  });

  final ClassifiedFeedback feedback;

  @override
  State<FeedbackSummarySection> createState() => _FeedbackSummarySectionState();
}

enum _ViewMode { sentiment, category }

class _FeedbackSummarySectionState extends State<FeedbackSummarySection> {
  _ViewMode _viewMode = _ViewMode.sentiment;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    if (widget.feedback.items.isEmpty) {
      return Center(
        child: Text(
          messages.agentRitualReviewNoFeedback,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // View toggle
        Center(
          child: SegmentedButton<_ViewMode>(
            segments: [
              ButtonSegment(
                value: _ViewMode.sentiment,
                label: Text(messages.agentRitualReviewBySentiment),
              ),
              ButtonSegment(
                value: _ViewMode.category,
                label: Text(messages.agentRitualReviewByCategory),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (selection) {
              setState(() => _viewMode = selection.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_viewMode == _ViewMode.sentiment)
          _SentimentView(feedback: widget.feedback)
        else
          FeedbackCategoryBreakdown(feedback: widget.feedback),
      ],
    );
  }
}

class _SentimentView extends StatelessWidget {
  const _SentimentView({required this.feedback});

  final ClassifiedFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final negative = feedback.negative;
    final positive = feedback.positive;
    final neutral = feedback.neutral;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (negative.isNotEmpty)
          _SentimentGroup(
            title: messages.agentRitualReviewNegativeSignals,
            count: negative.length,
            color: GameyColors.primaryRed,
            items: negative,
          ),
        if (positive.isNotEmpty)
          _SentimentGroup(
            title: messages.agentRitualReviewPositiveSignals,
            count: positive.length,
            color: GameyColors.primaryGreen,
            items: positive,
          ),
        if (neutral.isNotEmpty)
          _SentimentGroup(
            title: messages.agentRitualReviewNeutralSignals,
            count: neutral.length,
            color: GameyColors.primaryOrange,
            items: neutral,
          ),
      ],
    );
  }
}

/// A collapsible section with a colored header + count badge.
class _SentimentGroup extends StatefulWidget {
  const _SentimentGroup({
    required this.title,
    required this.count,
    required this.color,
    required this.items,
  });

  final String title;
  final int count;
  final Color color;
  final List<ClassifiedFeedbackItem> items;

  @override
  State<_SentimentGroup> createState() => _SentimentGroupState();
}

class _SentimentGroupState extends State<_SentimentGroup> {
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
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: widget.color,
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
}
