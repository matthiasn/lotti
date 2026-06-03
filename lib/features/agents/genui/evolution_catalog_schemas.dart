part of 'evolution_catalog.dart';

// ── Schemas ─────────────────────────────────────────────────────────────────

final _proposalSchema = S.object(
  properties: {
    'generalDirective': S.string(
      description: 'The proposed general directive text',
    ),
    'reportDirective': S.string(
      description: 'The proposed report directive text',
    ),
    'rationale': S.string(description: 'Brief rationale for the changes'),
    'currentGeneralDirective': S.string(
      description: 'The current general directive for comparison',
    ),
    'currentReportDirective': S.string(
      description: 'The current report directive for comparison',
    ),
  },
  required: ['generalDirective', 'reportDirective', 'rationale'],
);

final _soulProposalSchema = S.object(
  properties: {
    'voiceDirective': S.string(description: 'Proposed voice directive'),
    'toneBounds': S.string(description: 'Proposed tone bounds'),
    'coachingStyle': S.string(description: 'Proposed coaching style'),
    'antiSycophancyPolicy': S.string(
      description: 'Proposed anti-sycophancy policy',
    ),
    'rationale': S.string(description: 'Brief rationale for the changes'),
    'crossTemplateNotice': S.string(
      description: 'Impact notice for other templates sharing this soul',
    ),
    'currentVoiceDirective': S.string(
      description: 'Current voice directive for comparison',
    ),
    'currentToneBounds': S.string(
      description: 'Current tone bounds for comparison',
    ),
    'currentCoachingStyle': S.string(
      description: 'Current coaching style for comparison',
    ),
    'currentAntiSycophancyPolicy': S.string(
      description: 'Current anti-sycophancy policy for comparison',
    ),
  },
  required: ['rationale'],
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
    'averageDurationSeconds': S.number(
      description: 'Average wake duration in seconds',
    ),
    'activeInstances': S.integer(
      description: 'Number of active agent instances',
    ),
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
          'positiveCount': S.integer(
            description: 'Positive items in this category',
          ),
          'negativeCount': S.integer(
            description: 'Negative items in this category',
          ),
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

final _categoryRatingsSchema = S.object(
  properties: {
    'categories': S.list(
      items: S.object(
        properties: {
          'name': S.string(description: 'Category identifier (e.g., accuracy)'),
          'label': S.string(description: 'Display label for the category'),
        },
        required: ['name', 'label'],
      ),
      description: 'Categories to rate',
    ),
  },
  required: ['categories'],
);

final _highPriorityFeedbackSchema = S.object(
  properties: {
    'grievances': S.list(
      items: S.object(
        properties: {
          'agentId': S.string(description: 'Short agent ID'),
          'detail': S.string(description: 'Full grievance text'),
        },
        required: ['detail'],
      ),
      description: 'Negative critical observations (grievances)',
    ),
    'excellenceNotes': S.list(
      items: S.object(
        properties: {
          'agentId': S.string(description: 'Short agent ID'),
          'detail': S.string(description: 'Full excellence note text'),
        },
        required: ['detail'],
      ),
      description: 'Positive critical observations (excellence notes)',
    ),
  },
  required: ['grievances', 'excellenceNotes'],
);

final _binaryChoicePromptSchema = S.object(
  properties: {
    'question': S.string(description: 'The yes/no question to ask'),
    'detail': S.string(
      description: 'Optional supporting detail shown below the question',
    ),
    'confirmLabel': S.string(
      description: 'Optional label for the affirmative button',
    ),
    'dismissLabel': S.string(
      description: 'Optional label for the negative button',
    ),
    'confirmValue': S.string(
      description: 'Semantic payload sent when the user confirms',
    ),
    'dismissValue': S.string(
      description: 'Semantic payload sent when the user declines',
    ),
  },
  required: ['question'],
);

final _abComparisonSchema = S.object(
  properties: {
    'question': S.string(
      description: 'The question shown at the top of the comparison card',
    ),
    'optionA': S.string(
      description: 'Full text of option A — a concrete example phrasing',
    ),
    'optionB': S.string(
      description: 'Full text of option B — a concrete example phrasing',
    ),
    'labelA': S.string(
      description: 'Short label for A, e.g. "Warmer" or "Encouraging"',
    ),
    'labelB': S.string(
      description: 'Short label for B, e.g. "More direct" or "Fact-first"',
    ),
  },
  required: ['question', 'optionA', 'optionB'],
);

// ── Private helpers ─────────────────────────────────────────────────────────

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
    'negative' => AgentPalette.red,
    'positive' => AgentPalette.green,
    _ => AgentPalette.orange,
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

Widget _highPrioritySectionHeader(String label, int count, Color color) {
  return Row(
    children: [
      Container(
        width: 4,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '$label ($count)',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

Widget _highPriorityItemTile({
  required String agentId,
  required String detail,
  required Color accentColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 16,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        if (agentId.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              '[$agentId]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
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
  final neutralCount = max(0, count - positiveCount - negativeCount);

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
                      child: Container(color: AgentPalette.red),
                    ),
                  if (positiveCount > 0)
                    Expanded(
                      flex: positiveCount,
                      child: Container(color: AgentPalette.green),
                    ),
                  if (neutralCount > 0)
                    Expanded(
                      flex: neutralCount,
                      child: Container(color: AgentPalette.orange),
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
