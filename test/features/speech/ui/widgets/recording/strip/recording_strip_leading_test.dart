import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'strip_test_bench.dart';

void main() {
  group('isOnRecordingOrigin', () {
    const origin = RecordingOrigin(route: '/tasks/task-1');

    for (final (route, expected) in [
      ('/tasks/task-1', true),
      ('/tasks/task-1/', true),
      ('/tasks/task-1?tab=checklist', true),
      ('/tasks/task-2', false),
      ('/tasks', false),
      ('/calendar', false),
    ]) {
      test('$route is ${expected ? '' : 'not '}the origin', () {
        expect(isOnRecordingOrigin(route, origin), expected);
      });
    }

    test('the root route survives normalisation', () {
      expect(
        isOnRecordingOrigin('/', const RecordingOrigin(route: '/')),
        isTrue,
      );
    });

    test('no origin is never here', () {
      expect(isOnRecordingOrigin('/tasks/task-1', null), isFalse);
    });
  });

  group('RecordingStripLeading', () {
    late StripBench bench;

    setUp(() => bench = StripBench());
    tearDown(() => bench.dispose());

    Future<void> pump(WidgetTester tester) => bench.pump(
      tester,
      const SizedBox(width: 280, height: 56, child: RecordingStripLeading()),
    );

    Finder back() => find.byKey(RecordingStripLeading.backKey);

    testWidgets('away from the origin it is the way back: ←, "Recording '
        'for" and the subject, one button that goes there', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await bench.startTake(tester);

      expect(find.byIcon(LottiIcons.back), findsOneWidget);
      expect(find.text('Recording for'), findsOneWidget);
      expect(find.text(stripSubject.data.title), findsOneWidget);
      expect(
        find.bySemanticsLabel('Back to ${stripSubject.data.title}'),
        findsOneWidget,
      );
      final node = tester.getSemantics(back());
      expect(node.value, 'Recording for');
      expect(node.flagsCollection.isLiveRegion, isTrue);

      await tester.tap(back());
      await tester.pump();
      await tester.pump();
      verify(() => bench.nav.beamToNamed(stripSubjectRoute)).called(1);
      semantics.dispose();
    });

    testWidgets('paused, the caption says so', (tester) async {
      await pump(tester);
      await bench.startTake(tester);
      await bench.recorder.pause();
      await tester.pump();

      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('on the origin it says "Recording here" beside the red dot, '
        'and is not a button', (tester) async {
      bench.route = stripSubjectRoute;
      await pump(tester);
      await bench.startTake(tester);

      expect(find.text('Recording here'), findsOneWidget);
      expect(find.byType(DesignSystemBadge), findsOneWidget);
      expect(back(), findsNothing);
      expect(find.byIcon(LottiIcons.back), findsNothing);
    });

    testWidgets('paused on the origin: "Paused here" beside the pause '
        'glyph', (tester) async {
      bench.route = stripSubjectRoute;
      await pump(tester);
      await bench.startTake(tester);
      await bench.recorder.pause();
      await tester.pump();

      expect(find.text('Paused here'), findsOneWidget);
      expect(find.byIcon(LottiIcons.pause), findsOneWidget);
      expect(find.byType(DesignSystemBadge), findsNothing);
    });

    testWidgets('it follows the route on screen: arriving at the origin '
        'turns the way back into "here", and leaving turns it back', (
      tester,
    ) async {
      await pump(tester);
      await bench.startTake(tester);
      expect(back(), findsOneWidget);

      bench.route = stripSubjectRoute;
      await tester.pump();
      expect(find.text('Recording here'), findsOneWidget);
      expect(back(), findsNothing);

      bench.route = '/journal';
      await tester.pump();
      expect(back(), findsOneWidget);
    });

    testWidgets('a voice note reads "Voice note" and is never a button, '
        'wherever the user is', (tester) async {
      await pump(tester);
      await bench.startTake(tester, voiceNote: true, route: '/journal');

      expect(find.text('Voice note'), findsOneWidget);
      expect(back(), findsNothing);

      bench.route = '/journal';
      await tester.pump();
      expect(find.text('Voice note'), findsOneWidget);
    });

    testWidgets('a subject deleted mid-take reads as a voice note, with no '
        'way back', (tester) async {
      when(
        () => bench.db.journalEntityById(stripSubjectId),
      ).thenAnswer((_) async => null);
      await pump(tester);
      await bench.startTake(tester);

      expect(find.text('Voice note'), findsOneWidget);
      expect(back(), findsNothing);
    });

    testWidgets('a subject with no words to name it by still has its way '
        'back', (tester) async {
      when(() => bench.db.journalEntityById(stripSubjectId)).thenAnswer(
        (_) async =>
            stripSubject.copyWith(data: stripSubject.data.copyWith(title: '')),
      );
      await pump(tester);
      await bench.startTake(tester);

      expect(back(), findsOneWidget);
      expect(find.text('Voice note'), findsNothing);
    });

    testWidgets('a take with no origin names its subject but offers no '
        'way back', (tester) async {
      await pump(tester);
      await bench.recorder.record(linkedId: stripSubjectId);
      await tester.pump();
      await tester.pump();

      expect(find.text('Recording for'), findsOneWidget);
      expect(find.text(stripSubject.data.title), findsOneWidget);
      expect(back(), findsNothing);
      expect(find.byType(DesignSystemBadge), findsOneWidget);
    });

    testWidgets('a long title ellipsises on one line rather than wrapping', (
      tester,
    ) async {
      when(() => bench.db.journalEntityById(stripSubjectId)).thenAnswer(
        (_) async => stripSubject.copyWith(
          data: stripSubject.data.copyWith(
            title:
                'Inspect the orbital penguin habitat and its air scrubbers '
                'before the Friday review',
          ),
        ),
      );
      await pump(tester);
      await bench.startTake(tester);

      final title = tester.widget<Text>(
        find.textContaining('Inspect the orbital'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('its words come from the typography tokens', (tester) async {
      await pump(tester);
      await bench.startTake(tester);
      final tokens = tester
          .element(find.byType(RecordingStripLeading))
          .designTokens;

      expect(
        tester.widget<Text>(find.text('Recording for')).style?.fontSize,
        tokens.typography.styles.others.caption.fontSize,
      );
      expect(
        tester.widget<Text>(find.text(stripSubject.data.title)).style?.fontSize,
        tokens.typography.styles.body.bodySmall.fontSize,
      );
    });
  });
}
