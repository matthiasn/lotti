import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

class _MockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTimeService mockTimeService;
  late _MockNavService mockNavService;
  late StreamController<JournalEntity?> controller;

  setUp(() {
    mockTimeService = MockTimeService();
    mockNavService = _MockNavService();
    controller = StreamController<JournalEntity?>.broadcast();

    getIt
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService);

    when(() => mockTimeService.getStream())
        .thenAnswer((_) => controller.stream);
  });

  tearDown(() async {
    await controller.close();
    await getIt.reset();
  });

  testWidgets('indicator shows with stable width across durations',
      (tester) async {
    final now = DateTime.now();
    const entryId = 'rec-1';

    final first = JournalEntry(
      meta: Metadata(
        id: entryId,
        createdAt: now,
        updatedAt: now,
        dateFrom: now.subtract(const Duration(seconds: 10)),
        dateTo: now,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const TimeRecordingIndicator()),
    );

    controller.add(first);
    await tester.pumpAndSettle();

    final materialFinder = find.descendant(
      of: find.byType(TimeRecordingIndicator),
      matching: find.byType(Material),
    );
    expect(materialFinder, findsOneWidget);

    final size1 = tester.getSize(materialFinder);
    expect(size1.width, AudioRecordingIndicatorConstants.indicatorWidth);

    // Push a new update with a different duration -> width should remain constant
    final second = first.copyWith(
      meta: first.meta.copyWith(dateTo: now.add(const Duration(seconds: 8))),
    );
    controller.add(second);
    await tester.pumpAndSettle();

    final size2 = tester.getSize(materialFinder);
    expect(size2.width, AudioRecordingIndicatorConstants.indicatorWidth);
    expect(size2, equals(size1));
  });

  testWidgets('tap navigates to linked entry if present, else to current',
      (tester) async {
    final now = DateTime.now();
    final current = JournalEntry(
      meta: Metadata(
        id: 'current-id',
        createdAt: now,
        updatedAt: now,
        dateFrom: now.subtract(const Duration(seconds: 5)),
        dateTo: now,
      ),
    );

    // First case: no linkedFrom -> navigates to journal/current-id
    when(() => mockTimeService.linkedFrom).thenReturn(null);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const TimeRecordingIndicator()),
    );

    controller.add(current);
    await tester.pumpAndSettle();

    final materialFinder = find.descendant(
      of: find.byType(TimeRecordingIndicator),
      matching: find.byType(Material),
    );
    await tester.tap(materialFinder);
    await tester.pumpAndSettle();

    expect(
        mockNavService.navigationHistory.last, '/journal/${current.meta.id}');

    // Second case: linkedFrom is a task -> navigates to tasks/<id>
    final taskFrom = Task(
      data: TaskData(
        title: 'T',
        status: TaskStatus.open(
          id: 'st',
          createdAt: now,
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: now,
        dateTo: now,
        estimate: const Duration(minutes: 1),
      ),
      meta: Metadata(
        id: 'task-42',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
    );

    when(() => mockTimeService.linkedFrom).thenReturn(taskFrom);

    await tester.tap(materialFinder);
    await tester.pumpAndSettle();

    expect(mockNavService.navigationHistory.last, '/tasks/${taskFrom.meta.id}');
  });
}
