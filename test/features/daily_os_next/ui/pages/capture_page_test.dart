import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
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

const _category = DayAgentCategory(
  id: 'cat-work',
  name: 'Work',
  colorHex: '5ED4B7',
);

class _RecordingAgent implements DayAgentInterface {
  String? capturedTranscript;
  String? capturedAudioId;
  DateTime? capturedAt;
  int submitCount = 0;

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async {
    capturedTranscript = transcript;
    capturedAudioId = audioId;
    this.capturedAt = capturedAt;
    submitCount++;
    return const CaptureId('cap_recorded');
  }

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async => null;

  @override
  Future<bool> deletePlanForDate(DateTime date) async => true;

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => const [];

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async =>
      throw UnimplementedError();

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async => TriageResult(taskId: taskId, action: action);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async => DraftPlan(
    dayDate: dayDate,
    blocks: const [],
    bands: const [],
    capacityMinutes: 0,
    scheduledMinutes: 0,
  );

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async => const [];

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async => PlanDiff(
    id: 'rec',
    transcript: voiceTranscript,
    changes: const [],
    updatedPlan: currentPlan,
  );

  @override
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) async => diff.updatedPlan;

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async => originalPlan;

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) async =>
      plan.copyWith(state: DayState.committed);

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: const <CompletedItem>[],
    carryover: const <CarryoverItem>[],
    metrics: const ShutdownMetrics(
      focusMinutes: 0,
      flowSessions: 0,
      contextSwitches: 0,
      contextSwitchesWeekAvg: 0,
      energyScore: 0,
      energyDeltaVsWeek: 0,
    ),
  );

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {}

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {}

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => const TomorrowNote(body: '', maturity: 1);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) async => const [];
}

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
        find.text(messages.dailyOsNextCaptureTranscriptLabel),
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
        final agent = _RecordingAgent();
        final harness = _AudioHarness(transcript: 'hi there')..arm();
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              dayAgentProvider.overrideWithValue(agent),
              captureControllerProvider.overrideWith(harness.controllerFactory),
            ],
          ),
        );
        await tester.pump();

        // Start listening: drive the controller's async chain (mock
        // permission + startRecording + real Directory.create) to
        // completion via a zero-delay `runAsync` — no fake `pump`
        // frames can resolve the real filesystem call.
        await tester.tap(find.byType(VoiceButton));
        await tester.runAsync(() async {});
        await tester.pump();
        // Stop listening — triggers transcribe + persist.
        await tester.tap(find.byType(VoiceButton));
        await tester.runAsync(() async {});
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
          find.text(messages.dailyOsNextCaptureTranscriptLabel),
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

        await harness.dispose();
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
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
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
      final agent = _RecordingAgent();
      final harness = _AudioHarness(transcript: 'plan tomorrow')..arm();
      await tester.pumpWidget(
        _wrap(
          CapturePage(forDate: DateTime(2026, 5, 27)),
          overrides: [
            dayAgentProvider.overrideWithValue(agent),
            captureControllerProvider.overrideWith(harness.controllerFactory),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(VoiceButton));
      await tester.runAsync(() async {});
      await tester.pump();
      await tester.tap(find.byType(VoiceButton));
      await tester.runAsync(() async {});
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

      await harness.dispose();
    });
  });
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
  _AudioHarness({this.transcript = 'transcript'});

  final String transcript;
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
