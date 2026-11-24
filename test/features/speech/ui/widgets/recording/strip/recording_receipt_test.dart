import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_receipt.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'strip_test_bench.dart';

void main() {
  late StripBench bench;

  setUp(() => bench = StripBench());
  tearDown(() => bench.dispose());

  final origin = RecordingOrigin(
    route: stripSubjectRoute,
    subjectId: stripSubjectId,
  );

  /// Puts up a receipt through the real controller and pumps its row.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String? subjectId,
    String? subjectTitle = 'Fix the airlock',
    RecordingOrigin? receiptOrigin,
    bool transcribing = true,
    MediaQueryData? mediaQueryData,
  }) async {
    await bench.pump(
      tester,
      Consumer(
        builder: (context, ref, _) {
          final receipt = ref.watch(recordingReceiptControllerProvider);
          return SizedBox(
            width: 390,
            child: receipt == null
                ? const SizedBox.shrink()
                : RecordingReceiptRow(receipt: receipt),
          );
        },
      ),
      mediaQueryData:
          mediaQueryData ?? const MediaQueryData(size: Size(390, 844)),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    container
        .read(recordingReceiptControllerProvider.notifier)
        .show(
          entryId: 'audio-1',
          duration: const Duration(seconds: 42),
          subjectId: subjectId ?? stripSubjectId,
          subjectTitle: subjectTitle,
          origin: receiptOrigin ?? origin,
          transcribing: transcribing,
        );
    await tester.pump();
    return container;
  }

  Finder undo() => find.byKey(RecordingReceiptRow.undoKey);
  Finder open() => find.byKey(RecordingReceiptRow.openKey);

  testWidgets('says where the take was saved, how long it ran and that it '
      'is being transcribed', (tester) async {
    final container = await pump(tester);

    expect(find.text('Saved to Fix the airlock'), findsOneWidget);
    expect(find.text('00:42 · transcribing'), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
    container.read(recordingReceiptControllerProvider.notifier).commit();
  });

  testWidgets('says nothing of a transcript where none will run', (
    tester,
  ) async {
    final container = await pump(tester, transcribing: false);
    expect(find.text('00:42'), findsOneWidget);
    expect(find.textContaining('transcribing'), findsNothing);
    container.read(recordingReceiptControllerProvider.notifier).commit();
  });

  testWidgets('a take with no title reads "Voice note saved"', (tester) async {
    final container = await pump(tester, subjectTitle: null);
    expect(find.text('Voice note saved'), findsOneWidget);
    container.read(recordingReceiptControllerProvider.notifier).commit();
  });

  testWidgets('is as tall as the strip it replaces', (tester) async {
    final container = await pump(tester);
    expect(
      tester.getSize(find.byKey(RecordingReceiptRow.receiptKey)).height,
      RecordingStrip.height(tester.element(undo())),
    );
    container.read(recordingReceiptControllerProvider.notifier).commit();
  });

  group('Open', () {
    testWidgets('shows away from where the take started, and goes back '
        'there, committing the take', (tester) async {
      final container = await pump(tester);
      expect(open(), findsOneWidget);

      await tester.tap(open());
      await tester.pump();
      await tester.pump();

      expect(container.read(recordingReceiptControllerProvider), isNull);
      expect(bench.recorder.committedAutomation, ['audio-1']);
      verify(() => bench.nav.beamToNamed(stripSubjectRoute)).called(1);
    });

    testWidgets('is left out where the take started', (tester) async {
      bench.route = stripSubjectRoute;
      final container = await pump(tester);
      expect(open(), findsNothing);
      expect(undo(), findsOneWidget);
      container.read(recordingReceiptControllerProvider.notifier).commit();
    });

    testWidgets('comes and goes with the route on screen', (tester) async {
      final container = await pump(tester);
      bench.route = stripSubjectRoute;
      await tester.pump();
      expect(open(), findsNothing);
      bench.route = '/calendar';
      await tester.pump();
      expect(open(), findsOneWidget);
      container.read(recordingReceiptControllerProvider.notifier).commit();
    });
  });

  testWidgets('Undo deletes the take', (tester) async {
    final container = await pump(tester);
    await tester.tap(undo());
    await tester.pump();

    verify(() => bench.repository.deleteJournalEntity('audio-1')).called(1);
    expect(container.read(recordingReceiptControllerProvider), isNull);
    expect(bench.recorder.droppedAutomation, ['audio-1']);
  });

  testWidgets('its words are a live region, so the save is heard once', (
    tester,
  ) async {
    final container = await pump(tester);
    expect(
      find.ancestor(
        of: find.text('Saved to Fix the airlock'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.liveRegion ?? false),
        ),
      ),
      findsOneWidget,
    );
    container.read(recordingReceiptControllerProvider.notifier).commit();
  });

  testWidgets('its tick is the success ink', (tester) async {
    final container = await pump(tester);
    final tokens = tester.element(undo()).designTokens;
    expect(
      tester.widget<Icon>(find.byIcon(LottiIcons.confirm)).color,
      tokens.colors.alert.success.defaultColor,
    );
    container.read(recordingReceiptControllerProvider.notifier).commit();
  });
}
