import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';

/// These names are PERSISTED vocabulary: `GoalTrackStatus.name` is the
/// `goalProgress` row's indexed `subtype`, `GoalSpecVersionStatus.name` is
/// the spec version's subtype, and the eval report tool's status enum is
/// derived from these values. Renaming a member is a silent data-corruption
/// change — this test makes it a loud one.
void main() {
  test('GoalTrackStatus serialized names are frozen', () {
    expect(GoalTrackStatus.values.map((v) => v.name), [
      'onTrack',
      'atRisk',
      'offTrack',
      'recovering',
      'achieved',
      'insufficientData',
    ]);
  });

  test('GoalSpecVersionStatus serialized names are frozen', () {
    expect(GoalSpecVersionStatus.values.map((v) => v.name), [
      'active',
      'superseded',
    ]);
  });

  test('aggregation and direction names are frozen', () {
    expect(GoalAggregation.values.map((v) => v.name), [
      'dailySumThenAverage',
      'sum',
      'count',
      'max',
    ]);
    expect(GoalDirection.values.map((v) => v.name), ['atLeast', 'atMost']);
  });
}
