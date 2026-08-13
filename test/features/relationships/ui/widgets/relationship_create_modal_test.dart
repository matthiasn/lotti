import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_create_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;

  RelationshipEntry createdEntry(RelationshipData data) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-created',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: data,
  );

  setUp(() {
    mockRepository = MockRelationshipRepository();
  });

  Widget buildForm() => makeTestableWidgetWithScaffold(
    const RelationshipCreateForm(),
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  testWidgets('does not persist when the name is empty', (tester) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        trackingStartedAt: any(named: 'trackingStartedAt'),
      ),
    );
  });

  testWidgets(
    'persists name, nickname, importance, and the picked cadence preset',
    (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (invocation) async => createdEntry(
          invocation.namedArguments[#data] as RelationshipData,
        ),
      );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.enterText(find.byType(TextField).at(1), 'Sis');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every two weeks'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => mockRepository.createRelationship(
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as RelationshipData;
      expect(data.title, 'Anna Example');
      expect(data.nickname, 'Sis');
      expect(data.important, isTrue);
      expect(data.checkInCadenceDays, 14);
      expect(data.status, isA<RelationshipActive>());
    },
  );

  testWidgets('cadence defaults to none when nothing is picked', (
    tester,
  ) async {
    when(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (invocation) async => createdEntry(
        invocation.namedArguments[#data] as RelationshipData,
      ),
    );

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ben');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final data =
        verify(
              () => mockRepository.createRelationship(
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as RelationshipData;
    expect(data.checkInCadenceDays, isNull);
    expect(data.important, isFalse);
    expect(data.nickname, isNull);
  });
}
