import 'package:flutter_test/flutter_test.dart';

import 'support/goal_ad_image_probe.dart';

void main() {
  test('composed prompt is scene + headline/cta + mood/style + contract', () {
    final prompt = composeGoalAdImagePrompt(
      sceneConcept: 'Dusty running shoes on a couch.',
      headline: 'Your shoes miss you.',
      cta: 'Lace up now',
      mood: 'dryly comedic',
      stylePreset: 'bold flat poster',
    );
    expect(
      prompt,
      'Dusty running shoes on a couch.\n'
      "Render exactly this headline as the banner's display "
      'typography: "Your shoes miss you."\n'
      'Include a small call-to-action element reading exactly: '
      '"Lace up now"\n'
      'Mood: dryly comedic.\n'
      'Style: bold flat poster.\n'
      '$goalAdImageStyleContract',
    );
  });

  test('empty optional fields are omitted, the contract never is', () {
    final prompt = composeGoalAdImagePrompt(
      sceneConcept: '  A lighthouse at dawn.  ',
      headline: '  ',
      mood: '  ',
    );
    expect(
      prompt,
      'A lighthouse at dawn.\n$goalAdImageStyleContract',
    );
  });

  test('the contract demands banner design and bans any OTHER text', () {
    // Headline + CTA are the only sanctioned type; stray words, digits and
    // logos stay banned so user data cannot ride in as set dressing.
    expect(goalAdImageStyleContract, contains('advertising banner'));
    expect(goalAdImageStyleContract, contains('display typography'));
    expect(goalAdImageStyleContract, contains('no other readable text'));
    expect(goalAdImageStyleContract, contains('no digits'));
    expect(goalAdImageStyleContract, contains('16:9'));
  });
}
