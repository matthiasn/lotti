import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Renders a single [ClassifiedFeedbackItem] with a sentiment-colored leading
/// indicator, category badge, source label, and expandable detail text.
class FeedbackItemTile extends StatefulWidget {
  const FeedbackItemTile({
    required this.item,
    super.key,
  });

  final ClassifiedFeedbackItem item;

  @override
  State<FeedbackItemTile> createState() => _FeedbackItemTileState();
}

class _FeedbackItemTileState extends State<FeedbackItemTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sentimentColor = feedbackSentimentColor(widget.item.sentiment);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sentiment-colored leading strip
            Container(
              width: 4,
              height: _expanded ? null : 40,
              constraints: const BoxConstraints(minHeight: 40),
              decoration: BoxDecoration(
                color: sentimentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(category: widget.item.category),
                      const SizedBox(width: 8),
                      Text(
                        _sourceLabel(context, widget.item.source),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      widget.item.detail,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondChild: Text(
                      widget.item.detail,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(BuildContext context, String source) {
    final messages = context.messages;
    return switch (source) {
      'observation' => messages.agentFeedbackSourceObservation,
      'decision' => messages.agentFeedbackSourceDecision,
      'metric' => messages.agentFeedbackSourceMetric,
      'rating' => messages.agentFeedbackSourceRating,
      _ => source,
    };
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final FeedbackCategory category;

  @override
  Widget build(BuildContext context) {
    final color = feedbackCategoryColor(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        feedbackCategoryLabel(context, category),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
