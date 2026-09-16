import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/notifications/producer/agent_alert_copy.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

NudgeBrief _brief({
  String headline = "Check in with Anna — it's been 2 weeks.",
  String? tagline,
  String? cta,
}) => NudgeBrief(
  headline: headline,
  tone: NudgeTone.nudge,
  animation: NudgeBannerAnimation.steady,
  tagline: tagline,
  cta: cta,
);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockGoalOffTrackSink alerts;
  late MockDomainLogger logger;
  late bool allowed;

  AgentAlertCopy copy({Future<bool> Function()? isAllowed}) => AgentAlertCopy(
    alerts: alerts,
    isAllowed: isAllowed ?? () async => allowed,
    logger: logger,
  );

  setUp(() {
    alerts = MockGoalOffTrackSink();
    logger = MockDomainLogger();
    allowed = true;
    when(
      () => alerts.restate(
        any(),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
  });

  void verifyNothingRestated() => verifyNever(
    () => alerts.restate(
      any(),
      title: any(named: 'title'),
      body: any(named: 'body'),
    ),
  );

  group('AgentAlertCopy.fromBrief', () {
    test('the headline is the title and the tagline the body', () {
      final result = AgentAlertCopy.fromBrief(
        _brief(tagline: 'Last time: the move.', cta: 'Call her'),
      );

      expect(result, (
        title: "Check in with Anna — it's been 2 weeks.",
        body: 'Last time: the move.',
      ));
    });

    test('without a tagline the call to action is the body', () {
      expect(
        AgentAlertCopy.fromBrief(_brief(cta: 'Call her')),
        (title: "Check in with Anna — it's been 2 weeks.", body: 'Call her'),
      );
    });

    test('with neither, the body is left to the row', () {
      expect(
        AgentAlertCopy.fromBrief(_brief()),
        (title: "Check in with Anna — it's been 2 weeks.", body: null),
      );
    });

    test('a blank headline is nothing worth re-wording for', () {
      expect(AgentAlertCopy.fromBrief(_brief(headline: '  \n ')), isNull);
      expect(
        AgentAlertCopy.fromBrief(_brief(headline: '', tagline: 'body')),
        isNull,
      );
    });

    test('a tagline that fits to nothing is dropped, not sent blank', () {
      expect(AgentAlertCopy.fromBrief(_brief(tagline: '   '))!.body, isNull);
    });
  });

  group('AgentAlertCopy.fit', () {
    test('collapses whitespace runs and line breaks to one line', () {
      expect(
        AgentAlertCopy.fit('  Your\n pedometer   misses\tyou. ', 80),
        'Your pedometer misses you.',
      );
    });

    test('a line at the limit is untouched', () {
      final exact = 'x' * 80;
      expect(AgentAlertCopy.fit(exact, 80), exact);
    });

    test(
      'a longer line is cut at the last word boundary, with an ellipsis',
      () {
        final words = List.generate(30, (i) => 'word$i').join(' ');

        final fitted = AgentAlertCopy.fit(words, 40);

        expect(fitted.length, lessThanOrEqualTo(40));
        expect(fitted, endsWith('…'));
        expect(fitted, isNot(contains('…w')), reason: 'never mid-word');
        expect(words, startsWith(fitted.substring(0, fitted.length - 2)));
      },
    );

    test('one unbroken word past the limit is cut hard', () {
      final fitted = AgentAlertCopy.fit('a' * 100, 20);

      expect(fitted, '${'a' * 19}…');
    });

    test('the title and body limits fit a lock screen', () {
      final result = AgentAlertCopy.fromBrief(
        _brief(headline: 'h ' * 200, tagline: 'b ' * 200),
      );

      expect(
        result!.title.length,
        lessThanOrEqualTo(AgentAlertCopy.titleLimit),
      );
      expect(result.body!.length, lessThanOrEqualTo(AgentAlertCopy.bodyLimit));
    });
  });

  group('AgentAlertCopy.fromFlags', () {
    late MockJournalDb journalDb;

    setUp(() => journalDb = MockJournalDb());

    AgentAlertCopy fromFlags() => AgentAlertCopy.fromFlags(
      alerts: alerts,
      journalDb: journalDb,
      logger: logger,
    );

    test('the say is the notify_agent_copy flag, read per wake', () async {
      when(
        () => journalDb.getConfigFlag(notifyAgentCopyFlag),
      ).thenAnswer((_) async => true);

      await fromFlags().restate(subjectId: 'agent-1', brief: _brief());

      verify(
        () => alerts.restate(
          'agent-1',
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).called(1);
      verify(() => journalDb.getConfigFlag(notifyAgentCopyFlag)).called(1);
    });

    test(
      'with the flag off — the shipped default — nothing is re-worded',
      () async {
        when(
          () => journalDb.getConfigFlag(notifyAgentCopyFlag),
        ).thenAnswer((_) async => false);

        await fromFlags().restate(subjectId: 'agent-1', brief: _brief());

        verifyNothingRestated();
      },
    );
  });

  group('AgentAlertCopy.restate', () {
    test(
      're-words the armed alert with the brief when the user allows it',
      () async {
        await copy().restate(
          subjectId: 'agent-1',
          brief: _brief(tagline: 'Last time: the move.'),
        );

        verify(
          () => alerts.restate(
            'agent-1',
            title: "Check in with Anna — it's been 2 weeks.",
            body: 'Last time: the move.',
          ),
        ).called(1);
      },
    );

    test('does nothing while the user has not opted in', () async {
      allowed = false;

      await copy().restate(subjectId: 'agent-1', brief: _brief());

      // The default: the template copy stands (ADR 0039 Decision 6).
      verifyNothingRestated();
    });

    test('reads the preference at the moment of the wake', () async {
      var reads = 0;
      final instance = copy(
        isAllowed: () async {
          reads++;
          return reads > 1;
        },
      );

      await instance.restate(subjectId: 'agent-1', brief: _brief());
      await instance.restate(subjectId: 'agent-1', brief: _brief());

      verify(
        () => alerts.restate(
          'agent-1',
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('a brief with a blank headline re-words nothing', () async {
      await copy().restate(
        subjectId: 'agent-1',
        brief: _brief(headline: ' '),
      );

      verifyNothingRestated();
    });

    test('a sink failure is logged and never escapes the wake', () async {
      when(
        () => alerts.restate(
          any(),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenThrow(StateError('store gone'));

      await expectLater(
        copy().restate(subjectId: 'agent-1', brief: _brief()),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'agentAlertCopy.restate',
        ),
      ).called(1);
    });

    test('a preference read failure is contained the same way', () async {
      final instance = copy(isAllowed: () => throw StateError('db gone'));

      await expectLater(
        instance.restate(subjectId: 'agent-1', brief: _brief()),
        completes,
      );

      verifyNothingRestated();
      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'agentAlertCopy.restate',
        ),
      ).called(1);
    });
  });
}
