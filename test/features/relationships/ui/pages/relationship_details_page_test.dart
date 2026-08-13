import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockUpdateNotifications mockNotifications;

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
  );

  RelationshipEntry relationship({
    bool important = false,
    int? cadenceDays,
  }) => RelationshipEntry(
    meta: meta('rel-1'),
    data: RelationshipData(
      title: 'Anna',
      nickname: 'Sis',
      important: important,
      checkInCadenceDays: cadenceDays,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  CheckInEntry checkIn(
    String id, {
    CheckInSentiment? sentiment,
    List<String> topics = const [],
    String? narrative,
  }) => CheckInEntry(
    meta: meta(id),
    data: CheckInData(
      relationshipId: 'rel-1',
      interactionType: CheckInInteractionType.call,
      sentiment: sentiment,
      topics: topics,
    ),
    entryText: narrative == null ? null : EntryText(plainText: narrative),
  );

  setUp(() {
    mockRepository = MockRelationshipRepository();
    mockNotifications = MockUpdateNotifications();
    getIt.registerSingleton<UpdateNotifications>(mockNotifications);
  });

  tearDown(() async {
    await getIt.unregister<UpdateNotifications>();
  });

  Widget buildPage() => ProviderScope(
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
    child: MaterialApp(
      theme: resolveTestTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RelationshipDetailsPage(relationshipId: 'rel-1'),
    ),
  );

  testWidgets(
    'renders header chips (status, cadence, nickname) and check-in rows',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(important: true, cadenceDays: 14),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer(
        (_) async => [
          checkIn(
            'check-1',
            sentiment: CheckInSentiment.good,
            topics: ['travel'],
            narrative: 'Planned the summer trip.',
          ),
        ],
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Every two weeks'), findsOneWidget);
      expect(find.text('Sis'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('travel'), findsOneWidget);
      expect(find.text('Planned the summer trip.'), findsOneWidget);
    },
  );

  testWidgets('renders the no-check-ins hint when the log is empty', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      find.text('No check-ins yet — log one after you next talk.'),
      findsOneWidget,
    );
    // No star in the app bar for an unimportant relationship.
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('shows the error text when the relationship is gone', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => null,
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
  });
}
