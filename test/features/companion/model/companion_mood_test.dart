import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';

void main() {
  test('calm is neutral: it changes nothing', () {
    const m = CompanionMood.calm;
    expect(
      [m.smile, m.squint, m.brow, m.tilt, m.lids, m.pitch, m.bounce],
      [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ],
    );
    expect([m.glanceRate, m.blinkRate, m.breathRate], [1, 1, 1]);
  });

  test('bright smiles more than calm, and bounces', () {
    expect(CompanionMood.bright.smile, greaterThan(0));
    expect(CompanionMood.bright.bounce, greaterThan(0));
  });

  test('frazzled worries more than busy, never by closing the eyes', () {
    expect(CompanionMood.frazzled.tilt, greaterThan(CompanionMood.busy.tilt));
    expect(
      CompanionMood.frazzled.blinkRate,
      greaterThan(CompanionMood.busy.blinkRate),
    );
    expect(CompanionMood.frazzled.lids, 0);
  });

  test('sleepy is the only mood with heavy lids and slower breath', () {
    for (final m in CompanionMood.values) {
      if (m == CompanionMood.sleepy) {
        expect(m.lids, greaterThan(0));
        expect(m.breathRate, lessThan(1));
      } else {
        expect(m.lids, 0, reason: m.name);
      }
    }
  });

  test('no mood frowns past her resting smile', () {
    // The base smile is 0.3 while talking: a mood may soften it, never turn
    // it into a scowl.
    for (final m in CompanionMood.values) {
      expect(0.3 + m.smile, greaterThanOrEqualTo(0), reason: m.name);
    }
  });
}
