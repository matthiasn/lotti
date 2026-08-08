import 'package:flutter_test/flutter_test.dart';

import 'support/eval_text_matchers.dart';

void main() {
  group('containsAnyEvalTerm', () {
    test('matches any group member, case-insensitively', () {
      expect(
        containsAnyEvalTerm('The TRACKER was offline', ['tracker']),
        isTrue,
      );
      expect(containsAnyEvalTerm('all good', ['tracker', 'gap']), isFalse);
    });
  });

  group('containsAffirmativeReportClaim', () {
    test('a plain assertion is affirmative', () {
      expect(
        containsAffirmativeReportClaim('the fix is validated', 'validated'),
        isTrue,
      );
    });

    test('a negated assertion is not', () {
      expect(
        containsAffirmativeReportClaim(
          'the fix is not yet validated',
          'validated',
        ),
        isFalse,
      );
    });

    test('a window cut cannot fabricate a cue from a severed word', () {
      // Position "casino" so the 60-char window boundary falls after
      // "casi", leaving "no" at the context start — a whole-word cue for
      // the un-fixed matcher. The claim is plainly asserted, so this must
      // stay affirmative.
      const claim = 'delivered';
      final text = '${'x' * 4} casino ${'y' * 56} $claim';
      final index = text.indexOf(claim);
      final cut = text[index - 60];
      expect(
        'casino'.contains(cut),
        isTrue,
        reason: 'the cut must land inside "casino" for this test to bite',
      );
      expect(containsAffirmativeReportClaim(text, claim), isTrue);
    });

    test('an intact cue inside the window still negates', () {
      final text = 'we cannot say it was ${'y' * 20} delivered';
      expect(containsAffirmativeReportClaim(text, 'delivered'), isFalse);
    });
  });
}
