import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:lotti/features/agents/genui/ab_comparison_card.dart';
import 'package:lotti/features/agents/genui/binary_choice_prompt_card.dart';
import 'package:lotti/features/agents/genui/category_ratings_card.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';
import 'package:lotti/features/agents/genui/evolution_note_confirmation_card.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

part 'evolution_catalog_schemas.dart';
part 'evolution_catalog_proposal_items.dart';
part 'evolution_catalog_metrics_items.dart';
part 'evolution_catalog_feedback_items.dart';
part 'evolution_catalog_interaction_items.dart';

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
