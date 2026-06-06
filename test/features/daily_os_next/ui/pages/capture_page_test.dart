import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat-work',
  name: 'Work',
  colorHex: '5ED4B7',
);

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  MediaQueryData mediaQueryData = const MediaQueryData(size: Size(1280, 900)),
}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: mediaQueryData,
    ),
  );
}

/// Pumps a [CapturePage] (or override) with the harness's controller
/// factory pinned and runs a single frame so the initial state lands.
Future<void> _pumpCapture(
  WidgetTester tester, {
  required _AudioHarness harness,
  Widget page = const CapturePage(),
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    _wrap(
      page,
      overrides: [
        captureControllerProvider.overrideWith(harness.controllerFactory),
        ...extraOverrides,
      ],
    ),
  );
  await tester.pump();
}

void main() {
  group('CapturePage', () {
    testWidgets(
      'idle phase shows talk hint, type action, voice button, no CTA',
      (
        tester,
      ) async {
        final harness = _AudioHarness()..arm();
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(harness.controllerFactory),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(CapturePage));
        final messages = context.messages;

        expect(find.text(messages.dailyOsNextGreetingHi), findsOneWidget);
        expect(find.text(messages.dailyOsNextCaptureIdleTalk), findsOneWidget);
        expect(
          find.text(messages.dailyOsNextCaptureTypeInstead),
          findsOneWidget,
        );
        expect(find.byType(VoiceButton), findsOneWidget);
        expect(find.byType(LiveWaveform), findsNothing);
        expect(
          find.text(messages.dailyOsNextCaptureReconcileCta),
          findsNothing,
        );

        await harness.dispose();
      },
    );

    testWidgets('recorded time preview renders above the idle capture prompt', (
      tester,
    ) async {
      final harness = _AudioHarness()..arm();
      await _pumpCapture(
        tester,
        harness: harness,
        page: CapturePage(
          actualBlocks: [
            TimeBlock(
              id: 'actual:entry-1',
              title: 'Client follow-up',
              start: DateTime(2026, 5, 26, 9),
              end: DateTime(2026, 5, 26, 10),
              type: TimeBlockType.manual,
              state: TimeBlockState.completed,
              category: _category,
              taskId: 'task-1',
            ),
          ],
        ),
      );

      final messages = tester.element(find.byType(CapturePage)).messages;
      expect(find.text(messages.dailyOsNextTimeSpentTitle), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextTimeSpentSummary('1h', 1)),
        findsOneWidget,
      );
      expect(find.text('Client follow-up'), findsOneWidget);
      expect(find.text(messages.dailyOsNextCaptureIdleTalk), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('type instead opens the editable transcript path', (
      tester,
    ) async {
      final harness = _AudioHarness()..arm();
      await _pumpCapture(tester, harness: harness);

      final messages = tester.element(find.byType(CapturePage)).messages;
      await tester.tap(find.text(messages.dailyOsNextCaptureTypeInstead));
      await tester.pump();

      expect(
        find.byKey(const Key('daily_os_capture_transcript_editor')),
        findsOneWidget,
      );
      expect(find.byType(VoiceButton), findsOneWidget);

      await harness.dispose();
    });

    testWidgets('tapping the voice button arms the listening phase', (
      tester,
    ) async {
      final harness = _AudioHarness()..arm();
      await tester.pumpWidget(
        _wrap(
          const CapturePage(),
          overrides: [
            captureControllerProvider.overrideWith(harness.controllerFactory),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(VoiceButton));
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(CapturePage));
      final messages = context.messages;
      expect(find.text(messages.dailyOsNextCaptureListening), findsOneWidget);
      expect(find.byType(LiveWaveform), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
      'after capture, the Reconcile CTA submits edited transcript + audioId',
      (tester) async {
        final agent = RecordingDayAgent();
        // Pre-baked captured state: the idle→listening→captured chain is
        // exercised by the CaptureController unit tests and the
        // 'arms the listening phase' test; this test only verifies the
        // page→agent submission wiring, so no real recording I/O is needed.
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              dayAgentProvider.overrideWithValue(agent),
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.captured,
                    transcript: 'hi there',
                    amplitudes: [],
                    audioId: 'audio_001',
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(CapturePage));
        final messages = context.messages;
        final tokens = context.designTokens;
        expect(find.text(messages.dailyOsNextCaptureCaptured), findsOneWidget);
        final capturedStatus = tester.widget<Text>(
          find.text(messages.dailyOsNextCaptureCaptured),
        );
        expect(
          capturedStatus.style?.letterSpacing,
          tokens.typography.styles.subtitle.subtitle2.letterSpacing,
        );
        expect(
          find.byKey(const Key('daily_os_capture_transcript_editor')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('daily_os_capture_transcript_editor')),
          'complete client animation',
        );
        await tester.pump();

        final ctaFinder = find.text(messages.dailyOsNextCaptureReconcileCta);
        expect(ctaFinder, findsOneWidget);
        await tester.ensureVisible(ctaFinder);
        await tester.pump();
        await tester.tap(ctaFinder, warnIfMissed: false);
        await tester.pump();

        expect(agent.submitCount, 1);
        expect(agent.capturedTranscript, 'complete client animation');
        expect(agent.capturedAudioId, 'audio_001');
      },
    );

    testWidgets('error phase surfaces the localized controller error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CapturePage(),
          overrides: [
            captureControllerProvider.overrideWith(_ErrorController.new),
          ],
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(CapturePage)).messages;
      expect(
        find.text(messages.dailyOsNextCaptureErrorMicrophonePermissionDenied),
        findsOneWidget,
      );
      expect(find.byType(VoiceButton), findsOneWidget);
      expect(find.byType(LiveWaveform), findsNothing);
    });

    // Greeting cases: (label, fixed hour, expected, also-not).
    final greetingCases =
        <
          (
            String,
            int,
            String Function(AppLocalizations),
            String Function(AppLocalizations)?,
          )
        >[
          (
            'morning before noon',
            8,
            (m) => m.dailyOsNextGreetingMorning,
            (m) => m.dailyOsNextGreetingAfternoon,
          ),
          (
            'afternoon between noon and 6pm',
            14,
            (m) => m.dailyOsNextGreetingAfternoon,
            null,
          ),
          (
            'evening after 6pm',
            20,
            (m) => m.dailyOsNextGreetingEvening,
            null,
          ),
        ];
    for (final c in greetingCases) {
      testWidgets('${c.$1} greeting renders', (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 26, c.$2)), () async {
          final harness = _AudioHarness()..arm();
          await _pumpCapture(tester, harness: harness);
          final messages = tester.element(find.byType(CapturePage)).messages;
          expect(find.text(c.$3(messages)), findsOneWidget);
          final notExpected = c.$4;
          if (notExpected != null) {
            expect(find.text(notExpected(messages)), findsNothing);
          }
          await harness.dispose();
        });
      });
    }

    // Headline-tail cases: (label, today's clock, forDate, matcher).
    final tailCases =
        <(String, DateTime, DateTime, String Function(AppLocalizations))>[
          (
            'forDate=tomorrow swaps the headline tail copy',
            DateTime(2026, 5, 26, 9),
            DateTime(2026, 5, 27),
            (m) => m.dailyOsNextCaptureHeadlineTailTomorrow,
          ),
          (
            'forDate=yesterday swaps the headline tail copy',
            DateTime(2026, 5, 26, 9),
            DateTime(2026, 5, 25),
            (m) => m.dailyOsNextCaptureHeadlineTailYesterday,
          ),
          (
            'forDate further out uses the formatted-date headline tail',
            DateTime(2026, 5, 26, 9),
            DateTime(2026, 6, 10),
            // Headline tail rendered as "for Jun 10?" via DateFormat.MMMd.
            (_) => 'Jun 10',
          ),
          (
            'forDate equal to today uses the default "for today?" tail',
            DateTime(2026, 5, 26, 9),
            DateTime(2026, 5, 26),
            (m) => m.dailyOsNextCaptureHeadlineTail,
          ),
        ];
    for (final c in tailCases) {
      testWidgets(c.$1, (tester) async {
        await withClock(Clock.fixed(c.$2), () async {
          final harness = _AudioHarness()..arm();
          await _pumpCapture(
            tester,
            harness: harness,
            page: CapturePage(forDate: c.$3),
          );
          final messages = tester.element(find.byType(CapturePage)).messages;
          final expected = c.$4(messages);
          expect(
            find.byWidgetPredicate(
              (w) => w is RichText && w.text.toPlainText().contains(expected),
            ),
            findsOneWidget,
          );
          await harness.dispose();
        });
      });
    }

    testWidgets('dateStrip widget renders in the AppBar when provided', (
      tester,
    ) async {
      final harness = _AudioHarness()..arm();
      await tester.pumpWidget(
        _wrap(
          const CapturePage(dateStrip: Text('PICKER')),
          overrides: [
            captureControllerProvider.overrideWith(harness.controllerFactory),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('PICKER'), findsOneWidget);
      await harness.dispose();
    });

    testWidgets(
      'transcribing phase renders the spinner instead of the waveform',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.transcribing,
                    transcript: '',
                    amplitudes: [],
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturePage)).messages;
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text(messages.dailyOsNextCaptureListening),
          findsOneWidget,
        );
        expect(find.byType(LiveWaveform), findsNothing);
      },
    );

    testWidgets(
      'error phase surfaces the localized controller error',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.error,
                    transcript: '',
                    amplitudes: [],
                    error: CaptureError.recordingStartFailed,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturePage)).messages;
        expect(
          find.text(messages.dailyOsNextCaptureErrorRecordingStartFailed),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'error phase with null message falls back to the idle hint',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.error,
                    transcript: '',
                    amplitudes: [],
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturePage)).messages;
        expect(
          find.text(messages.dailyOsNextCaptureIdleHint),
          findsOneWidget,
        );
      },
    );

    // The microphone-permission and recording-start arms are exercised
    // individually above; cover the remaining error arms in one pass so every
    // CaptureError maps to its localized copy.
    final remainingErrorCases =
        <(CaptureError, String Function(AppLocalizations))>[
          (
            CaptureError.realtimeTranscriptionStartFailed,
            (m) => m.dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed,
          ),
          (
            CaptureError.noActiveRealtimeSession,
            (m) => m.dailyOsNextCaptureErrorNoActiveRealtimeSession,
          ),
          (
            CaptureError.realtimeTranscriptionFailed,
            (m) => m.dailyOsNextCaptureErrorRealtimeTranscriptionFailed,
          ),
          (
            CaptureError.noAudioRecorded,
            (m) => m.dailyOsNextCaptureErrorNoAudioRecorded,
          ),
          (
            CaptureError.transcriptionFailed,
            (m) => m.dailyOsNextCaptureErrorTranscriptionFailed,
          ),
        ];
    for (final c in remainingErrorCases) {
      testWidgets('error phase surfaces localized copy for ${c.$1.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  CaptureState(
                    phase: CapturePhase.error,
                    transcript: '',
                    amplitudes: const [],
                    error: c.$1,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturePage)).messages;
        expect(find.text(c.$2(messages)), findsOneWidget);
      });
    }

    testWidgets(
      'listening phase with a partial transcript shows the live preview text',
      (tester) async {
        const liveTranscript =
            'streaming words keep coming\n'
            'then another sentence lands\n'
            'and the viewport should stay on the tail';

        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.listening,
                    transcript: '',
                    amplitudes: [0.2, 0.4, 0.6],
                    partialTranscript: liveTranscript,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(CapturePage));
        final tokens = context.designTokens;
        expect(find.byType(LiveWaveform), findsOneWidget);
        expect(find.text(liveTranscript), findsOneWidget);
        expect(
          tester
              .getSize(
                find.byKey(
                  const Key('daily_os_capture_live_transcript_viewport'),
                ),
              )
              .height,
          greaterThan(tokens.typography.lineHeight.bodyMedium * 3),
        );
        final scrollView = tester.widget<SingleChildScrollView>(
          find.descendant(
            of: find.byKey(
              const Key('daily_os_capture_live_transcript_viewport'),
            ),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        expect(scrollView.reverse, isTrue);
        final transcriptText = tester.widget<Text>(find.text(liveTranscript));
        expect(transcriptText.strutStyle?.forceStrutHeight, isTrue);
        expect(transcriptText.maxLines, isNull);
        expect(transcriptText.overflow, isNull);
      },
    );

    testWidgets(
      'listening preview keeps a readable viewport on very small phone layouts',
      (tester) async {
        const liveTranscript = 'live words appear while speaking';
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            mediaQueryData: const MediaQueryData(size: Size(320, 568)),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.listening,
                    transcript: '',
                    amplitudes: [0.2, 0.4, 0.6],
                    partialTranscript: liveTranscript,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final tokens = tester.element(find.byType(CapturePage)).designTokens;
        expect(find.text(liveTranscript), findsOneWidget);
        expect(
          tester
              .getSize(
                find.byKey(
                  const Key('daily_os_capture_live_transcript_viewport'),
                ),
              )
              .height,
          greaterThanOrEqualTo(tokens.typography.lineHeight.bodyMedium * 3),
        );
        expect(tester.getTopLeft(find.text(liveTranscript)).dy, greaterThan(0));
      },
    );

    testWidgets(
      'capture state slot keeps the voice button stable while listening starts',
      (tester) async {
        const stateSlotKey = Key('daily_os_capture_state_slot');

        Future<({Size slotSize, Offset voiceOffset})> pumpWithState(
          CaptureState state,
        ) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pumpWidget(
            _wrap(
              const CapturePage(),
              overrides: [
                captureControllerProvider.overrideWith(
                  _StubCaptureController.factory(state),
                ),
              ],
            ),
          );
          await tester.pump();

          return (
            slotSize: tester.getSize(find.byKey(stateSlotKey)),
            voiceOffset: tester.getTopLeft(find.byType(VoiceButton)),
          );
        }

        final idle = await pumpWithState(const CaptureState.idle());
        final listening = await pumpWithState(
          const CaptureState(
            phase: CapturePhase.listening,
            transcript: '',
            amplitudes: [0.2, 0.4, 0.6],
          ),
        );
        final longTranscript = await pumpWithState(
          const CaptureState(
            phase: CapturePhase.listening,
            transcript: '',
            amplitudes: [0.2, 0.4, 0.6],
            partialTranscript:
                'First recognised line\n'
                'then a second recognised line\n'
                'then a third recognised line\n'
                'then a fourth recognised line',
          ),
        );

        expect(listening.slotSize, idle.slotSize);
        expect(longTranscript.slotSize, idle.slotSize);
        expect(listening.voiceOffset, idle.voiceOffset);
        expect(longTranscript.voiceOffset, idle.voiceOffset);
      },
    );

    testWidgets(
      'capture body reserves the mobile bottom navigation area',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.captured,
                    transcript:
                        'Reviewable transcript line one. '
                        'Reviewable transcript line two. '
                        'Reviewable transcript line three. '
                        'Reviewable transcript line four.',
                    amplitudes: [],
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(CapturePage));
        final bottomPadding = tester.widget<Padding>(
          find.byKey(const Key('daily_os_capture_bottom_nav_padding')),
        );

        expect(
          bottomPadding.padding.resolve(Directionality.of(context)).bottom,
          DesignSystemBottomNavigationBar.occupiedHeight(context),
        );
        expect(
          tester
              .getBottomLeft(
                find.text(context.messages.dailyOsNextCaptureReconcileCta),
              )
              .dy,
          lessThan(844),
        );
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('daily_os_capture_transcript_editor')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.minLines, greaterThanOrEqualTo(4));
        expect(field.maxLines, isNull);
      },
    );

    testWidgets(
      'captured transcript editor compacts on very small phone viewports',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            mediaQueryData: const MediaQueryData(size: Size(320, 568)),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.captured,
                    transcript: 'Reviewable transcript',
                    amplitudes: [],
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('daily_os_capture_transcript_editor')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.minLines, 2);
        expect(field.maxLines, isNull);
        expect(field.scrollPhysics, isA<NeverScrollableScrollPhysics>());

        final context = tester.element(find.byType(CapturePage));
        final ctaFinder = find.text(
          context.messages.dailyOsNextCaptureReconcileCta,
        );
        await tester.ensureVisible(ctaFinder);
        await tester.pump();

        expect(tester.getBottomLeft(ctaFinder).dy, lessThan(568));
      },
    );

    testWidgets(
      'captured phase with whitespace-only transcript disables the Reconcile CTA',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.captured,
                    transcript: '   ',
                    amplitudes: [],
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturePage)).messages;
        final button = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text(messages.dailyOsNextCaptureReconcileCta),
            matching: find.byType(FilledButton),
          ),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('submits captures against the selected planning date', (
      tester,
    ) async {
      final agent = RecordingDayAgent();
      await tester.pumpWidget(
        _wrap(
          CapturePage(forDate: DateTime(2026, 5, 27)),
          overrides: [
            dayAgentProvider.overrideWithValue(agent),
            captureControllerProvider.overrideWith(
              _StubCaptureController.factory(
                const CaptureState(
                  phase: CapturePhase.captured,
                  transcript: 'plan tomorrow',
                  amplitudes: [],
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final ctaFinder = find.text(
        tester
            .element(find.byType(CapturePage))
            .messages
            .dailyOsNextCaptureReconcileCta,
      );
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder, warnIfMissed: false);
      await tester.pump();

      expect(agent.submitCount, 1);
      expect(agent.capturedAt?.year, 2026);
      expect(agent.capturedAt?.month, 5);
      expect(agent.capturedAt?.day, 27);
    });

    testWidgets(
      'recorded time summary formats hours and minutes together',
      (tester) async {
        final harness = _AudioHarness()..arm();
        await _pumpCapture(
          tester,
          harness: harness,
          // 90 minutes total exercises the "Xh Ym" branch of
          // _formatMinutes (both hours and remaining minutes non-zero).
          page: CapturePage(
            actualBlocks: [
              TimeBlock(
                id: 'actual:entry-90',
                title: 'Deep work',
                start: DateTime(2026, 5, 26, 9),
                end: DateTime(2026, 5, 26, 10, 30),
                type: TimeBlockType.manual,
                state: TimeBlockState.completed,
                category: _category,
                taskId: 'task-90',
              ),
            ],
          ),
        );

        final messages = tester.element(find.byType(CapturePage)).messages;
        expect(
          find.text(messages.dailyOsNextTimeSpentSummary('1h 30m', 1)),
          findsOneWidget,
        );

        await harness.dispose();
      },
    );

    testWidgets(
      'greeting addresses the user by name when a userName is set',
      (tester) async {
        final harness = _AudioHarness()..arm();
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              captureControllerProvider.overrideWith(
                harness.controllerFactory,
              ),
              dailyOsPreferencesControllerProvider.overrideWith(
                () => _StubPreferencesController(
                  DailyOsPreferences(userName: 'Alex'),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturePage)).messages;
        expect(
          find.text(messages.dailyOsNextGreetingHiName('Alex')),
          findsOneWidget,
        );
        // The anonymous greeting is replaced by the personalised one.
        expect(find.text(messages.dailyOsNextGreetingHi), findsNothing);

        await harness.dispose();
      },
    );

    testWidgets(
      'submitting resets capture and dismisses spinner after Reconcile returns',
      (tester) async {
        final agent = RecordingDayAgent();
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              dayAgentProvider.overrideWithValue(agent),
              // Pre-baked captured state — reset() and _submitting are
              // page-level concerns; the recording chain itself is covered
              // by the CaptureController unit tests.
              captureControllerProvider.overrideWith(
                _StubCaptureController.factory(
                  const CaptureState(
                    phase: CapturePhase.captured,
                    transcript: 'hello world',
                    amplitudes: [],
                  ),
                ),
              ),
              // Keep the pushed ReconcilePage on its loading shell so it
              // does not reach into GetIt-backed services.
              reconcileControllerProvider.overrideWith(
                _PendingReconcileController.new,
              ),
            ],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(CapturePage)).messages;
        final ctaFinder = find.text(messages.dailyOsNextCaptureReconcileCta);
        await tester.ensureVisible(ctaFinder);
        await tester.pump();

        // Pre-condition: captured surface shows the editable transcript
        // and the Reconcile CTA, and the idle hint is absent.
        expect(
          find.byKey(const Key('daily_os_capture_transcript_editor')),
          findsOneWidget,
        );
        expect(find.text(messages.dailyOsNextCaptureIdleTalk), findsNothing);

        // Tapping enters _onSubmit: submitCapture runs, then
        // Navigator.push lands us on the ReconcilePage. The pushed page
        // keeps an infinite spinner, so we drive the route transition
        // with explicit frames instead of pumpAndSettle.
        await tester.tap(ctaFinder, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // We navigated onto ReconcilePage (its loading spinner is on top).
        expect(agent.submitCount, 1);
        expect(find.byType(ReconcilePage), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Popping ReconcilePage completes the awaited push, so _onSubmit
        // resumes: reset() returns capture to idle (lines 938-939) and the
        // finally block clears _submitting (line 942).
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        // Drive the reverse route transition to completion (its duration
        // plus a margin) so ReconcilePage fully leaves the tree.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // ReconcilePage is gone and reset() returned the capture surface to
        // idle: the transcript editor + CTA are replaced by the talk hint.
        expect(find.byType(ReconcilePage), findsNothing);
        final idleMessages = tester.element(find.byType(CapturePage)).messages;
        expect(
          find.text(idleMessages.dailyOsNextCaptureIdleTalk),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('daily_os_capture_transcript_editor')),
          findsNothing,
        );
        expect(
          find.text(idleMessages.dailyOsNextCaptureReconcileCta),
          findsNothing,
        );
      },
    );
  });

  group('CaptureLayoutMetrics', () {
    final tokens = resolveTestTheme().extension<DsTokens>()!;

    test('minimum review transcript line count per viewport band', () {
      expect(CaptureLayoutMetrics.minimumReviewTranscriptLineCountFor(559), 2);
      expect(CaptureLayoutMetrics.minimumReviewTranscriptLineCountFor(560), 3);
      expect(CaptureLayoutMetrics.minimumReviewTranscriptLineCountFor(699), 3);
      expect(CaptureLayoutMetrics.minimumReviewTranscriptLineCountFor(700), 4);
      expect(CaptureLayoutMetrics.minimumReviewTranscriptLineCountFor(1200), 4);
    });

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(280, 1600),
      glados.IntAnys(glados.any).intInRange(0, CapturePhase.values.length),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'resolve keeps slot height clamped and line counts in range',
      (viewportSeed, phaseSeed) {
        final viewportHeight = viewportSeed.toDouble();
        final phase =
            CapturePhase.values[phaseSeed % CapturePhase.values.length];

        final layout = CaptureLayoutMetrics.resolve(
          tokens,
          phase: phase,
          viewportHeight: viewportHeight,
        );

        final minLines =
            CaptureLayoutMetrics.minimumReviewTranscriptLineCountFor(
              viewportHeight,
            );
        final minSlot = CaptureLayoutMetrics.minimumSlotHeightFor(
          tokens,
          phase,
          minimumReviewTranscriptLineCount: minLines,
        );
        final maxSlot = CaptureLayoutMetrics.maximumSlotHeightFor(tokens);
        final reason = 'viewport=$viewportHeight phase=$phase';

        // (1) slot height stays within the clamp bounds.
        expect(
          layout.stateSlotHeight,
          greaterThanOrEqualTo(minSlot),
          reason: reason,
        );
        expect(
          layout.stateSlotHeight,
          lessThanOrEqualTo(math.max(minSlot, maxSlot)),
          reason: reason,
        );
        // (2) live transcript line count is always within [3, 7].
        expect(
          layout.liveTranscriptLineCount,
          inInclusiveRange(3, 7),
          reason: reason,
        );
        // (3) review transcript line count honors the viewport-band minimum.
        expect(
          layout.reviewTranscriptLineCount,
          greaterThanOrEqualTo(minLines),
          reason: reason,
        );
        expect(
          layout.reviewTranscriptLineCount,
          lessThanOrEqualTo(math.max(6, minLines)),
          reason: reason,
        );
      },
      tags: 'glados',
    );
  });
}

/// Pins a fixed [DailyOsPreferences] so the greeting can be tested with
/// a known userName without touching the SettingsDb-backed loader.
class _StubPreferencesController extends DailyOsPreferencesController {
  _StubPreferencesController(this._initial);

  final DailyOsPreferences _initial;

  @override
  DailyOsPreferences build() => _initial;
}

/// Holds the Reconcile screen on its loading shell so the pushed page in
/// the submit flow renders a spinner instead of reaching GetIt services.
class _PendingReconcileController extends ReconcileController {
  _PendingReconcileController() : super(_unusedParams);

  static final ReconcileParams _unusedParams = ReconcileParams(
    captureId: const CaptureId('cap_recorded'),
    dayDate: DateTime(2026, 5, 26),
  );

  @override
  Future<ReconcileData> build() => Completer<ReconcileData>().future;
}

/// Surfaces a fixed error state so the page can be tested independently
/// of the recording lifecycle.
class _ErrorController extends CaptureController {
  @override
  CaptureState build() => const CaptureState(
    phase: CapturePhase.error,
    transcript: '',
    amplitudes: <double>[],
    error: CaptureError.microphonePermissionDenied,
  );
}

/// Wraps a fake recorder + transcription service so widget tests can
/// drive the [CaptureController] without touching the mic or cloud.
class _AudioHarness {
  _AudioHarness();

  static const transcript = 'transcript';
  final MockAudioRecorderRepository recorder = MockAudioRecorderRepository();
  final MockAudioTranscriptionService transcriber =
      MockAudioTranscriptionService();
  final MockRealtimeTranscriptionService realtimeService =
      MockRealtimeTranscriptionService();
  final StreamController<Amplitude> ampController =
      StreamController<Amplitude>.broadcast();

  void arm() {
    // Page tests pin the batch path; realtime coverage lives in the
    // controller test.
    when(
      realtimeService.resolveRealtimeConfig,
    ).thenAnswer((_) async => null);
    when(realtimeService.dispose).thenAnswer((_) async {});
    when(recorder.hasPermission).thenAnswer((_) async => true);
    when(
      () => recorder.amplitudeStream,
    ).thenAnswer((_) => ampController.stream);
    when(recorder.startRecording).thenAnswer(
      (_) async => AudioNote(
        createdAt: DateTime(2026, 5, 26, 9),
        audioFile: 'capture.m4a',
        audioDirectory: '/audio/2026-05-26/',
        duration: Duration.zero,
      ),
    );
    when(recorder.stopRecording).thenAnswer((_) async {});
    when(
      () => transcriber.transcribe(
        any(),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer((_) async => transcript);
  }

  CaptureController controllerFactory() => CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    realtimeService: realtimeService,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => JournalAudio(
      meta: Metadata(
        id: 'audio_001',
        createdAt: DateTime(2026, 5, 26, 9),
        updatedAt: DateTime(2026, 5, 26, 9),
        dateFrom: DateTime(2026, 5, 26, 9),
        dateTo: DateTime(2026, 5, 26, 9, 0, 1),
        vectorClock: const VectorClock(<String, int>{}),
      ),
      data: AudioData(
        dateFrom: DateTime(2026, 5, 26, 9),
        dateTo: DateTime(2026, 5, 26, 9, 0, 1),
        audioFile: 'capture.m4a',
        audioDirectory: '/audio/2026-05-26/',
        duration: const Duration(seconds: 1),
      ),
    ),
    now: () => DateTime(2026, 5, 26, 9),
  );

  Future<void> dispose() async {
    await ampController.close();
  }
}

/// CaptureController override that emits a pre-baked [CaptureState] so
/// page tests can render phase-specific UI without driving the recorder.
class _StubCaptureController extends CaptureController {
  _StubCaptureController(this._initial);

  final CaptureState _initial;

  static CaptureController Function() factory(CaptureState state) =>
      () => _StubCaptureController(state);

  @override
  CaptureState build() => _initial;
}
