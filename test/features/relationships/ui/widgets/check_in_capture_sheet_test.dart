import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;

  CheckInEntry createdEntry(CheckInData data) => CheckInEntry(
    meta: Metadata(
      id: 'check-created',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: data,
  );

  setUp(() {
    mockRepository = MockRelationshipRepository();
    when(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
      ),
    ).thenAnswer(
      (invocation) async => createdEntry(
        invocation.namedArguments[#data] as CheckInData,
      ),
    );
  });

  Widget buildForm() => makeTestableWidgetWithScaffold(
    const CheckInCaptureForm(relationshipId: 'rel-001'),
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  ({CheckInData data, EntryText? entryText}) capturedSave() {
    final captured = verify(
      () => mockRepository.createCheckIn(
        data: captureAny(named: 'data'),
        entryText: captureAny(named: 'entryText'),
      ),
    ).captured;
    return (
      data: captured.first as CheckInData,
      entryText: captured.last as EntryText?,
    );
  }

  testWidgets(
    'saves interaction type, sentiment, parsed topics, and narrative',
    (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();

      // Field order: narrative, topics, pay attention, avoid.
      await tester.enterText(
        find.byType(TextField).at(0),
        'Talked about the interview.',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        ' job search ,vacation , ',
      );
      await tester.enterText(find.byType(TextField).at(2), 'Interview result');
      await tester.enterText(find.byType(TextField).at(3), 'Inheritance');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = capturedSave();
      expect(saved.data.relationshipId, 'rel-001');
      expect(saved.data.interactionType, CheckInInteractionType.call);
      expect(saved.data.sentiment, CheckInSentiment.good);
      expect(saved.data.topics, ['job search', 'vacation']);
      expect(saved.data.payAttentionTo, 'Interview result');
      expect(saved.data.avoid, 'Inheritance');
      expect(saved.entryText?.plainText, 'Talked about the interview.');
    },
  );

  testWidgets('sentiment stays unset unless the user picks one', (
    tester,
  ) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = capturedSave();
    expect(saved.data.sentiment, isNull);
    expect(saved.data.interactionType, CheckInInteractionType.inPerson);
    expect(saved.data.topics, isEmpty);
    expect(saved.entryText, isNull);
  });

  testWidgets('tapping the selected sentiment clears it again', (
    tester,
  ) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedSave().data.sentiment, isNull);
  });
}
