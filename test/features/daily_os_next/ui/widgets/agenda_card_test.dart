import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_card.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
);

Widget _wrapPhone(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(390, 844)),
);

const _category = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

JournalImage _image({String id = 'image-1'}) {
  final now = DateTime(2026, 5, 26, 9);
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: ImageData(
      imageId: 'image-data-$id',
      imageFile: '$id.jpg',
      imageDirectory: '/covers/',
      capturedAt: now,
    ),
  );
}

void main() {
  group('AgendaCard', () {
    testWidgets('renders title, outcome and inline estimate metadata', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Send the leadership deck to Sarah',
                category: _category,
                linkedBlockIds: ['b1'],
                outcome: 'Deck reviewed by Sarah, sent to leadership.',
                totalEstimateMinutes: 120,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Send the leadership deck to Sarah'), findsOneWidget);
      expect(
        find.text('Deck reviewed by Sarah, sent to leadership.'),
        findsOneWidget,
      );
      expect(find.text('120m'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('shows why metadata when a whyReason is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Deep work',
                category: _category,
                linkedBlockIds: ['b1'],
              ),
              whyReason: 'High-energy window 8–10:30.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.text('WHY'), findsOneWidget);
      expect(find.byTooltip('High-energy window 8–10:30.'), findsOneWidget);
    });

    testWidgets('omits why metadata when no reason is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Plain item',
                category: _category,
                linkedBlockIds: ['b1'],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.text('WHY'), findsNothing);
    });

    testWidgets('invokes onTap when the card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Material(
            child: AgendaCard(
              index: 1,
              item: const AgendaItem(
                id: 'a1',
                title: 'Open task',
                category: _category,
                linkedBlockIds: ['b1'],
                taskId: 'task-1',
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open task'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('wraps long titles on phone layouts instead of ellipsizing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapPhone(
          const Material(
            child: AgendaCard(
              index: 2,
              item: AgendaItem(
                id: 'a1',
                title: 'Sprint Roundup presentation for leadership review',
                category: _category,
                linkedBlockIds: ['b1'],
                totalEstimateMinutes: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(
        find.text('Sprint Roundup presentation for leadership review'),
      );
      expect(title.maxLines, greaterThan(1));
      expect(title.overflow, TextOverflow.fade);
    });

    testWidgets('renders task cover art as the leading visual', (
      tester,
    ) async {
      final image = _image();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [createEntryControllerOverride(image)],
          child: _wrapPhone(
            const Material(
              child: AgendaCard(
                index: 3,
                item: AgendaItem(
                  id: 'a1',
                  title: 'Task with cover art',
                  category: _category,
                  linkedBlockIds: ['b1'],
                ),
                coverArtId: 'image-1',
                coverArtCropX: 0.25,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CoverArtThumbnail), findsOneWidget);
      final thumbnail = tester.widget<CoverArtThumbnail>(
        find.byType(CoverArtThumbnail),
      );
      expect(thumbnail.imageId, 'image-1');
      expect(thumbnail.cropX, 0.25);
    });

    testWidgets('renders non-open state and progress metadata', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 4,
              item: AgendaItem(
                id: 'a1',
                title: 'Close out shipped work',
                category: _category,
                linkedBlockIds: ['b1'],
                state: AgendaItemState.done,
                progress: 0.75,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.75);
    });
  });
}
