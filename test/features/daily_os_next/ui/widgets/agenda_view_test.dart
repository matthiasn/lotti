// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_donut.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../helpers/fake_entry_controller.dart';
import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    makeTestableWidgetNoScroll(
      child,
      overrides: overrides,
      mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
    );

const _category = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

DraftPlan _draft({String? taskId}) {
  final day = DateTime(2026, 5, 26);
  return DraftPlan(
    dayDate: day,
    blocks: const [],
    bands: const [],
    capacityMinutes: 480,
    scheduledMinutes: 60,
    agendaItems: [
      AgendaItem(
        id: 'agenda-1',
        title: 'Complete client animation',
        category: _category,
        linkedBlockIds: const ['block-1'],
        taskId: taskId,
        totalEstimateMinutes: 60,
      ),
    ],
  );
}

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
  tearDown(() => beamToNamedOverride = null);

  group('AgendaView', () {
    testWidgets('opens task-backed agenda items through app navigation', (
      tester,
    ) async {
      String? openedPath;
      beamToNamedOverride = (path) => openedPath = path;

      await tester.pumpWidget(_wrap(AgendaView(draft: _draft(taskId: 't1'))));
      await tester.pump();

      // The agenda title and the link badge both carry the item title
      // when no live task title resolves; tap the card title.
      await tester.tap(find.text('Complete client animation').first);
      await tester.pump();

      expect(openedPath, '/tasks/t1');
    });

    testWidgets('leaves standalone agenda items inert', (tester) async {
      String? openedPath;
      beamToNamedOverride = (path) => openedPath = path;

      await tester.pumpWidget(_wrap(AgendaView(draft: _draft())));
      await tester.pump();

      await tester.tap(find.text('Complete client animation'));
      await tester.pump();

      expect(openedPath, isNull);
    });

    testWidgets('uses live task title for linked agenda items', (
      tester,
    ) async {
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final mocks = await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);
      when(
        () => mocks.updateNotifications.updateStream,
      ).thenAnswer((_) => updates.stream);

      var task = TestTaskFactory.create(
        id: 't1',
        title: 'Updated task title',
      );
      when(() => mocks.journalDb.journalEntityById('t1')).thenAnswer(
        (_) async => task,
      );

      await tester.pumpWidget(
        _wrap(AgendaView(draft: _draft(taskId: 't1'))),
      );
      await tester.pump();

      // The live task name renders on the link badge; the card title
      // keeps the agenda intent line.
      expect(find.text('Updated task title'), findsOneWidget);
      expect(find.text('Complete client animation'), findsOneWidget);

      task = TestTaskFactory.create(
        id: 't1',
        title: 'Renamed from task detail',
      );
      updates.add({'t1'});
      await tester.idle();
      await tester.pump();
      await tester.idle();
      await tester.pump();

      expect(find.text('Renamed from task detail'), findsOneWidget);
      expect(find.text('Updated task title'), findsNothing);
    });

    testWidgets('passes linked task cover art through to agenda cards', (
      tester,
    ) async {
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final mocks = await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);
      when(
        () => mocks.updateNotifications.updateStream,
      ).thenAnswer((_) => updates.stream);

      final baseTask = TestTaskFactory.create(
        id: 't1',
        title: 'Task with cover art',
      );
      final task = baseTask.copyWith(
        data: baseTask.data.copyWith(
          coverArtId: 'image-1',
          coverArtCropX: 0.25,
        ),
      );
      when(() => mocks.journalDb.journalEntityById('t1')).thenAnswer(
        (_) async => task,
      );

      await tester.pumpWidget(
        _wrap(
          AgendaView(draft: _draft(taskId: 't1')),
          overrides: [createEntryControllerOverride(_image())],
        ),
      );
      await tester.pump();

      final thumbnail = tester.widget<CoverArtThumbnail>(
        find.byType(CoverArtThumbnail),
      );
      expect(thumbnail.imageId, 'image-1');
      expect(thumbnail.cropX, 0.25);
    });

    testWidgets('comfortable capacity (< 90%) shows comfortable overline', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 600,
        scheduledMinutes: 300, // 50% utilisation.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityComfortable),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextAgendaCapacityNearFull),
        findsNothing,
      );
      expect(
        find.text(messages.dailyOsNextAgendaCapacityOver),
        findsNothing,
      );
    });

    testWidgets('near-full capacity (90–100%) shows near-full overline', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 600,
        scheduledMinutes: 570, // 95%.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityNearFull),
        findsOneWidget,
      );
    });

    testWidgets('over-capacity (> 100%) shows over overline', (tester) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 600,
        scheduledMinutes: 720, // 120%.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityOver),
        findsOneWidget,
      );
    });

    testWidgets('summary string interpolates scheduled / capacity hours', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 240,
        scheduledMinutes: 90, // 1h 30m of 4h.
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaSummary('1h 30m', '4h')),
        findsOneWidget,
      );
      expect(find.byType(CapacityDonut), findsOneWidget);
    });

    testWidgets('empty agenda renders the dashed "No plan yet" hint card', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 240,
        scheduledMinutes: 0,
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(find.text(messages.dailyOsNextAgendaNoPlanTitle), findsOneWidget);
      expect(find.text(messages.dailyOsNextAgendaNoPlanBody), findsOneWidget);
      expect(find.byType(AgendaCard), findsNothing);
      // No tracked time -> no TimeSpentCard either.
      expect(find.byType(TimeSpentCard), findsNothing);
    });

    testWidgets(
      'no-plan day stays honest: eyebrow, tracked summary, legend, and '
      'the TimeSpentCard with the recorded sessions',
      (tester) async {
        final day = DateTime(2026, 5, 26);
        final tracked = [
          TimeBlock(
            id: 'tr1',
            title: 'Build attention framework',
            start: DateTime(2026, 5, 26, 8, 30),
            end: DateTime(2026, 5, 26, 10),
            type: TimeBlockType.manual,
            state: TimeBlockState.completed,
            category: _category,
            taskId: 'task-tr1',
          ),
          TimeBlock(
            id: 'tr2',
            title: 'UI improvements',
            start: DateTime(2026, 5, 26, 10, 30),
            end: DateTime(2026, 5, 26, 11, 35),
            type: TimeBlockType.manual,
            state: TimeBlockState.inProgress,
            category: _category,
          ),
        ];
        final draft = DraftPlan.emptyForDay(day);
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: draft,
              actualBlocks: tracked,
              hasPlan: false,
            ),
          ),
        );

        final messages = tester.element(find.byType(AgendaView)).messages;
        // Honest eyebrow + tracked-time summary (1h 30m + 1h 5m = 2h 35m).
        expect(
          find.text(messages.dailyOsNextAgendaCapacityNoPlan),
          findsOneWidget,
        );
        expect(
          find.text(messages.dailyOsNextAgendaNoPlanSummary('2h 35m')),
          findsOneWidget,
        );
        // Neutral donut + single tracked legend (1 completed session).
        final donut = tester.widget<CapacityDonut>(find.byType(CapacityDonut));
        expect(donut.neutral, isTrue);
        expect(donut.scheduledMinutes, 155);
        expect(
          find.text(messages.dailyOsNextAgendaTrackedLegend('2h 35m', 1)),
          findsOneWidget,
        );
        // The recorded sessions are listed in the TimeSpentCard.
        expect(find.byType(TimeSpentCard), findsOneWidget);
        expect(find.text('Build attention framework'), findsOneWidget);
        expect(find.text('UI improvements'), findsOneWidget);
      },
    );

    testWidgets(
      'category mix renders one legend per used category, dropped blocks excluded',
      (tester) async {
        const work = DayAgentCategory(
          id: 'w',
          name: 'Work',
          colorHex: '5ED4B7',
        );
        const personal = DayAgentCategory(
          id: 'p',
          name: 'Personal',
          colorHex: 'FF00AA',
        );
        final start = DateTime(2026, 5, 26, 9);
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: [
            TimeBlock(
              id: 'b1',
              title: 'Deep work',
              start: start,
              end: start.add(const Duration(minutes: 90)),
              type: TimeBlockType.ai,
              state: TimeBlockState.drafted,
              category: work,
            ),
            TimeBlock(
              id: 'b2',
              title: 'Errands',
              start: start.add(const Duration(hours: 2)),
              end: start.add(const Duration(hours: 2, minutes: 30)),
              type: TimeBlockType.manual,
              state: TimeBlockState.drafted,
              category: personal,
            ),
            TimeBlock(
              id: 'b3',
              title: 'Cancelled review',
              start: start.add(const Duration(hours: 4)),
              end: start.add(const Duration(hours: 5)),
              type: TimeBlockType.ai,
              state: TimeBlockState.dropped,
              category: work,
            ),
          ],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 120,
          agendaItems: const [],
        );
        await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

        // 90m of Work (dropped 60m excluded), 30m of Personal.
        expect(find.text('Work · 1h 30m'), findsOneWidget);
        expect(find.text('Personal · 30m'), findsOneWidget);
      },
    );

    testWidgets('zero-capacity day computes ratio safely (no divide-by-zero)', (
      tester,
    ) async {
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: const [],
        bands: const [],
        capacityMinutes: 0,
        scheduledMinutes: 0,
        agendaItems: const [],
      );
      await tester.pumpWidget(_wrap(AgendaView(draft: draft)));

      // Ratio defaults to 0 → comfortable overline.
      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityComfortable),
        findsOneWidget,
      );
    });
  });
}
