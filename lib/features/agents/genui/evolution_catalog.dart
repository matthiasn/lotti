import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/glows.dart';
import 'package:lotti/themes/gamey/gradients.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Catalog ID for the evolution agent's custom widgets.
const evolutionCatalogId = 'com.lotti.evolution_catalog';

/// Builds the GenUI [Catalog] for the evolution chat, containing custom
/// widget types the LLM can instantiate via the `render_surface` tool.
Catalog buildEvolutionCatalog() => Catalog(
      [
        evolutionProposalItem,
        evolutionNoteConfirmationItem,
        metricsSummaryItem,
        versionComparisonItem,
        feedbackClassificationItem,
        feedbackCategoryBreakdownItem,
        sessionProgressItem,
      ],
      catalogId: evolutionCatalogId,
    );

// ── Schemas ─────────────────────────────────────────────────────────────────

final _proposalSchema = S.object(
  properties: {
    'directives': S.string(description: 'The proposed directives text'),
    'rationale': S.string(description: 'Brief rationale for the changes'),
    'currentDirectives':
        S.string(description: 'The current directives for comparison'),
  },
  required: ['directives', 'rationale'],
);

final _noteConfirmationSchema = S.object(
  properties: {
    'kind': S.string(
      description: 'The note kind',
      enumValues: ['reflection', 'hypothesis', 'decision', 'pattern'],
    ),
    'content': S.string(description: 'The note content'),
  },
  required: ['kind', 'content'],
);

final _metricsSummarySchema = S.object(
  properties: {
    'totalWakes': S.integer(description: 'Total number of wakes'),
    'successRate': S.number(description: 'Success rate 0.0–1.0'),
    'failureCount': S.integer(description: 'Number of failures'),
    'averageDurationSeconds':
        S.number(description: 'Average wake duration in seconds'),
    'activeInstances':
        S.integer(description: 'Number of active agent instances'),
  },
  required: ['totalWakes', 'successRate', 'failureCount'],
);

final _versionComparisonSchema = S.object(
  properties: {
    'beforeVersion': S.integer(description: 'Previous version number'),
    'afterVersion': S.integer(description: 'New version number'),
    'beforeDirectives': S.string(description: 'Previous directives text'),
    'afterDirectives': S.string(description: 'New directives text'),
    'changesSummary': S.string(description: 'Summary of changes'),
  },
  required: [
    'beforeVersion',
    'afterVersion',
    'beforeDirectives',
    'afterDirectives',
  ],
);

final _feedbackClassificationSchema = S.object(
  properties: {
    'items': S.list(
      items: S.object(
        properties: {
          'sentiment': S.string(
            description: 'Sentiment: positive, negative, or neutral',
            enumValues: ['positive', 'negative', 'neutral'],
          ),
          'category': S.string(
            description: 'Feedback category',
            enumValues: [
              'accuracy',
              'communication',
              'prioritization',
              'tooling',
              'timeliness',
              'general',
            ],
          ),
          'source': S.string(description: 'Signal source'),
          'detail': S.string(description: 'Detail text'),
        },
        required: ['sentiment', 'category', 'source', 'detail'],
      ),
      description: 'List of classified feedback items',
    ),
    'positiveCount': S.integer(description: 'Number of positive signals'),
    'negativeCount': S.integer(description: 'Number of negative signals'),
    'neutralCount': S.integer(description: 'Number of neutral signals'),
  },
  required: ['items', 'positiveCount', 'negativeCount', 'neutralCount'],
);

final _feedbackCategoryBreakdownSchema = S.object(
  properties: {
    'categories': S.list(
      items: S.object(
        properties: {
          'name': S.string(description: 'Category name'),
          'count': S.integer(description: 'Total items in this category'),
          'positiveCount':
              S.integer(description: 'Positive items in this category'),
          'negativeCount':
              S.integer(description: 'Negative items in this category'),
        },
        required: ['name', 'count'],
      ),
      description: 'Category breakdown entries',
    ),
  },
  required: ['categories'],
);

final _sessionProgressSchema = S.object(
  properties: {
    'sessionNumber': S.integer(description: 'Current session number'),
    'totalSessions': S.integer(description: 'Total sessions so far'),
    'feedbackCount': S.integer(description: 'Number of feedback items'),
    'positiveCount': S.integer(description: 'Positive feedback count'),
    'negativeCount': S.integer(description: 'Negative feedback count'),
    'status': S.string(
      description: 'Session status',
      enumValues: ['active', 'completed', 'abandoned'],
    ),
  },
  required: ['sessionNumber', 'totalSessions', 'feedbackCount', 'status'],
);

// ── Catalog Items ───────────────────────────────────────────────────────────

/// Proposal card with approve/reject actions.
final evolutionProposalItem = CatalogItem(
  name: 'EvolutionProposal',
  dataSchema: _proposalSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final directives =
        json['directives'] is String ? json['directives']! as String : '';
    final rationale =
        json['rationale'] is String ? json['rationale']! as String : '';
    final currentDirectives = json['currentDirectives'] is String
        ? json['currentDirectives']! as String
        : null;
    final context = itemContext.buildContext;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ModernBaseCard(
        isEnhanced: true,
        customShadows: [GameyGlows.strongGlow(GameyColors.primaryPurple)],
        gradient: GameyGradients.cardDark(GameyColors.primaryPurple),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: GameyColors.primaryPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.agentEvolutionProposalTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentDirectives != null && currentDirectives.isNotEmpty) ...[
              _sectionLabel(
                context,
                context.messages.agentEvolutionCurrentDirectives,
              ),
              const SizedBox(height: 6),
              _directiveBox(text: currentDirectives),
              const SizedBox(height: 14),
            ],
            _sectionLabel(
              context,
              context.messages.agentEvolutionProposedDirectives,
            ),
            const SizedBox(height: 6),
            _directiveBox(
              text: directives,
              backgroundColor: GameyColors.primaryPurple.withValues(alpha: 0.1),
              borderColor: GameyColors.primaryPurple.withValues(alpha: 0.3),
            ),
            if (rationale.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                rationale,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'proposal_rejected',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GameyColors.primaryRed),
                    foregroundColor: GameyColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: Text(context.messages.agentTemplateEvolveReject),
                ),
                const SizedBox(width: 12),
                _approveButton(
                  context: context,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'proposal_approved',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

/// Confirmation card for a recorded evolution note.
final evolutionNoteConfirmationItem = CatalogItem(
  name: 'EvolutionNoteConfirmation',
  dataSchema: _noteConfirmationSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final kind =
        json['kind'] is String ? json['kind']! as String : 'reflection';
    final content = json['content'] is String ? json['content']! as String : '';

    return _EvolutionNoteConfirmationCard(
      kind: kind,
      content: content,
    );
  },
);

/// Expandable card showing a recorded evolution note.
///
/// Starts collapsed (2 lines max) and expands to show the full content on tap.
class _EvolutionNoteConfirmationCard extends StatefulWidget {
  const _EvolutionNoteConfirmationCard({
    required this.kind,
    required this.content,
  });

  final String kind;
  final String content;

  @override
  State<_EvolutionNoteConfirmationCard> createState() =>
      _EvolutionNoteConfirmationCardState();
}

class _EvolutionNoteConfirmationCardState
    extends State<_EvolutionNoteConfirmationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: ModernBaseCard(
          gradient: GameyGradients.cardDark(GameyColors.aiCyan),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _noteKindIcon(widget.kind),
                size: 18,
                color: GameyColors.aiCyan,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.messages.agentEvolutionNoteRecorded,
                            style: const TextStyle(
                              color: GameyColors.aiCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Text(
                        widget.content,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondChild: Text(
                        widget.content,
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
      ),
    );
  }
}

/// Inline metrics summary widget.
final metricsSummaryItem = CatalogItem(
  name: 'MetricsSummary',
  dataSchema: _metricsSummarySchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final totalWakes =
        (json['totalWakes'] is num) ? (json['totalWakes']! as num).toInt() : 0;
    final successRate = (json['successRate'] is num)
        ? (json['successRate']! as num).toDouble()
        : 0.0;
    final failureCount = (json['failureCount'] is num)
        ? (json['failureCount']! as num).toInt()
        : 0;
    final avgDuration = json['averageDurationSeconds'] is num
        ? json['averageDurationSeconds']! as num
        : null;
    final activeInstances =
        json['activeInstances'] is num ? json['activeInstances']! as num : null;

    final context = itemContext.buildContext;
    final messages = context.messages;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: GameyGradients.cardDark(GameyColors.surfaceDarkElevated),
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _metricChip(messages.agentEvolutionMetricWakes, '$totalWakes'),
            _metricChip(
              messages.agentEvolutionMetricSuccess,
              '${(successRate * 100).toStringAsFixed(0)}%',
            ),
            _metricChip(
              messages.agentEvolutionMetricFailures,
              '$failureCount',
            ),
            if (avgDuration != null)
              _metricChip(
                messages.agentEvolutionMetricAvgDuration,
                '${avgDuration.toStringAsFixed(0)}s',
              ),
            if (activeInstances != null)
              _metricChip(
                messages.agentEvolutionMetricActive,
                '${activeInstances.toInt()}',
              ),
          ],
        ),
      ),
    );
  },
);

/// Before/after version comparison widget.
final versionComparisonItem = CatalogItem(
  name: 'VersionComparison',
  dataSchema: _versionComparisonSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final beforeVersion = (json['beforeVersion'] is num)
        ? (json['beforeVersion']! as num).toInt()
        : 0;
    final afterVersion = (json['afterVersion'] is num)
        ? (json['afterVersion']! as num).toInt()
        : 0;
    final beforeDirectives = json['beforeDirectives'] is String
        ? json['beforeDirectives']! as String
        : '';
    final afterDirectives = json['afterDirectives'] is String
        ? json['afterDirectives']! as String
        : '';
    final changesSummary = json['changesSummary'] is String
        ? json['changesSummary']! as String
        : null;
    final context = itemContext.buildContext;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ModernBaseCard(
        gradient: GameyGradients.cardDark(GameyColors.surfaceDarkElevated),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.compare_arrows,
                  size: 20,
                  color: GameyColors.aiCyan,
                ),
                const SizedBox(width: 8),
                Text(
                  'v$beforeVersion → v$afterVersion',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionLabel(
              context,
              '${context.messages.agentEvolutionCurrentDirectives}'
              ' (v$beforeVersion)',
            ),
            const SizedBox(height: 6),
            _directiveBox(text: beforeDirectives),
            const SizedBox(height: 12),
            _sectionLabel(
              context,
              '${context.messages.agentEvolutionProposedDirectives}'
              ' (v$afterVersion)',
            ),
            const SizedBox(height: 6),
            _directiveBox(
              text: afterDirectives,
              backgroundColor: GameyColors.primaryPurple.withValues(alpha: 0.1),
              borderColor: GameyColors.primaryPurple.withValues(alpha: 0.3),
            ),
            if (changesSummary != null && changesSummary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                changesSummary,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  },
);

/// Inline grouped feedback classification card.
final feedbackClassificationItem = CatalogItem(
  name: 'FeedbackClassification',
  dataSchema: _feedbackClassificationSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final items = (json['items'] is List)
        ? (json['items']! as List).whereType<Map<String, Object?>>().toList()
        : <Map<String, Object?>>[];
    final positiveCount = (json['positiveCount'] is num)
        ? (json['positiveCount']! as num).toInt()
        : 0;
    final negativeCount = (json['negativeCount'] is num)
        ? (json['negativeCount']! as num).toInt()
        : 0;
    final neutralCount = (json['neutralCount'] is num)
        ? (json['neutralCount']! as num).toInt()
        : 0;
    final context = itemContext.buildContext;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: GameyGradients.cardDark(GameyColors.surfaceDarkElevated),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  size: 18,
                  color: GameyColors.aiCyan,
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
                  _sentimentChip(
                    context.messages.agentRitualReviewNegativeSignals,
                    negativeCount,
                    GameyColors.primaryRed,
                  ),
                if (positiveCount > 0)
                  _sentimentChip(
                    context.messages.agentRitualReviewPositiveSignals,
                    positiveCount,
                    GameyColors.primaryGreen,
                  ),
                if (neutralCount > 0)
                  _sentimentChip(
                    context.messages.agentRitualReviewNeutralSignals,
                    neutralCount,
                    GameyColors.primaryOrange,
                  ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...items.take(5).map(
                    (item) => _feedbackLine(
                      detail: item['detail'] is String
                          ? item['detail']! as String
                          : '',
                      sentiment: item['sentiment'] is String
                          ? item['sentiment']! as String
                          : 'neutral',
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
  dataSchema: _feedbackCategoryBreakdownSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final categories = (json['categories'] is List)
        ? (json['categories']! as List)
            .whereType<Map<String, Object?>>()
            .toList()
        : <Map<String, Object?>>[];
    final context = itemContext.buildContext;

    final totalCount = categories.fold<int>(
      0,
      (sum, c) =>
          sum + ((c['count'] is num) ? (c['count']! as num).toInt() : 0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: GameyGradients.cardDark(GameyColors.surfaceDarkElevated),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: GameyColors.aiCyan,
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
              (c) => _categoryBar(
                name: c['name'] is String ? c['name']! as String : '',
                count: (c['count'] is num) ? (c['count']! as num).toInt() : 0,
                positiveCount: (c['positiveCount'] is num)
                    ? (c['positiveCount']! as num).toInt()
                    : 0,
                negativeCount: (c['negativeCount'] is num)
                    ? (c['negativeCount']! as num).toInt()
                    : 0,
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
  dataSchema: _sessionProgressSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final sessionNumber = (json['sessionNumber'] is num)
        ? (json['sessionNumber']! as num).toInt()
        : 0;
    final totalSessions = (json['totalSessions'] is num)
        ? (json['totalSessions']! as num).toInt()
        : 0;
    final feedbackCount = (json['feedbackCount'] is num)
        ? (json['feedbackCount']! as num).toInt()
        : 0;
    final positiveCount = (json['positiveCount'] is num)
        ? (json['positiveCount']! as num).toInt()
        : 0;
    final negativeCount = (json['negativeCount'] is num)
        ? (json['negativeCount']! as num).toInt()
        : 0;
    final status =
        json['status'] is String ? json['status']! as String : 'active';
    final context = itemContext.buildContext;

    final statusColor = switch (status) {
      'completed' => GameyColors.primaryGreen,
      'abandoned' => GameyColors.primaryRed,
      _ => GameyColors.primaryBlue,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: GameyGradients.cardDark(statusColor),
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
                _metricChip(
                  context.messages.agentEvolutionTimelineFeedbackLabel,
                  '$feedbackCount',
                ),
                if (positiveCount > 0) _metricChip('+', '$positiveCount'),
                if (negativeCount > 0) _metricChip('-', '$negativeCount'),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

// ── Private helpers ─────────────────────────────────────────────────────────

Widget _sectionLabel(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.6),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
}

Widget _directiveBox({
  required String text,
  Color? backgroundColor,
  Color? borderColor,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: backgroundColor ?? GameyColors.surfaceDark.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      border: borderColor != null ? Border.all(color: borderColor) : null,
    ),
    child: SelectableText(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 13,
        height: 1.5,
      ),
    ),
  );
}

Widget _metricChip(String label, String value) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    ],
  );
}

Widget _approveButton({
  required BuildContext context,
  required VoidCallback onPressed,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: GameyGradients.success,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            context.messages.agentTemplateEvolveApprove,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    ),
  );
}

IconData _noteKindIcon(String kind) {
  return switch (kind) {
    'reflection' => Icons.psychology,
    'hypothesis' => Icons.lightbulb_outline,
    'decision' => Icons.gavel,
    'pattern' => Icons.pattern,
    _ => Icons.note,
  };
}

Widget _sentimentChip(String label, int count, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      '$count $label',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

Widget _feedbackLine({required String detail, required String sentiment}) {
  final color = switch (sentiment) {
    'negative' => GameyColors.primaryRed,
    'positive' => GameyColors.primaryGreen,
    _ => GameyColors.primaryOrange,
  };

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 16,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget _categoryBar({
  required String name,
  required int count,
  required int positiveCount,
  required int negativeCount,
  required int totalCount,
}) {
  final fraction = totalCount > 0 ? count / totalCount : 0.0;
  final neutralCount = count - positiveCount - negativeCount;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 6,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Row(
                children: [
                  if (negativeCount > 0)
                    Expanded(
                      flex: negativeCount,
                      child: Container(color: GameyColors.primaryRed),
                    ),
                  if (positiveCount > 0)
                    Expanded(
                      flex: positiveCount,
                      child: Container(color: GameyColors.primaryGreen),
                    ),
                  if (neutralCount > 0)
                    Expanded(
                      flex: neutralCount,
                      child: Container(color: GameyColors.primaryOrange),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
