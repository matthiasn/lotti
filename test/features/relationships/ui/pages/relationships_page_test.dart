import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
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

  RelationshipEntry relationship(
    String id, {
    required String title,
    bool important = false,
  }) => RelationshipEntry(
    meta: Metadata(
      id: id,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: title,
      important: important,
      status: RelationshipStatus.active(
        id: 'status-$id',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
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
      home: const RelationshipsPage(),
    ),
  );

  testWidgets('renders the empty state when nothing is tracked', (
    tester,
  ) async {
    when(() => mockRepository.getRelationships()).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      find.text('Add the people you want to stay close to.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders one row per relationship and stars only important ones',
    (tester) async {
      when(() => mockRepository.getRelationships()).thenAnswer(
        (_) async => [
          relationship('rel-1', title: 'Anna', important: true),
          relationship('rel-2', title: 'Ben'),
        ],
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
      // Exactly one star: Anna is important, Ben is not.
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(
        find.text('Add the people you want to stay close to.'),
        findsNothing,
      );
    },
  );
}
