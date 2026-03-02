import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_item_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Renders [ClassifiedFeedback] grouped by sentiment using tabs (negative,
/// positive, neutral) with count badges.
class FeedbackSummarySection extends StatelessWidget {
  const FeedbackSummarySection({
    required this.feedback,
    super.key,
  });

  final ClassifiedFeedback feedback;

  @override
  Widget build(BuildContext context) {
    if (feedback.items.isEmpty) {
      return Center(
        child: Text(
          context.messages.agentRitualReviewNoFeedback,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return _SentimentTabView(feedback: feedback);
  }
}

/// Tabbed view with three sentiment tabs (Negative, Positive, Neutral),
/// each showing a bounded, scrollable list of [FeedbackItemTile] widgets.
class _SentimentTabView extends StatefulWidget {
  const _SentimentTabView({required this.feedback});

  final ClassifiedFeedback feedback;

  @override
  State<_SentimentTabView> createState() => _SentimentTabViewState();
}

class _SentimentTabViewState extends State<_SentimentTabView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
  }

  /// Trigger rebuild so the ValueKey-based content swap picks up the new index.
  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final negative = widget.feedback.negative;
    final positive = widget.feedback.positive;
    final neutral = widget.feedback.neutral;

    final itemLists = [negative, positive, neutral];

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: GameyColors.primaryPurple,
          dividerColor: Colors.white.withValues(alpha: 0.1),
          labelPadding: EdgeInsets.zero,
          tabs: [
            _SentimentTab(
              label: messages.agentRitualReviewNegativeSignals,
              count: negative.length,
              color: GameyColors.primaryRed,
            ),
            _SentimentTab(
              label: messages.agentRitualReviewPositiveSignals,
              count: positive.length,
              color: GameyColors.primaryGreen,
            ),
            _SentimentTab(
              label: messages.agentRitualReviewNeutralSignals,
              count: neutral.length,
              color: GameyColors.primaryOrange,
            ),
          ],
        ),
        Expanded(
          child: _SentimentItemList(
            // Use ValueKey so Flutter rebuilds the list when the tab changes.
            key: ValueKey(_tabController.index),
            items: itemLists[_tabController.index],
          ),
        ),
      ],
    );
  }
}

/// A single tab label with sentiment-colored text and count badge.
class _SentimentTab extends StatelessWidget {
  const _SentimentTab({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bounded, scrollable list of feedback items for a single sentiment tab.
class _SentimentItemList extends StatelessWidget {
  const _SentimentItemList({required this.items, super.key});

  final List<ClassifiedFeedbackItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.messages.agentRitualReviewNoFeedback,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => FeedbackItemTile(item: items[index]),
    );
  }
}
