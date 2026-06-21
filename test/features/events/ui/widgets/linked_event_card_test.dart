import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/events/ui/widgets/event_summary_card.dart';
import 'package:lotti/features/events/ui/widgets/linked_event_card.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

JournalEvent _event(String id, {String? categoryId}) {
  final now = DateTime(2026, 5, 12);
  return JournalEvent(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: categoryId,
    ),
    data: const EventData(
      title: 'Summer Festival',
      stars: 0,
      status: EventStatus.completed,
    ),
  );
}

JournalImage _image(String id) {
  final now = DateTime(2026, 5, 12);
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: ImageData(
      capturedAt: now,
      imageId: id,
      imageFile: '$id.jpg',
      imageDirectory: '/images/2026/',
    ),
  );
}

void main() {
  late MockEntitiesCacheService cache;

  setUp(() async {
    await getIt.reset();
    cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    getIt
      ..registerSingleton<EntitiesCacheService>(cache)
      ..registerSingleton<Directory>(Directory.systemTemp);
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await getIt.reset();
  });

  testWidgets('renders a compact summary card and opens the event on tap', (
    tester,
  ) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedOutgoingLinkedEntriesProvider(
            'evt-1',
          ).overrideWithValue(const []),
        ],
        child: makeTestableWidget2(
          Scaffold(body: LinkedEventCard(event: _event('evt-1'))),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EventSummaryCard), findsOneWidget);
    expect(find.text('Summer Festival'), findsOneWidget);

    await tester.tap(find.byType(EventSummaryCard));
    await tester.pump();
    expect(beamed, ['/events/evt-1']);
  });

  testWidgets('resolves the category name and a linked-photo cover', (
    tester,
  ) async {
    when(() => cache.getCategoryById('cat-1')).thenReturn(
      CategoryDefinition(
        id: 'cat-1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        name: 'Friends',
        vectorClock: null,
        private: false,
        active: true,
        color: '#E91E63',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedOutgoingLinkedEntriesProvider(
            'evt-2',
          ).overrideWithValue([_image('img-1')]),
        ],
        child: makeTestableWidget2(
          Scaffold(
            body: LinkedEventCard(event: _event('evt-2', categoryId: 'cat-1')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EventSummaryCard), findsOneWidget);
    // The resolved category name renders in the card's meta line
    // ("Friends · <date>"), confirming the category lookup ran.
    expect(find.textContaining('Friends'), findsOneWidget);
  });
}
