import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
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

/// The A2UI message processor that holds the evolution chat's surfaces.
typedef EvolutionSurfaces = MessageProcessor<ComponentImplementation>;

/// Builds the A2UI catalog for the evolution chat: the custom components the
/// LLM can instantiate via the `render_surface` tool.
CatalogImplementation buildEvolutionCatalog() => CatalogImplementation(
  id: evolutionCatalogId,
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [
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
);
