import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';

extension _AnyChecklistConfidence on glados.Any {
  glados.Generator<ChecklistCompletionConfidence> get checklistConfidence =>
      glados.AnyUtils(this).choose(ChecklistCompletionConfidence.values);
}

void main() {
  group('ChecklistCompletionSuggestion.fromJson', () {
    test('deserializes all fields including known confidence levels', () {
      for (final entry in {
        'high': ChecklistCompletionConfidence.high,
        'medium': ChecklistCompletionConfidence.medium,
        'low': ChecklistCompletionConfidence.low,
      }.entries) {
        final suggestion = ChecklistCompletionSuggestion.fromJson({
          'checklistItemId': 'item-123',
          'reason': 'mentioned as done in transcript',
          'confidence': entry.key,
        });

        expect(suggestion.checklistItemId, 'item-123');
        expect(suggestion.reason, 'mentioned as done in transcript');
        expect(suggestion.confidence, entry.value);
      }
    });

    test('falls back to low confidence for unknown enum value', () {
      final suggestion = ChecklistCompletionSuggestion.fromJson({
        'checklistItemId': 'item-456',
        'reason': 'unclear',
        'confidence': 'totally-unknown',
      });

      expect(suggestion.checklistItemId, 'item-456');
      expect(suggestion.confidence, ChecklistCompletionConfidence.low);
    });

    // Round-trip property: serializing then deserializing must reconstruct an
    // equal value for any field combination. This catches schema-vs-generated
    // (de)serializer drift across the whole input space, not just hand picks.
    glados.Glados<(String, String, ChecklistCompletionConfidence)>(
      glados.CombinableAny(glados.any).combine3(
        glados.any.letterOrDigits,
        glados.any.letterOrDigits,
        glados.any.checklistConfidence,
        (String id, String reason, ChecklistCompletionConfidence c) =>
            (id, reason, c),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'fromJson(toJson(x)) == x',
      (triple) {
        final original = ChecklistCompletionSuggestion(
          checklistItemId: triple.$1,
          reason: triple.$2,
          confidence: triple.$3,
        );
        expect(
          ChecklistCompletionSuggestion.fromJson(original.toJson()),
          original,
        );
      },
      tags: 'glados',
    );
  });
}
