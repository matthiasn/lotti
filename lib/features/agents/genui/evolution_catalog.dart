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

// ── Catalog Items ───────────────────────────────────────────────────────────

/// Proposal card with approve/reject actions.
final evolutionProposalItem = CatalogItem(
  name: 'EvolutionProposal',
  dataSchema: _proposalSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data as Map<String, Object?>;
    final directives = json['directives'] as String? ?? '';
    final rationale = json['rationale'] as String? ?? '';
    final currentDirectives = json['currentDirectives'] as String?;
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
    final json = itemContext.data as Map<String, Object?>;
    final kind = json['kind'] as String? ?? 'reflection';
    final content = json['content'] as String? ?? '';
    final context = itemContext.buildContext;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ModernBaseCard(
        gradient: GameyGradients.cardDark(GameyColors.aiCyan),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _noteKindIcon(kind),
              size: 18,
              color: GameyColors.aiCyan,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.messages.agentEvolutionNoteRecorded,
                    style: const TextStyle(
                      color: GameyColors.aiCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// Inline metrics summary widget.
final metricsSummaryItem = CatalogItem(
  name: 'MetricsSummary',
  dataSchema: _metricsSummarySchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data as Map<String, Object?>;
    final totalWakes = (json['totalWakes'] as num?)?.toInt() ?? 0;
    final successRate = (json['successRate'] as num?)?.toDouble() ?? 0;
    final failureCount = (json['failureCount'] as num?)?.toInt() ?? 0;
    final avgDuration = json['averageDurationSeconds'] as num?;
    final activeInstances = json['activeInstances'] as num?;

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
    final json = itemContext.data as Map<String, Object?>;
    final beforeVersion = (json['beforeVersion'] as num?)?.toInt() ?? 0;
    final afterVersion = (json['afterVersion'] as num?)?.toInt() ?? 0;
    final beforeDirectives = json['beforeDirectives'] as String? ?? '';
    final afterDirectives = json['afterDirectives'] as String? ?? '';
    final changesSummary = json['changesSummary'] as String?;
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
