import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Fixtures shared by the day-page suites: `day_page_test.dart` and the
/// header-layout suite in `day_page_header_test.dart`. Kept here rather than
/// copied so the two files cannot drift apart.

const dayPageCategory = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan draftedPlan({
  DayState state = DayState.drafted,
  String title = 'Deep work',
}) => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 120,
  state: state,
  agendaItems: [
    AgendaItem(
      id: 'item_1',
      title: title,
      category: dayPageCategory,
      linkedBlockIds: const ['blk_1'],
    ),
  ],
);

/// Stub the realtime service so CaptureController (built by RefinePage
/// when DayPage pushes it) can dispose cleanly without touching the AI
/// providers during teardown.
CaptureController stubCaptureController() {
  final recorder = MockAudioRecorderRepository();
  final transcriber = MockAudioTranscriptionService();
  when(recorder.stopRecording).thenAnswer((_) async {});
  return CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => null,
    now: () => DateTime(2026, 5, 26, 9),
  );
}

Widget wrapDayPage(
  Widget child, {
  List<Override> overrides = const [],
  List<TimeBlock> actualBlocks = const [],
  List<DayActivityEntry> activityEntries = const [],
  Size size = const Size(1400, 1200),
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
  DailyOsSetupStatus setupStatus = const DailyOsSetupStatus(
    hasInferenceRoute: true,
    hasPreferredName: true,
  ),
}) {
  return makeTestableWidgetNoScroll(
    child,
    overrides: [
      capturesForDateProvider.overrideWith((ref, date) async => const []),
      dayActivityProvider.overrideWith((ref, date) async => activityEntries),
      dailyOsActualTimeBlocksProvider.overrideWith(
        (ref, date) async => actualBlocks,
      ),
      // RefinePage builds a CaptureController; stub so it doesn't read
      // the realtime service providers during dispose.
      captureControllerProvider.overrideWith(stubCaptureController),
      dailyOsSetupStatusProvider.overrideWith(
        (ref) async => setupStatus,
      ),
      ...overrides,
    ],
    mediaQueryData: mediaQueryData ?? MediaQueryData(size: size),
    theme: theme,
  );
}

ThemeData themeWithHeaderSpacing(double step2) {
  final theme = resolveTestTheme();
  final tokens = theme.extension<DsTokens>()!;
  return theme.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      tokens.copyWith(
        spacing: tokens.spacing.copyWith(step2: step2),
      ),
    ],
  );
}

Widget dateStripLike(String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(LottiIcons.chevronLeft),
        onPressed: () {},
      ),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      IconButton(
        icon: const Icon(LottiIcons.chevronRight),
        onPressed: () {},
      ),
    ],
  );
}
