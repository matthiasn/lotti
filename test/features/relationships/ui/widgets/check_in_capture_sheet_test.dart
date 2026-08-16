import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
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

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepository = MockRelationshipRepository();
    when(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
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

  final interactionTime = DateTime(2026, 8, 10, 19, 45);

  CheckInEntry existing() => CheckInEntry(
    meta: Metadata(
      id: 'check-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: interactionTime,
      dateTo: interactionTime,
    ),
    data: const CheckInData(
      relationshipId: 'rel-001',
      interactionType: CheckInInteractionType.call,
      sentiment: CheckInSentiment.good,
      topics: ['travel', 'work'],
      payAttentionTo: 'Job interview',
    ),
    entryText: const EntryText(plainText: 'Planned the trip.'),
  );

  Widget buildEditForm() => makeTestableWidgetWithScaffold(
    CheckInCaptureForm(
      relationshipId: 'rel-001',
      initial: existing(),
    ),
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  ({CheckInData data, EntryText? entryText, DateTime? dateFrom})
  capturedSave() {
    final captured = verify(
      () => mockRepository.createCheckIn(
        data: captureAny(named: 'data'),
        entryText: captureAny(named: 'entryText'),
        dateFrom: captureAny(named: 'dateFrom'),
      ),
    ).captured;
    return (
      data: captured[0] as CheckInData,
      entryText: captured[1] as EntryText?,
      dateFrom: captured[2] as DateTime?,
    );
  }

  testWidgets(
    'saves interaction type, sentiment, parsed topics, and narrative',
    (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Call'));
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Good'));
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

      await tester.ensureVisible(find.text('Save'));
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

    await tester.ensureVisible(find.text('Save'));
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

    await tester.ensureVisible(find.text('Good'));
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Good'));
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedSave().data.sentiment, isNull);
  });

  testWidgets('create mode passes an interaction time to the repository', (
    tester,
  ) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedSave().dateFrom, isNotNull);
  });

  testWidgets('a refused save keeps the sheet open and reports it', (
    tester,
  ) async {
    when(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the check-in. Please try again.'),
      findsOneWidget,
    );
    // Still editable, and Save is armed again — a retry does not need the
    // sheet reopened.
    expect(find.text('How did you connect?'), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Save'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a save that throws reports the failure too', (tester) async {
    when(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
      ),
    ).thenThrow(Exception('db gone'));

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the check-in. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('How did you connect?'), findsOneWidget);
  });

  testWidgets('Cancel closes without saving anything', (tester) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Typed but discarded');
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
      ),
    );
  });

  group('edit mode', () {
    setUp(() {
      when(
        () => mockRepository.updateCheckIn(any()),
      ).thenAnswer((_) async => true);
    });

    testWidgets(
      'prefills every field and preserves the interaction time on save',
      (tester) async {
        await tester.pumpWidget(buildEditForm());
        await tester.pumpAndSettle();

        // Prefilled: narrative, joined topics, guidance, and the date field.
        expect(
          find.widgetWithText(TextField, 'Planned the trip.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, 'travel, work'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Job interview'),
          findsOneWidget,
        );
        expect(find.text('2026-08-10'), findsOneWidget);

        await tester.ensureVisible(find.text('Neutral'));
        await tester.tap(find.text('Neutral'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final updated =
            verify(
                  () => mockRepository.updateCheckIn(captureAny()),
                ).captured.single
                as CheckInEntry;
        expect(updated.id, 'check-1');
        expect(updated.data.sentiment, CheckInSentiment.neutral);
        expect(updated.data.topics, ['travel', 'work']);
        // Untouched date: the original interaction time survives, to the
        // minute.
        expect(updated.meta.dateFrom, interactionTime);
        expect(updated.meta.dateTo, interactionTime);
        expect(updated.entryText?.plainText, 'Planned the trip.');
      },
    );

    testWidgets('tapping the date field opens the date picker', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      // One 'When?' before (the field label)…
      expect(find.text('When?'), findsOneWidget);
      await tester.ensureVisible(find.text('2026-08-10'));
      await tester.tap(find.text('2026-08-10'));
      await tester.pumpAndSettle();

      // …and a second one as the picker modal's title once it is open.
      expect(find.text('When?'), findsNWidgets(2));
    });

    testWidgets('delete asks for confirmation, then deletes and closes', (
      tester,
    ) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text('Delete this check-in? This cannot be undone.'),
        findsOneWidget,
      );
      verifyNever(() => mockRepository.deleteCheckIn(any()));

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.deleteCheckIn('check-1')).called(1);
    });

    testWidgets('create mode carries no delete affordance', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('a refused delete keeps the check-in and reports it', (
      tester,
    ) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOneWidget,
      );
      // The sheet stays up on its still-live check-in.
      expect(
        find.widgetWithText(TextField, 'Planned the trip.'),
        findsOneWidget,
      );
    });

    testWidgets('a delete that throws reports the failure too', (tester) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenThrow(Exception('db gone'));

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Planned the trip.'),
        findsOneWidget,
      );
    });

    testWidgets('a refused update reports it and keeps the edits', (
      tester,
    ) async {
      when(
        () => mockRepository.updateCheckIn(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Edited narrative');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Edited narrative'),
        findsOneWidget,
      );
    });

    testWidgets('the date picker moves the day and keeps the time of day', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('2026-08-10'));
      await tester.tap(find.text('2026-08-10'));
      await tester.pumpAndSettle();

      // Pick the 6th in the open month grid, then confirm.
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('2026-08-06'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          verify(
                () => mockRepository.updateCheckIn(captureAny()),
              ).captured.single
              as CheckInEntry;
      // The day moved; 19:45 survived, because the picker is date-only.
      expect(updated.meta.dateFrom, DateTime(2026, 8, 6, 19, 45));
      expect(updated.meta.dateTo, DateTime(2026, 8, 6, 19, 45));
    });
  });

  group('error toasts', () {
    testWidgets('shows a toast when create returns null', (tester) async {
      when(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when create throws', (tester) async {
      when(
        () => mockRepository.createCheckIn(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          dateFrom: any(named: 'dateFrom'),
        ),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update returns false', (tester) async {
      when(() => mockRepository.updateCheckIn(any())).thenAnswer(
        (_) async => false,
      );

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when delete returns false', (tester) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when delete throws', (tester) async {
      when(
        () => mockRepository.deleteCheckIn('check-1'),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildEditForm());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the check-in. Please try again.'),
        findsOne,
      );
    });
  });
}
