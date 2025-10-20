import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/tags_service.dart';

import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Minimal registrations to satisfy dependencies in the card
    if (!getIt.isRegistered<EntitiesCacheService>()) {
      getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    }
    if (!getIt.isRegistered<TagsService>()) {
      final mockTags = MockTagsService();
      when(mockTags.watchTags)
          .thenAnswer((_) => Stream<List<TagEntity>>.value(const []));
      when(() => mockTags.tagsById).thenReturn({});
      getIt.registerSingleton<TagsService>(mockTags);
    }
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('date header uses tabular figures for entries', (tester) async {
    final entry = testTextEntry; // Non-event -> dfShorter

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(ModernJournalCard(item: entry)),
    );
    await tester.pumpAndSettle();

    final dateText = dfShorter.format(entry.meta.dateFrom);
    final finder = find.text(dateText);
    expect(finder, findsOneWidget);

    final textWidget = tester.widget<Text>(finder);
    final hasTabular =
        textWidget.style?.fontFeatures?.any((f) => f.feature == 'tnum') ??
            false;
    expect(hasTabular, isTrue);
  });

  testWidgets('date header uses tabular figures for events', (tester) async {
    // JournalEvent should use dfShort
    final now = DateTime.now();
    final event = JournalEvent(
      meta: Metadata(
        id: 'evt-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: const EventData(
        status: EventStatus.planned,
        // ignore: prefer_int_literals
        stars: 0.0,
        title: 'Title',
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(ModernJournalCard(item: event)),
    );
    await tester.pumpAndSettle();

    final dateText = dfShort.format(event.meta.dateFrom);
    final finder = find.text(dateText);
    expect(finder, findsOneWidget);

    final textWidget = tester.widget<Text>(finder);
    final hasTabular =
        textWidget.style?.fontFeatures?.any((f) => f.feature == 'tnum') ??
            false;
    expect(hasTabular, isTrue);
  });
}
