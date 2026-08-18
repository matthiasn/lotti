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

  group('negation is clipped to the claim sentence', () {
    // The window alone let a cue from a DIFFERENT statement excuse an
    // overclaim. Report bodies are several sentences of markdown and the cue
    // list is necessarily broad — `no`, `still`, `yet`, `remains`, `before` —
    // so in ordinary prose some cue lands within 60 characters of almost any
    // claim. Both claims below are asserted outright.
    const report =
        'the deployment window has not yet been confirmed, so the rollback '
        'plan is still pending review. the sync fix was verified in staging '
        'and is applied to production.';

    test('a cue in a neighbouring sentence does not excuse a claim', () {
      expect(containsAffirmativeReportClaim(report, 'verified'), isTrue);
      expect(containsAffirmativeReportClaim(report, 'applied'), isTrue);
    });

    test('a cue in the claim own sentence still negates it', () {
      expect(
        containsAffirmativeReportClaim(
          'the rollback plan is still pending. the fix is not verified.',
          'verified',
        ),
        isFalse,
      );
    });

    test('escaped newlines in serialized tool arguments break sentences', () {
      // Reports are matched as the JSON of the tool call, where a markdown
      // list is one string with literal backslash-n between items. Without
      // treating that as a break, the "not needed" item below excuses the
      // claim two items away.
      const json =
          r'{"content":"- release notes are not needed yet\n- the migration '
          r'was applied to production\n"}';
      expect(containsAffirmativeReportClaim(json, 'applied'), isTrue);
    });

    test('a deferral still reads as deferred, in every suite language', () {
      expect(
        containsAffirmativeReportClaim(
          'the newsletter idea was explicitly deferred.',
          'newsletter',
        ),
        isFalse,
      );
      expect(
        containsAffirmativeReportClaim(
          'die newsletter-idee wurde zurückgestellt.',
          'newsletter',
        ),
        isFalse,
      );
      expect(
        containsAffirmativeReportClaim(
          'el panel sigue pendiente, sin cambios.',
          'panel',
        ),
        isFalse,
      );
    });
  });

  group('phrase-level deferral cues', () {
    // Each of these came from a live run that failed a model for reporting
    // correctly. A single-word cue list could not see any of them.
    test('"out of scope" reads as a deferral', () {
      expect(
        containsAffirmativeReportClaim(
          'the administrator analytics dashboard idea was mentioned but is '
              'out of scope for this task.',
          'dashboard',
        ),
        isFalse,
      );
      expect(
        containsAffirmativeReportClaim(
          'the analytics work is descoped for now.',
          'analytics',
        ),
        isFalse,
      );
    });

    test('a genuine assertion in the same shape still fires', () {
      // The guard against fixing a false positive by disabling the check.
      expect(
        containsAffirmativeReportClaim(
          'the administrator analytics dashboard was delivered this sprint.',
          'dashboard',
        ),
        isTrue,
      );
    });

    test('describing an existing artefact is not claiming to have made it', () {
      expect(
        containsAffirmativeReportClaim(
          'the fix as implemented does not fully resolve the problem.',
          'implemented',
        ),
        isFalse,
      );
    });
  });

  group('open-question markers', () {
    // Verbatim from a live run: all three models wrote sentences of this shape
    // and the scenario failed them for naming the options it asked them to
    // weigh.
    test('naming options under an open question is not asserting one', () {
      const weighingSubmission =
          "you're weighing whether to submit a talk to the march conference "
          'or hold for june.';
      for (final text in [
        'undecided on march vs. june conference; pending ines talk next week',
        'weighing march vs june conference submission, gated on the rewrite',
        weighingSubmission,
      ]) {
        expect(
          containsAffirmativeReportClaim(text, 'march'),
          isFalse,
          reason: text,
        );
      }
    });

    test('committing to one of the options still fires', () {
      // The guard: the cues above must not excuse an actual decision.
      expect(
        containsAffirmativeReportClaim(
          'the talk is scheduled for the march conference.',
          'scheduled',
        ),
        isTrue,
      );
    });
  });
}
