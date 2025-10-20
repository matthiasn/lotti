import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    if (getIt.isRegistered<TimeService>()) {
      getIt.unregister<TimeService>();
    }
    getIt.registerSingleton<TimeService>(_FakeTimeService());
  });

  testWidgets('TimeRecordingIndicator text width is stable', (tester) async {
    final fake = getIt<TimeService>() as _FakeTimeService;

    Future<void> pumpOnce(JournalEntity entity) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: TimeRecordingIndicator()),
          ),
        ),
      );
      fake.emit(entity);
      await tester.pump();
      await tester.pumpAndSettle();
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

class _FakeTimeService extends TimeService {
  final _controller = StreamController<JournalEntity?>.broadcast();

  @override
  Stream<JournalEntity?> getStream() => _controller.stream;

  void emit(JournalEntity? entity) => _controller.add(entity);
}
// ignore_for_file: avoid_redundant_argument_values
