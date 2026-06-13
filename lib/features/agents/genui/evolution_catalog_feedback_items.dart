import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_schemas.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Inline grouped feedback classification card.
final feedbackClassificationItem = CatalogItem(
  name: 'FeedbackClassification',
  dataSchema: feedbackClassificationSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final items = readMapList(json, 'items');
    final positiveCount = readInt(json, 'positiveCount');
    final negativeCount = readInt(json, 'negativeCount');
    final neutralCount = readInt(json, 'neutralCount');
    final context = itemContext.buildContext;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: agentCardDarkGradient(AgentPalette.surfaceDarkElevated),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  size: 18,
                  color: AgentPalette.cyan,
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.agentFeedbackClassificationTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (negativeCount > 0)
                  sentimentChip(
                    context.messages.agentRitualReviewNegativeSignals,
                    negativeCount,
                    AgentPalette.red,
                  ),
                if (positiveCount > 0)
                  sentimentChip(
                    context.messages.agentRitualReviewPositiveSignals,
                    positiveCount,
                    AgentPalette.green,
                  ),
                if (neutralCount > 0)
                  sentimentChip(
                    context.messages.agentRitualReviewNeutralSignals,
                    neutralCount,
                    AgentPalette.orange,
                  ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...items
                  .take(5)
                  .map(
                    (item) => feedbackLine(
                      detail: readString(item, 'detail'),
                      sentiment: readString(item, 'sentiment', 'neutral'),
                    ),
                  ),
              if (items.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.messages.agentFeedbackItemCount(items.length - 5),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  },
);

/// Category distribution visualization card.
final feedbackCategoryBreakdownItem = CatalogItem(
  name: 'FeedbackCategoryBreakdown',
  dataSchema: feedbackCategoryBreakdownSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final categories = readMapList(json, 'categories');
    final context = itemContext.buildContext;

    final totalCount = categories.fold<int>(
      0,
      (sum, c) => sum + readInt(c, 'count'),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: agentCardDarkGradient(AgentPalette.surfaceDarkElevated),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: AgentPalette.cyan,
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.agentFeedbackCategoryBreakdownTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...categories.map(
              (c) => categoryBar(
                name: readString(c, 'name'),
                count: readInt(c, 'count'),
                positiveCount: readInt(c, 'positiveCount'),
                negativeCount: readInt(c, 'negativeCount'),
                totalCount: totalCount,
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// Compact session progress status card.
final sessionProgressItem = CatalogItem(
  name: 'SessionProgress',
  dataSchema: sessionProgressSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final sessionNumber = readInt(json, 'sessionNumber');
    final totalSessions = readInt(json, 'totalSessions');
    final feedbackCount = readInt(json, 'feedbackCount');
    final positiveCount = readInt(json, 'positiveCount');
    final negativeCount = readInt(json, 'negativeCount');
    final status = readString(json, 'status', 'active');
    final context = itemContext.buildContext;

    final statusColor = switch (status) {
      'completed' => AgentPalette.green,
      'abandoned' => AgentPalette.red,
      _ => AgentPalette.blue,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: agentCardDarkGradient(statusColor),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.loop, size: 20, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.messages.agentSessionProgressTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.messages.agentEvolutionSessionProgress(
                      sessionNumber,
                      totalSessions,
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                metricChip(
                  context.messages.agentEvolutionTimelineFeedbackLabel,
                  '$feedbackCount',
                ),
                if (positiveCount > 0) metricChip('+', '$positiveCount'),
                if (negativeCount > 0) metricChip('-', '$negativeCount'),
              ],
            ),
          ],
        ),
      ),
    );
  },
);
