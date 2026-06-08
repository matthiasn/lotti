part of 'evolution_catalog.dart';

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

// ── A/B comparison item ──────────────────────────────────────────────────

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
        gradient: agentCardDarkGradient(AgentPalette.red),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.priority_high,
                  size: 18,
                  color: AgentPalette.red,
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
                AgentPalette.red,
              ),
              const SizedBox(height: 4),
              ...grievances.map(
                (item) => _highPriorityItemTile(
                  agentId: readString(item, 'agentId'),
                  detail: readString(item, 'detail'),
                  accentColor: AgentPalette.red,
                ),
              ),
            ],
            if (excellenceNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _highPrioritySectionHeader(
                messages.agentFeedbackExcellenceTitle,
                excellenceNotes.length,
                AgentPalette.green,
              ),
              const SizedBox(height: 4),
              ...excellenceNotes.map(
                (item) => _highPriorityItemTile(
                  agentId: readString(item, 'agentId'),
                  detail: readString(item, 'detail'),
                  accentColor: AgentPalette.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  },
);
