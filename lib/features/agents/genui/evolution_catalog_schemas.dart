import 'package:json_schema_builder/json_schema_builder.dart';

// ── Schemas ─────────────────────────────────────────────────────────────────

final proposalSchema = S.object(
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

final soulProposalSchema = S.object(
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

final noteConfirmationSchema = S.object(
  properties: {
    'kind': S.string(
      description: 'The note kind',
      enumValues: ['reflection', 'hypothesis', 'decision', 'pattern'],
    ),
    'content': S.string(description: 'The note content'),
  },
  required: ['kind', 'content'],
);

final metricsSummarySchema = S.object(
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

final versionComparisonSchema = S.object(
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

final feedbackClassificationSchema = S.object(
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

final feedbackCategoryBreakdownSchema = S.object(
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

final sessionProgressSchema = S.object(
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

final categoryRatingsSchema = S.object(
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

final highPriorityFeedbackSchema = S.object(
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

final binaryChoicePromptSchema = S.object(
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

final abComparisonSchema = S.object(
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
