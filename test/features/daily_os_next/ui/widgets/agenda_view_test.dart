// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agenda_row.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/design_system/components/cards/ds_rows_card.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../helpers/fake_entry_controller.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

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

      // The live task name renders on the row's meta line; the row title
      // keeps the agenda intent line.
      expect(find.text('Updated task title'), findsOneWidget);
      expect(find.text('Complete client animation'), findsOneWidget);

      task = TestTaskFactory.create(
        id: 't1',
        title: 'Renamed from task detail',
      );
      updates.add({'t1'});
      // Two idle/pump cycles are required, not padding. `updateStream` is a
      // broadcast `StreamController`: the first idle lets the broadcast event
      // reach the watching provider's subscription and schedule a refetch, the
      // first pump runs that microtask and the async `journalEntityById` lookup
      // resolves the new task; the second idle/pump then flushes the resulting
      // provider state change into a rebuild so the renamed title is rendered.
      await tester.idle();
      await tester.pump();
      await tester.idle();
      await tester.pump();

      expect(find.text('Renamed from task detail'), findsOneWidget);
      expect(find.text('Updated task title'), findsNothing);
    });

    testWidgets(
      'projects task category reassignment and category edits immediately',
      (tester) async {
        final updates = StreamController<Set<String>>.broadcast();
        addTearDown(updates.close);
        final mocks = await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);
        when(
          () => mocks.updateNotifications.updateStream,
        ).thenAnswer((_) => updates.stream);

        var task = TestTaskFactory.create(
          id: 't1',
          title: 'Move the penguins',
          categoryId: 'cat-work',
        );
        var personal = CategoryTestUtils.createTestCategory(
          id: 'cat-personal',
          name: 'Personal',
          color: '#34D399',
        );
        final work = CategoryTestUtils.createTestCategory(
          id: 'cat-work',
          name: 'Work',
          color: '#4F9DDE',
        );
        when(() => mocks.journalDb.journalEntityById('t1')).thenAnswer(
          (_) async => task,
        );
        when(() => mocks.journalDb.getCategoryById(any())).thenAnswer(
          (invocation) async =>
              switch (invocation.positionalArguments.single as String) {
                'cat-work' => work,
                'cat-personal' => personal,
                _ => null,
              },
        );

        await tester.pumpWidget(
          _wrap(AgendaView(draft: _draft(taskId: 't1'))),
        );
        await tester.pump();

        DayAgendaRow agendaCard() =>
            tester.widget<DayAgendaRow>(find.byType(DayAgendaRow));
        expect(agendaCard().item.category.id, 'cat-work');
        expect(agendaCard().item.category.name, 'Work');
        expect(agendaCard().item.category.colorHex, '4F9DDE');

        task = TestTaskFactory.create(
          id: 't1',
          title: 'Move the penguins',
          categoryId: 'cat-personal',
        );
        updates.add({'t1'});
        await tester.idle();
        await tester.pump();
        await tester.idle();
        await tester.pump();

        expect(agendaCard().item.category.id, 'cat-personal');
        expect(agendaCard().item.category.name, 'Personal');
        expect(agendaCard().item.category.colorHex, '34D399');

        personal = personal.copyWith(
          name: 'Penguin Logistics',
          color: '#A855F7',
        );
        updates.add({categoriesNotification});
        await tester.idle();
        await tester.pump();
        await tester.idle();
        await tester.pump();

        expect(agendaCard().item.category.id, 'cat-personal');
        expect(agendaCard().item.category.name, 'Penguin Logistics');
        expect(agendaCard().item.category.colorHex, 'A855F7');
      },
    );

    testWidgets('leaves linked task cover art to the task page', (
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

      // The category dot is the row's only mark; the cover stays on the
      // task page and in the companion's cards.
      expect(find.byType(DayAgendaRow), findsOneWidget);
      expect(find.byType(CoverArtThumbnail), findsNothing);
    });

    testWidgets('shows a visible fallback when a linked task is missing', (
      tester,
    ) async {
      await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      await tester.pumpWidget(
        _wrap(AgendaView(draft: _draft(taskId: 'missing-task'))),
      );
      await tester.pump();
      await tester.pump();

      final messages = tester.element(find.byType(AgendaView)).messages;
      expect(
        find.text(messages.conflictDetailEntryNotFoundTitle),
        findsOneWidget,
      );
      expect(find.text('Complete client animation'), findsOneWidget);
    });

    testWidgets(
      "surfaces the linked AI block's reason on the row",
      (tester) async {
        final day = DateTime(2026, 5, 26);
        final draft = DraftPlan(
          dayDate: day,
          blocks: [
            TimeBlock(
              id: 'block-1',
              title: 'Deep work',
              start: DateTime(2026, 5, 26, 9),
              end: DateTime(2026, 5, 26, 10),
              type: TimeBlockType.ai,
              state: TimeBlockState.drafted,
              category: _category,
              reason: 'High-energy window 8-10:30.',
            ),
          ],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 60,
          agendaItems: const [
            AgendaItem(
              id: 'agenda-1',
              title: 'Deep work',
              category: _category,
              linkedBlockIds: ['block-1'],
            ),
          ],
        );
        await tester.pumpWidget(_wrap(AgendaView(draft: draft)));
        await tester.pump();

        // The AI placement's reason reaches the row as its second line.
        expect(find.text('High-energy window 8-10:30.'), findsOneWidget);
        expect(
          tester.widget<DayAgendaRow>(find.byType(DayAgendaRow)).whyReason,
          'High-energy window 8-10:30.',
        );
      },
    );

    group('order and card', () {
      TimeBlock block(String id, int hour, {bool dropped = false}) => TimeBlock(
        id: id,
        title: id,
        start: DateTime(2026, 5, 26, hour),
        end: DateTime(2026, 5, 26, hour + 1),
        type: TimeBlockType.ai,
        state: dropped ? TimeBlockState.dropped : TimeBlockState.drafted,
        category: _category,
      );
      AgendaItem item(String id, List<String> blocks) => AgendaItem(
        id: id,
        title: 'Item $id',
        category: _category,
        linkedBlockIds: blocks,
      );
      DraftPlan plan(List<TimeBlock> blocks, List<AgendaItem> items) =>
          DraftPlan(
            dayDate: DateTime(2026, 5, 26),
            blocks: blocks,
            bands: const [],
            capacityMinutes: 480,
            scheduledMinutes: 0,
            agendaItems: items,
          );
      List<(String, DateTime?)> rowsOf(WidgetTester tester) => [
        for (final row in tester.widgetList<DayAgendaRow>(
          find.byType(DayAgendaRow),
        ))
          (row.item.id, row.start),
      ];

      testWidgets('orders the rows by their first block, not plan order', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('b9', 9), block('b13', 13), block('b11', 11)],
                [
                  item('late', ['b13']),
                  item('early', ['b9', 'b11']),
                ],
              ),
            ),
          ),
        );

        expect(rowsOf(tester), [
          ('early', DateTime(2026, 5, 26, 9)),
          ('late', DateTime(2026, 5, 26, 13)),
        ]);
      });

      testWidgets('an item with several blocks takes the earliest start', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('b14', 14), block('b8', 8)],
                [
                  item('split', ['b14', 'b8']),
                ],
              ),
            ),
          ),
        );

        expect(rowsOf(tester).single.$2, DateTime(2026, 5, 26, 8));
      });

      testWidgets('items with no block sort last, in plan order', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('b10', 10)],
                [
                  item('loose-a', const []),
                  item('timed', ['b10']),
                  item('loose-b', ['missing']),
                ],
              ),
            ),
          ),
        );

        expect(rowsOf(tester), [
          ('timed', DateTime(2026, 5, 26, 10)),
          ('loose-a', null),
          ('loose-b', null),
        ]);
      });

      testWidgets('items starting together keep plan order', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('x', 9), block('y', 9)],
                [
                  item('second', ['y']),
                  item('first', ['x']),
                ],
              ),
            ),
          ),
        );

        expect(rowsOf(tester).map((r) => r.$1), ['second', 'first']);
      });

      testWidgets('a dropped block holds no time', (tester) async {
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('gone', 7, dropped: true), block('kept', 12)],
                [
                  item('moved', ['gone', 'kept']),
                ],
              ),
            ),
          ),
        );

        expect(rowsOf(tester).single.$2, DateTime(2026, 5, 26, 12));
      });

      testWidgets('the rows share one card, each keyed by its item', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('b9', 9), block('b10', 10)],
                [
                  item('a', ['b9']),
                  item('b', ['b10']),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(DsRowsCard), findsOneWidget);
        expect(find.byKey(const ValueKey('a')), findsOneWidget);
        expect(find.byKey(const ValueKey('b')), findsOneWidget);
      });

      testWidgets('renaming a standalone row hands the item and its title up', (
        tester,
      ) async {
        final renames = <(String, String)>[];
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('b9', 9)],
                [
                  item('solo', ['b9']),
                ],
              ),
              onRenameItem: (item, title) => renames.add((item.id, title)),
            ),
          ),
        );

        await tester.tap(find.text('Item solo'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('daily_os_editable_title_field')),
          'Renamed',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(renames, [('solo', 'Renamed')]);
      });

      testWidgets('renaming a standalone row hands the item and its title up', (
        tester,
      ) async {
        final renames = <(String, String)>[];
        await tester.pumpWidget(
          _wrap(
            AgendaView(
              draft: plan(
                [block('b9', 9)],
                [
                  item('solo', ['b9']),
                ],
              ),
              onRenameItem: (item, title) => renames.add((item.id, title)),
            ),
          ),
        );

        await tester.tap(find.text('Item solo'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('daily_os_editable_title_field')),
          'Renamed',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(renames, [('solo', 'Renamed')]);
      });

      testWidgets('a plan with no items draws no card', (tester) async {
        await tester.pumpWidget(
          _wrap(AgendaView(draft: plan(const [], const []))),
        );

        expect(find.byType(DsRowsCard), findsNothing);
      });
    });

    testWidgets(
      'no-plan day renders the dashed "No plan yet" hint card; a real '
      'plan with zero agenda items does not',
      (tester) async {
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: const [],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 0,
          agendaItems: const [],
        );
        await tester.pumpWidget(
          _wrap(AgendaView(draft: draft, hasPlan: false)),
        );

        final messages = tester.element(find.byType(AgendaView)).messages;
        expect(
          find.text(messages.dailyOsNextAgendaNoPlanTitle),
          findsOneWidget,
        );
        expect(
          find.text(messages.dailyOsNextAgendaNoPlanBody),
          findsOneWidget,
        );
        expect(find.byType(DayAgendaRow), findsNothing);
        // No tracked time -> no TimeSpentCard either.
        expect(find.byType(TimeSpentCard), findsNothing);

        // With a real (if empty) plan the no-plan copy would be a lie.
        await tester.pumpWidget(_wrap(AgendaView(draft: draft)));
        expect(
          find.text(messages.dailyOsNextAgendaNoPlanTitle),
          findsNothing,
        );
      },
    );

    testWidgets(
      'no-plan day lists the recorded sessions in the TimeSpentCard',
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

        // The recorded sessions are listed in the TimeSpentCard.
        expect(find.byType(TimeSpentCard), findsOneWidget);
        expect(find.text('Build attention framework'), findsOneWidget);
        expect(find.text('UI improvements'), findsOneWidget);
      },
    );
  });
}
