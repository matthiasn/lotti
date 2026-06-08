
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';


void main() {
  group('buildEvolutionCatalog', () {
    test('contains all catalog items', () {
      final catalog = buildEvolutionCatalog();
      final items = catalog.items;

      expect(items, hasLength(12));
      expect(
        items.map((i) => i.name),
        containsAll([
          'EvolutionProposal',
          'SoulProposal',
          'EvolutionNoteConfirmation',
          'MetricsSummary',
          'VersionComparison',
          'FeedbackClassification',
          'FeedbackCategoryBreakdown',
          'SessionProgress',
          'CategoryRatings',
          'BinaryChoicePrompt',
          'ABComparison',
          'HighPriorityFeedback',
        ]),
      );
    });

    test('has the correct catalog ID', () {
      final catalog = buildEvolutionCatalog();
      expect(catalog.catalogId, evolutionCatalogId);
    });
  });
}
