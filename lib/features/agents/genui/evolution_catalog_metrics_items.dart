part of 'evolution_catalog.dart';

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
        gradient: agentCardDarkGradient(AgentPalette.surfaceDarkElevated),
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
        gradient: agentCardDarkGradient(AgentPalette.surfaceDarkElevated),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.compare_arrows,
                  size: 20,
                  color: AgentPalette.cyan,
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
