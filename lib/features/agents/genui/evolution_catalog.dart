import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_feedback_items.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_interaction_items.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_metrics_items.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_proposal_items.dart';

export 'package:lotti/features/agents/genui/evolution_catalog_feedback_items.dart';
export 'package:lotti/features/agents/genui/evolution_catalog_interaction_items.dart';
export 'package:lotti/features/agents/genui/evolution_catalog_metrics_items.dart';
export 'package:lotti/features/agents/genui/evolution_catalog_proposal_items.dart';
export 'package:lotti/features/agents/genui/evolution_catalog_schemas.dart';

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
