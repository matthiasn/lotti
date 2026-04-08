import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_interactive_widgets.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/gradients.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// Catalog ID for the evolution agent's custom widgets.
const evolutionCatalogId = 'com.lotti.evolution_catalog';

/// Builds the GenUI [Catalog] for the evolution chat, containing custom
/// widget types the LLM can instantiate via the `render_surface` tool.
Catalog buildEvolutionCatalog() => Catalog(
  [
    evolutionProposalItem,
    soulProposalItem,
    evolutionNoteConfirmationItem,
    metricsSummaryItem,
    versionComparisonItem,
    feedbackClassificationItem,
    feedbackCategoryBreakdownItem,
    sessionProgressItem,
    categoryRatingsItem,
    binaryChoicePromptItem,
    abComparisonCardItem,
    highPriorityFeedbackItem,
  ],
  catalogId: evolutionCatalogId,
);

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

// ── Catalog Items ───────────────────────────────────────────────────────────

/// Proposal card with approve/reject actions.
final evolutionProposalItem = CatalogItem(
  name: 'EvolutionProposal',
  dataSchema: _proposalSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final generalDirective = readString(json, 'generalDirective').trim();
    final reportDirective = readString(json, 'reportDirective').trim();
    final rationale = readString(json, 'rationale').trim();
    final currentGeneral = readStringOrNull(
      json,
      'currentGeneralDirective',
    )?.trim();
    final currentReport = readStringOrNull(
      json,
      'currentReportDirective',
    )?.trim();
    final context = itemContext.buildContext;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final tokens = context.designTokens;

    final hasCurrentDirectives =
        (currentGeneral != null && currentGeneral.isNotEmpty) ||
        (currentReport != null && currentReport.isNotEmpty);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: ModernBaseCard(
        backgroundColor: colorScheme.surfaceContainerLow,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModernIconContainer(
                  icon: Icons.auto_awesome_rounded,
                  isCompact: true,
                ),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.messages.agentEvolutionProposalTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        context.messages.agentEvolutionProposedDirectives,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Current directives (before)
            if (hasCurrentDirectives) ...[
              if (currentGeneral != null && currentGeneral.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step5),
                sectionLabel(
                  context,
                  '${context.messages.agentEvolutionCurrentDirectives}'
                  ' — ${context.messages.agentTemplateGeneralDirectiveLabel}',
                ),
                SizedBox(height: tokens.spacing.step3),
                directiveBox(
                  context: context,
                  text: currentGeneral,
                ),
              ],
              if (currentReport != null && currentReport.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step4),
                sectionLabel(
                  context,
                  '${context.messages.agentEvolutionCurrentDirectives}'
                  ' — ${context.messages.agentTemplateReportDirectiveLabel}',
                ),
                SizedBox(height: tokens.spacing.step3),
                directiveBox(
                  context: context,
                  text: currentReport,
                ),
              ],
            ],
            // Proposed directives (after)
            if (generalDirective.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step5),
              sectionLabel(
                context,
                '${context.messages.agentEvolutionProposedDirectives}'
                ' — ${context.messages.agentTemplateGeneralDirectiveLabel}',
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: generalDirective,
                isHighlighted: true,
              ),
            ],
            if (reportDirective.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              sectionLabel(
                context,
                '${context.messages.agentEvolutionProposedDirectives}'
                ' — ${context.messages.agentTemplateReportDirectiveLabel}',
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: reportDirective,
                isHighlighted: true,
              ),
            ],
            if (rationale.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              sectionLabel(
                context,
                context.messages.agentEvolutionProposalRationale,
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: rationale,
              ),
            ],
            SizedBox(height: tokens.spacing.step5),
            Wrap(
              spacing: tokens.spacing.step4,
              runSpacing: tokens.spacing.step4,
              alignment: WrapAlignment.end,
              children: [
                DesignSystemButton(
                  label: context.messages.agentTemplateEvolveReject,
                  variant: DesignSystemButtonVariant.dangerSecondary,
                  size: DesignSystemButtonSize.medium,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'proposal_rejected',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                ),
                primaryActionButton(
                  label: context.messages.agentTemplateEvolveApprove,
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

/// Soul personality proposal card with approve/reject actions.
final soulProposalItem = CatalogItem(
  name: 'SoulProposal',
  dataSchema: _soulProposalSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final voiceDirective =
        readStringOrNull(json, 'voiceDirective')?.trim() ?? '';
    final toneBounds = readStringOrNull(json, 'toneBounds')?.trim() ?? '';
    final coachingStyle = readStringOrNull(json, 'coachingStyle')?.trim() ?? '';
    final antiSycophancyPolicy =
        readStringOrNull(json, 'antiSycophancyPolicy')?.trim() ?? '';
    final rationale = readString(json, 'rationale').trim();
    final crossTemplateNotice = readStringOrNull(
      json,
      'crossTemplateNotice',
    )?.trim();
    final currentVoice = readStringOrNull(
      json,
      'currentVoiceDirective',
    )?.trim();
    final currentTone = readStringOrNull(json, 'currentToneBounds')?.trim();
    final currentCoaching = readStringOrNull(
      json,
      'currentCoachingStyle',
    )?.trim();
    final currentAntiSycophancy = readStringOrNull(
      json,
      'currentAntiSycophancyPolicy',
    )?.trim();
    final context = itemContext.buildContext;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final tokens = context.designTokens;

    // Build paired sections: (label, current, proposed) for each field.
    final msg = context.messages;
    final fields = <({String label, String? current, String proposed})>[
      if (voiceDirective.isNotEmpty)
        (
          label: msg.agentSoulFieldVoice,
          current: currentVoice,
          proposed: voiceDirective,
        ),
      if (toneBounds.isNotEmpty)
        (
          label: msg.agentSoulFieldToneBounds,
          current: currentTone,
          proposed: toneBounds,
        ),
      if (coachingStyle.isNotEmpty)
        (
          label: msg.agentSoulFieldCoachingStyle,
          current: currentCoaching,
          proposed: coachingStyle,
        ),
      if (antiSycophancyPolicy.isNotEmpty)
        (
          label: msg.agentSoulFieldAntiSycophancy,
          current: currentAntiSycophancy,
          proposed: antiSycophancyPolicy,
        ),
    ];

    if (fields.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: ModernBaseCard(
        backgroundColor: colorScheme.surfaceContainerLow,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModernIconContainer(
                  icon: Icons.psychology_rounded,
                  isCompact: true,
                ),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.agentSoulProposalTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        msg.agentSoulProposalSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Cross-template impact notice.
            if (crossTemplateNotice != null &&
                crossTemplateNotice.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              Container(
                padding: EdgeInsets.all(tokens.spacing.step4),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Text(
                        crossTemplateNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Directive fields with before/after.
            for (final field in fields) ...[
              SizedBox(height: tokens.spacing.step5),
              if (field.current != null && field.current!.isNotEmpty) ...[
                sectionLabel(
                  context,
                  msg.agentEvolutionSoulCurrentField(field.label),
                ),
                SizedBox(height: tokens.spacing.step3),
                directiveBox(context: context, text: field.current!),
                SizedBox(height: tokens.spacing.step3),
              ],
              sectionLabel(
                context,
                msg.agentEvolutionSoulProposedField(field.label),
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: field.proposed,
                isHighlighted: true,
              ),
            ],
            if (rationale.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              sectionLabel(
                context,
                msg.agentEvolutionProposalRationale,
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(context: context, text: rationale),
            ],
            SizedBox(height: tokens.spacing.step5),
            Wrap(
              spacing: tokens.spacing.step4,
              runSpacing: tokens.spacing.step4,
              alignment: WrapAlignment.end,
              children: [
                DesignSystemButton(
                  label: context.messages.agentTemplateEvolveReject,
                  variant: DesignSystemButtonVariant.dangerSecondary,
                  size: DesignSystemButtonSize.medium,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'soul_proposal_rejected',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                ),
                primaryActionButton(
                  label: context.messages.agentTemplateEvolveApprove,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'soul_proposal_approved',
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
    final kind = readString(json, 'kind', 'reflection');
    final content = readString(json, 'content');

    return EvolutionNoteConfirmationCard(
      kind: kind,
      content: content,
    );
  },
);

/// Inline metrics summary widget.
final metricsSummaryItem = CatalogItem(
  name: 'MetricsSummary',
  dataSchema: _metricsSummarySchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final totalWakes = readInt(json, 'totalWakes');
    final successRate = readDouble(json, 'successRate');
    final failureCount = readInt(json, 'failureCount');
    final avgDuration = readNumOrNull(json, 'averageDurationSeconds');
    final activeInstances = readNumOrNull(json, 'activeInstances');

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
            metricChip(messages.agentEvolutionMetricWakes, '$totalWakes'),
            metricChip(
              messages.agentEvolutionMetricSuccess,
              '${(successRate * 100).toStringAsFixed(0)}%',
            ),
            metricChip(
              messages.agentEvolutionMetricFailures,
              '$failureCount',
            ),
            if (avgDuration != null)
              metricChip(
                messages.agentEvolutionMetricAvgDuration,
                '${avgDuration.toStringAsFixed(0)}s',
              ),
            if (activeInstances != null)
              metricChip(
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
    final beforeVersion = readInt(json, 'beforeVersion');
    final afterVersion = readInt(json, 'afterVersion');
    final beforeDirectives = readString(json, 'beforeDirectives');
    final afterDirectives = readString(json, 'afterDirectives');
    final changesSummary = readStringOrNull(json, 'changesSummary');
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
            sectionLabel(
              context,
              '${context.messages.agentEvolutionCurrentDirectives}'
              ' (v$beforeVersion)',
            ),
            const SizedBox(height: 6),
            directiveBox(
              context: context,
              text: beforeDirectives,
            ),
            const SizedBox(height: 12),
            sectionLabel(
              context,
              '${context.messages.agentEvolutionProposedDirectives}'
              ' (v$afterVersion)',
            ),
            const SizedBox(height: 6),
            directiveBox(
              context: context,
              text: afterDirectives,
              isHighlighted: true,
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
    final items = readMapList(json, 'items');
    final positiveCount = readInt(json, 'positiveCount');
    final negativeCount = readInt(json, 'negativeCount');
    final neutralCount = readInt(json, 'neutralCount');
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
              ...items
                  .take(5)
                  .map(
                    (item) => _feedbackLine(
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
  dataSchema: _feedbackCategoryBreakdownSchema,
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
  dataSchema: _sessionProgressSchema,
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

/// Interactive category ratings widget for Phase 1 of the two-phase dialog.
final categoryRatingsItem = CatalogItem(
  name: 'CategoryRatings',
  dataSchema: _categoryRatingsSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final categories = readMapList(json, 'categories');
    if (categories.isEmpty) return const SizedBox.shrink();

    return CategoryRatingsCard(
      categories: categories,
      onSubmit: (ratings) {
        final ratingsJson = jsonEncode(ratings);
        itemContext.dispatchEvent(
          UserActionEvent(
            name: 'ratings_submitted',
            sourceComponentId: ratingsJson,
            surfaceId: itemContext.surfaceId,
          ),
        );
      },
    );
  },
);

/// Lightweight yes/no prompt for quick conversational branching.
final binaryChoicePromptItem = CatalogItem(
  name: 'BinaryChoicePrompt',
  dataSchema: _binaryChoicePromptSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();

    final question = readString(json, 'question').trim();
    if (question.isEmpty) return const SizedBox.shrink();

    final detail = readString(json, 'detail').trim();
    final context = itemContext.buildContext;

    final confirmLabelRaw = readStringOrNull(json, 'confirmLabel')?.trim();
    final dismissLabelRaw = readStringOrNull(json, 'dismissLabel')?.trim();
    final confirmLabel = (confirmLabelRaw?.isNotEmpty ?? false)
        ? confirmLabelRaw!
        : context.messages.agentBinaryChoiceYes;
    final dismissLabel = (dismissLabelRaw?.isNotEmpty ?? false)
        ? dismissLabelRaw!
        : context.messages.agentBinaryChoiceNo;

    final confirmValueRaw = readStringOrNull(json, 'confirmValue')?.trim();
    final dismissValueRaw = readStringOrNull(json, 'dismissValue')?.trim();
    final confirmValue = (confirmValueRaw?.isNotEmpty ?? false)
        ? confirmValueRaw!
        : 'confirm';
    final dismissValue = (dismissValueRaw?.isNotEmpty ?? false)
        ? dismissValueRaw!
        : 'dismiss';

    return BinaryChoicePromptCard(
      question: question,
      detail: detail,
      confirmLabel: confirmLabel,
      dismissLabel: dismissLabel,
      confirmValue: confirmValue,
      dismissValue: dismissValue,
      onSelect: (value) => itemContext.dispatchEvent(
        UserActionEvent(
          name: 'binary_choice_submitted',
          sourceComponentId: jsonEncode({'value': value}),
          surfaceId: itemContext.surfaceId,
        ),
      ),
    );
  },
);

// ── A/B comparison schema & item ──────────────────────────────────────────

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

/// Self-contained A/B comparison widget showing two full option phrasings
/// as tappable cards. Used in soul evolution sessions for personality
/// preference exploration.
final abComparisonCardItem = CatalogItem(
  name: 'ABComparison',
  dataSchema: _abComparisonSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();

    final question = readString(json, 'question').trim();
    if (question.isEmpty) return const SizedBox.shrink();

    final optionA = readString(json, 'optionA').trim();
    final optionB = readString(json, 'optionB').trim();
    if (optionA.isEmpty || optionB.isEmpty) return const SizedBox.shrink();

    final labelA = readStringOrNull(json, 'labelA')?.trim() ?? '';
    final labelB = readStringOrNull(json, 'labelB')?.trim() ?? '';

    return ABComparisonCard(
      question: question,
      optionA: optionA,
      optionB: optionB,
      labelA: labelA,
      labelB: labelB,
      onSelect: (value) => itemContext.dispatchEvent(
        UserActionEvent(
          name: 'ab_comparison_submitted',
          sourceComponentId: jsonEncode({'value': value}),
          surfaceId: itemContext.surfaceId,
        ),
      ),
    );
  },
);

/// High-priority feedback card showing grievances (red) and excellence notes
/// (green) with full untruncated text.
final highPriorityFeedbackItem = CatalogItem(
  name: 'HighPriorityFeedback',
  dataSchema: _highPriorityFeedbackSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final grievances = readMapList(
      json,
      'grievances',
    ).where((item) => readString(item, 'detail').trim().isNotEmpty).toList();
    final excellenceNotes = readMapList(
      json,
      'excellenceNotes',
    ).where((item) => readString(item, 'detail').trim().isNotEmpty).toList();
    if (grievances.isEmpty && excellenceNotes.isEmpty) {
      return const SizedBox.shrink();
    }
    final context = itemContext.buildContext;
    final messages = context.messages;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: GameyGradients.cardDark(GameyColors.primaryRed),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.priority_high,
                  size: 18,
                  color: GameyColors.primaryRed,
                ),
                const SizedBox(width: 8),
                Text(
                  messages.agentFeedbackHighPriorityTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (grievances.isNotEmpty) ...[
              const SizedBox(height: 10),
              _highPrioritySectionHeader(
                messages.agentFeedbackGrievancesTitle,
                grievances.length,
                GameyColors.primaryRed,
              ),
              const SizedBox(height: 4),
              ...grievances.map(
                (item) => _highPriorityItemTile(
                  agentId: readString(item, 'agentId'),
                  detail: readString(item, 'detail'),
                  accentColor: GameyColors.primaryRed,
                ),
              ),
            ],
            if (excellenceNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _highPrioritySectionHeader(
                messages.agentFeedbackExcellenceTitle,
                excellenceNotes.length,
                GameyColors.primaryGreen,
              ),
              const SizedBox(height: 4),
              ...excellenceNotes.map(
                (item) => _highPriorityItemTile(
                  agentId: readString(item, 'agentId'),
                  detail: readString(item, 'detail'),
                  accentColor: GameyColors.primaryGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  },
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
