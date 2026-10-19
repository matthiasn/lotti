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

  test('sleepy is the only record mood with heavy lids, and breathes '
      'slowest of all', () {
    const record = [
      CompanionMood.calm,
      CompanionMood.bright,
      CompanionMood.busy,
      CompanionMood.frazzled,
      CompanionMood.sleepy,
    ];
    for (final m in record) {
      if (m == CompanionMood.sleepy) {
        expect(m.lids, greaterThan(0));
      } else {
        expect(m.lids, 0, reason: m.name);
      }
    }
    for (final m in CompanionMood.values) {
      expect(
        m.breathRate,
        greaterThanOrEqualTo(CompanionMood.sleepy.breathRate),
        reason: m.name,
      );
    }
  });

  test('no record mood frowns past her resting smile', () {
    // The base smile is 0.3 while talking: a mood read from the record may
    // soften it, never turn it into a scowl. Only reactions frown.
    for (final m in [
      CompanionMood.calm,
      CompanionMood.bright,
      CompanionMood.busy,
      CompanionMood.frazzled,
      CompanionMood.sleepy,
    ]) {
      expect(0.3 + m.smile, greaterThanOrEqualTo(0), reason: m.name);
    }
  });

  test('the disapproving reactions frown, even at her idle smile', () {
    // Idle, her base smile is 0.5.
    for (final m in [
      CompanionMood.disappointed,
      CompanionMood.stern,
      CompanionMood.unimpressed,
      CompanionMood.skeptical,
    ]) {
      expect(0.5 + m.smile, lessThan(0), reason: m.name);
    }
  });

  test('smug and skeptical are the lopsided faces', () {
    for (final m in CompanionMood.values) {
      final lopsided = m == CompanionMood.smug || m == CompanionMood.skeptical;
      expect(m.smileSkew != 0 || m.browSkew != 0, lopsided, reason: m.name);
    }
    // A smirk lifts the corner on the side of the raised brow; skepticism
    // pulls the mouth the other way.
    expect(CompanionMood.smug.smileSkew, greaterThan(0));
    expect(CompanionMood.smug.browSkew, greaterThan(0));
    expect(CompanionMood.skeptical.smileSkew, lessThan(0));
    expect(
      CompanionMood.skeptical.browSkew,
      greaterThan(CompanionMood.smug.browSkew),
    );
  });

  test('stern draws the brows down and in; disappointed lifts them inside', () {
    expect(CompanionMood.stern.brow, lessThan(0));
    expect(CompanionMood.stern.tilt, lessThan(0));
    expect(CompanionMood.disappointed.tilt, greaterThan(0));
  });
}
