import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:lotti/features/agents/genui/ab_comparison_card.dart';
import 'package:lotti/features/agents/genui/binary_choice_prompt_card.dart';
import 'package:lotti/features/agents/genui/category_ratings_card.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_schemas.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:material_ui/material_ui.dart';

/// Interactive category ratings widget for Phase 1 of the two-phase dialog.
final categoryRatingsItem = ComponentImplementation(
  name: 'CategoryRatings',
  schema: categoryRatingsSchema,
  builder: (buildContext, node, props, _) {
    final json = evolutionProps(props);
    final categories = readMapList(json, 'categories');
    if (categories.isEmpty) return const SizedBox.shrink();

    return CategoryRatingsCard(
      categories: categories,
      onSubmit: (ratings) {
        evolutionAction(buildContext, node, 'ratings_submitted', {
          'ratings': ratings,
        });
      },
    );
  },
);

/// Lightweight yes/no prompt for quick conversational branching.
final binaryChoicePromptItem = ComponentImplementation(
  name: 'BinaryChoicePrompt',
  schema: binaryChoicePromptSchema,
  builder: (buildContext, node, props, _) {
    final json = evolutionProps(props);

    final question = readString(json, 'question').trim();
    if (question.isEmpty) return const SizedBox.shrink();

    final detail = readString(json, 'detail').trim();
    final context = buildContext;

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
      onSelect: (value) => evolutionAction(
        buildContext,
        node,
        'binary_choice_submitted',
        {'value': value},
      ),
    );
  },
);

// ── A/B comparison item ──────────────────────────────────────────────────

/// Self-contained A/B comparison widget showing two full option phrasings
/// as tappable cards. Used in soul evolution sessions for personality
/// preference exploration.
final abComparisonCardItem = ComponentImplementation(
  name: 'ABComparison',
  schema: abComparisonSchema,
  builder: (buildContext, node, props, _) {
    final json = evolutionProps(props);

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
      onSelect: (value) => evolutionAction(
        buildContext,
        node,
        'ab_comparison_submitted',
        {'value': value},
      ),
    );
  },
);

/// High-priority feedback card showing grievances (red) and excellence notes
/// (green) with full untruncated text.
final highPriorityFeedbackItem = ComponentImplementation(
  name: 'HighPriorityFeedback',
  schema: highPriorityFeedbackSchema,
  builder: (buildContext, node, props, _) {
    final json = evolutionProps(props);
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
    final context = buildContext;
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
                  LottiIcons.warning,
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
              highPrioritySectionHeader(
                messages.agentFeedbackGrievancesTitle,
                grievances.length,
                AgentPalette.red,
              ),
              const SizedBox(height: 4),
              ...grievances.map(
                (item) => highPriorityItemTile(
                  agentId: readString(item, 'agentId'),
                  detail: readString(item, 'detail'),
                  accentColor: AgentPalette.red,
                ),
              ),
            ],
            if (excellenceNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              highPrioritySectionHeader(
                messages.agentFeedbackExcellenceTitle,
                excellenceNotes.length,
                AgentPalette.green,
              ),
              const SizedBox(height: 4),
              ...excellenceNotes.map(
                (item) => highPriorityItemTile(
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
