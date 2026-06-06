import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<JournalEntity?> timeStreamController;

  setUp(() async {
    timeStreamController = StreamController<JournalEntity?>.broadcast();
    final mockTimeService = MockTimeService();
    when(mockTimeService.getStream).thenAnswer(
      (_) => timeStreamController.stream,
    );
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<TimeService>(mockTimeService);
      },
    );
  });

  tearDown(() async {
    await timeStreamController.close();
    await tearDownTestGetIt();
  });

  testWidgets('TimeRecordingIndicator text width is stable', (tester) async {
    Future<void> pumpOnce(JournalEntity entity) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: TimeRecordingIndicator()),
          ),
        ),
      );
      timeStreamController.add(entity);
      // Two pumps: one to deliver the stream event, one to lay out the
      // updated text. No animations are involved.
      await tester.pump();
      await tester.pump();
    }

    JournalEntity makeEntry(Duration duration) {
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      final from = now.subtract(duration);
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: 'e1',
          createdAt: from,
          updatedAt: now,
          dateFrom: from,
          dateTo: now,
        ),
      );
    }

    await pumpOnce(makeEntry(const Duration(minutes: 41)));
    final textFinder = find.descendant(
      of: find.byType(TimeRecordingIndicator),
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget);
    final w1 = tester.getSize(textFinder).width;

    await pumpOnce(makeEntry(const Duration(minutes: 48)));
    final w2 = tester.getSize(textFinder).width;

    expect(w1, equals(w2));
  });
}

// ignore_for_file: avoid_redundant_argument_values
