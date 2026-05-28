import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/captures_panel.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

final _date = DateTime(2026, 5, 26);
final StreamProvider<int> _capturesReloadTickProvider = StreamProvider<int>(
  (ref) => const Stream<int>.empty(),
);

CaptureEntity _capture({
  required String id,
  required String transcript,
  required DateTime at,
  String? audioRef,
}) => CaptureEntity(
  id: id,
  agentId: 'agent_day_2026_05_26',
  transcript: transcript,
  capturedAt: at,
  createdAt: at,
  vectorClock: null,
  audioRef: audioRef,
);

CaptureWithAudio _row({
  required String id,
  required String transcript,
  required DateTime at,
}) => CaptureWithAudio(
  capture: _capture(id: id, transcript: transcript, at: at),
);

Widget _wrap(
  Widget child, {
  required List<CaptureWithAudio> captures,
}) {
  return ProviderScope(
    overrides: [
      capturesForDateProvider.overrideWith((ref, _) async => captures),
    ],
    child: makeTestableWidget2(
      Material(child: child),
      mediaQueryData: const MediaQueryData(size: Size(800, 1000)),
    ),
  );
}

void main() {
  group('CapturesPanel', () {
    testWidgets('empty capture list collapses to SizedBox.shrink', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CapturesPanel(date: _date), captures: const []),
      );
      await tester.pump();

      final messages = tester.element(find.byType(CapturesPanel)).messages;
      expect(find.text(messages.dailyOsNextCapturesPanelTitle), findsNothing);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets(
      'with one capture: header shows count and is collapsed by default',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CapturesPanel(date: _date),
            captures: [
              _row(
                id: 'c1',
                transcript: 'pick up groceries',
                at: DateTime(2026, 5, 26, 9, 5),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturesPanel)).messages;
        expect(
          find.text(messages.dailyOsNextCapturesPanelTitle),
          findsOneWidget,
        );
        // Count shown next to the title.
        expect(find.text('·  1'), findsOneWidget);
        // Collapsed: the transcript text should NOT be visible.
        expect(find.text('pick up groceries'), findsNothing);
        // Collapsed chevron points down.
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
      },
    );

    testWidgets(
      'tapping the header expands the panel and reveals all rows',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CapturesPanel(date: _date),
            captures: [
              _row(
                id: 'c1',
                transcript: 'pick up groceries',
                at: DateTime(2026, 5, 26, 9, 5),
              ),
              _row(
                id: 'c2',
                transcript: 'call the dentist',
                at: DateTime(2026, 5, 26, 14, 30),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturesPanel)).messages;
        await tester.tap(find.text(messages.dailyOsNextCapturesPanelTitle));
        await tester.pump();

        expect(find.text('pick up groceries'), findsOneWidget);
        expect(find.text('call the dentist'), findsOneWidget);
        // Capture times rendered as HH:mm.
        expect(find.text('09:05'), findsOneWidget);
        expect(find.text('14:30'), findsOneWidget);
        // Chevron rotated to point up.
        expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
        expect(find.text('·  2'), findsOneWidget);
      },
    );

    testWidgets('tapping the header again collapses the panel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CapturesPanel(date: _date),
          captures: [
            _row(
              id: 'c1',
              transcript: 'pick up groceries',
              at: DateTime(2026, 5, 26, 9, 5),
            ),
          ],
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(CapturesPanel)).messages;
      // Expand.
      await tester.tap(find.text(messages.dailyOsNextCapturesPanelTitle));
      await tester.pump();
      expect(find.text('pick up groceries'), findsOneWidget);
      // Collapse.
      await tester.tap(find.text(messages.dailyOsNextCapturesPanelTitle));
      await tester.pump();
      expect(find.text('pick up groceries'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets(
      'capture rows without audio do not render the AudioPlayerWidget',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CapturesPanel(date: _date),
            captures: [
              _row(
                id: 'c1',
                transcript: 'no audio',
                at: DateTime(2026, 5, 26, 9, 5),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturesPanel)).messages;
        await tester.tap(find.text(messages.dailyOsNextCapturesPanelTitle));
        await tester.pump();

        expect(find.text('no audio'), findsOneWidget);
        expect(find.byType(AudioPlayerWidget), findsNothing);
      },
    );

    testWidgets('loading/error states render nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Never resolves → AsyncLoading, hits the maybeWhen orElse branch.
            capturesForDateProvider.overrideWith(
              (ref, _) => Completer<List<CaptureWithAudio>>().future,
            ),
          ],
          child: makeTestableWidget2(
            Material(child: CapturesPanel(date: _date)),
            mediaQueryData: const MediaQueryData(size: Size(800, 1000)),
          ),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(CapturesPanel)).messages;
      expect(find.text(messages.dailyOsNextCapturesPanelTitle), findsNothing);
    });

    testWidgets('keeps previous captures visible during dependency reloads', (
      tester,
    ) async {
      final captures = [
        _row(
          id: 'c1',
          transcript: 'pick up groceries',
          at: DateTime(2026, 5, 26, 9, 5),
        ),
      ];
      final pendingReload = Completer<List<CaptureWithAudio>>();
      final reloadTicks = StreamController<int>.broadcast();
      addTearDown(() {
        if (!pendingReload.isCompleted) pendingReload.complete(captures);
        return reloadTicks.close();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _capturesReloadTickProvider.overrideWith(
              (ref) => reloadTicks.stream,
            ),
            capturesForDateProvider.overrideWith((ref, _) {
              final tick = ref.watch(_capturesReloadTickProvider).value ?? 0;
              if (tick == 0) return captures;
              return pendingReload.future;
            }),
          ],
          child: makeTestableWidget2(
            Material(child: CapturesPanel(date: _date)),
            mediaQueryData: const MediaQueryData(size: Size(800, 1000)),
          ),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(CapturesPanel)).messages;
      expect(find.text(messages.dailyOsNextCapturesPanelTitle), findsOneWidget);
      expect(find.text('·  1'), findsOneWidget);

      reloadTicks.add(1);
      await tester.idle();
      await tester.pump();

      expect(find.text(messages.dailyOsNextCapturesPanelTitle), findsOneWidget);
      expect(find.text('·  1'), findsOneWidget);
    });
  });
}
