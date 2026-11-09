import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/widgets/event_summary_card.dart';
import 'package:lotti/features/events/ui/widgets/linked_event_card.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/journal_image_fixtures.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 11, 9, 10);
  final launch = CategoryDefinition(
    id: 'launch',
    name: 'Launch Ops',
    color: '#3B82F6',
    createdAt: at,
    updatedAt: at,
    vectorClock: null,
    private: false,
    active: true,
  );

  const iceRef = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 'ice-pad',
    title: 'Check the ice-pad weather window (as said)',
  );
  const coldRef = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 'cold-chain',
    title: 'Audit the cold-chain freezer logs',
  );

  TaskStatus inProgress() =>
      TaskStatus.inProgress(id: 's', createdAt: at, utcOffset: 0);

  FrontTaskPreview ice({
    String title = 'Check the ice-pad weather window',
    TaskStatus? status,
    String? oneLiner = 'Crosswind near the 18-knot limit',
    DateTime? due,
    Duration? estimate = const Duration(minutes: 90),
    String? categoryId = 'launch',
    String? coverArtId,
  }) => FrontTaskPreview(
    entityId: 'ice-pad',
    title: title,
    status: status ?? inProgress(),
    oneLiner: oneLiner,
    due: due ?? DateTime(2026, 11, 9, 17),
    estimate: estimate,
    categoryId: categoryId,
    coverArtId: coverArtId,
    coverArtCropX: 0.2,
  );

  late List<FrontEntityReference> opened;
  late StreamController<Set<String>> updates;
  late MockUpdateNotifications notifications;

  setUp(() {
    updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
  });

  final rehearsalRef = FrontEntityReference(
    kind: FrontEntityKind.event,
    id: testRehearsalEvent.meta.id,
    title: 'Launch-day rehearsal (as said)',
  );

  /// Pumps [references] as her list, each resolving through [load].
  Future<void> pump(
    WidgetTester tester, {
    List<FrontEntityReference> references = const [iceRef],
    Future<FrontEntityPreview?> Function(FrontEntityKey key)? load,
    Future<TaskPreview?> Function(String id)? loadTask,
    Future<JournalEntity?> Function(String id)? loadEntity,
    CategoryDefinition? category,
  }) async {
    opened = [];
    final cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(category);
    // An event card resolves its category and its photos' folder through
    // the locator, as it does wherever an event is linked.
    await setUpTestGetIt(
      additionalSetup: () => getIt
        ..registerSingleton<EntitiesCacheService>(cache)
        ..registerSingleton<Directory>(Directory.systemTemp),
    );
    addTearDown(tearDownTestGetIt);
    final journalDb = MockJournalDb();
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer(
      (i) async => loadEntity?.call(i.positionalArguments.single as String),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: FrontEntityPreviewList(
              references: references,
              onOpen: opened.add,
            ),
          ),
        ),
        overrides: [
          // Either the preview itself, or — for what follows the task as
          // it changes — the task under it.
          if (load != null)
            frontEntityPreviewProvider.overrideWith((ref, key) => load(key)),
          if (loadTask != null)
            taskPreviewProvider.overrideWith((ref, id) => loadTask(id)),
          entitiesCacheServiceProvider.overrideWithValue(cache),
          // An event, for what follows the event as it changes.
          journalDbProvider.overrideWithValue(journalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
          // The rehearsal links nothing yet.
          resolvedOutgoingLinkedEntriesProvider(
            testRehearsalEvent.meta.id,
          ).overrideWithValue(const []),
          // A cover resolves its image entry; none is on disk here.
          createEntryControllerOverride(buildJournalImage(id: 'cover-1')),
        ],
      ),
    );
    await tester.pump();
  }

  DesignSystemListItem item(WidgetTester tester, String id) =>
      tester.widget<DesignSystemListItem>(
        find.descendant(
          of: find.byKey(FrontEntityPreviewKeys.card(id)),
          matching: find.byType(DesignSystemListItem),
        ),
      );

  /// The subtitle's spans, read back as text, widgets as their own words.
  String subtitle(WidgetTester tester, String id) => [
    for (final span in item(tester, id).subtitleSpans ?? const <InlineSpan>[])
      if (span is TextSpan) span.text ?? '' else '[widget]',
  ].join();

  group('FrontEntityPreviewList', () {
    testWidgets('draws one card per reference, in order, and a tap opens '
        'that one', (tester) async {
      await pump(
        tester,
        references: const [iceRef, coldRef],
        load: (_) async => null,
      );

      final iceTop = tester.getTopLeft(
        find.byKey(FrontEntityPreviewKeys.card('ice-pad')),
      );
      final coldTop = tester.getTopLeft(
        find.byKey(FrontEntityPreviewKeys.card('cold-chain')),
      );
      expect(iceTop.dy, lessThan(coldTop.dy));

      await tester.tap(find.byKey(FrontEntityPreviewKeys.card('cold-chain')));
      await tester.tap(find.byKey(FrontEntityPreviewKeys.card('ice-pad')));

      expect(opened, [coldRef, iceRef]);
    });

    testWidgets('keeps a small gap between cards', (tester) async {
      await pump(
        tester,
        references: const [iceRef, coldRef],
        load: (_) async => null,
      );
      final tokens = tester
          .element(find.byType(FrontEntityPreviewList))
          .designTokens;

      final gap =
          tester
              .getTopLeft(find.byKey(FrontEntityPreviewKeys.card('cold-chain')))
              .dy -
          tester
              .getBottomLeft(find.byKey(FrontEntityPreviewKeys.card('ice-pad')))
              .dy;

      expect(gap, tokens.spacing.step2);
    });
  });

  group('FrontEntityPreviewCompactCard', () {
    testWidgets('a task that is gone keeps the title it was made with, and '
        'still opens', (tester) async {
      await pump(tester, load: (_) async => null);

      expect(find.text(iceRef.title), findsOneWidget);
      expect(find.byType(StatusGlyph), findsNothing);
      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);

      await tester.tap(find.text(iceRef.title));
      expect(opened, [iceRef]);
    });

    testWidgets('until it has loaded, the title it was made with stands '
        'alone', (tester) async {
      final never = Completer<FrontEntityPreview?>();
      await pump(tester, load: (_) => never.future);

      expect(find.text(iceRef.title), findsOneWidget);
      expect(find.byType(StatusGlyph), findsNothing);
    });

    testWidgets('asks for the preview of its own kind and id', (tester) async {
      final asked = <FrontEntityKey>[];
      await pump(
        tester,
        references: const [iceRef, coldRef],
        load: (key) async {
          asked.add(key);
          return null;
        },
      );

      expect(asked, [
        (FrontEntityKind.task, 'ice-pad'),
        (FrontEntityKind.task, 'cold-chain'),
      ]);
    });

    testWidgets('a task shows its live title, how it stands, its one-liner, '
        'category, due date and estimate', (tester) async {
      await pump(tester, load: (_) async => ice(), category: launch);

      // Its title now, not the one it was made with.
      expect(find.text('Check the ice-pad weather window'), findsOneWidget);
      expect(find.text(iceRef.title), findsNothing);
      expect(
        tester.widget<StatusGlyph>(find.byType(StatusGlyph)).status,
        inProgress(),
      );
      expect(
        subtitle(tester, 'ice-pad'),
        'Crosswind near the 18-knot limit\n'
        'In Progress · [widget] Launch Ops   [widget]   [widget]',
      );
      expect(find.byType(ColorIcon), findsOneWidget);
      expect(
        tester.widget<DueDateText>(find.byType(DueDateText)).dueDate,
        DateTime(2026, 11, 9, 17),
      );
      final estimate = find.byKey(FrontEntityPreviewKeys.estimate('ice-pad'));
      expect(
        find.descendant(of: estimate, matching: find.text('1h 30m')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: estimate, matching: find.byIcon(LottiIcons.timer)),
        findsOneWidget,
      );
    });

    testWidgets('reads as one line to a screen reader', (tester) async {
      await pump(tester, load: (_) async => ice(), category: launch);

      expect(
        item(tester, 'ice-pad').semanticsLabel,
        'Check the ice-pad weather window, Crosswind near the 18-knot limit, '
        'In Progress, Launch Ops, Estimate: 1h 30m',
      );
    });

    testWidgets('the one-liner leads in the AI ink, with room to wrap', (
      tester,
    ) async {
      await pump(tester, load: (_) async => ice());
      final tokens = tester
          .element(find.byType(FrontEntityPreviewList))
          .designTokens;

      final first = item(tester, 'ice-pad').subtitleSpans!.first as TextSpan;
      expect(first.text, 'Crosswind near the 18-knot limit\n');
      expect(first.style?.color, tokens.colors.aiCard.accent);
      expect(item(tester, 'ice-pad').subtitleMaxLines, 4);
    });

    testWidgets('without a one-liner, category or estimate, only how it '
        'stands and when it is due', (tester) async {
      await pump(
        tester,
        load: (_) async =>
            ice(oneLiner: null, categoryId: null, estimate: null),
      );

      expect(subtitle(tester, 'ice-pad'), 'In Progress   [widget]');
      expect(item(tester, 'ice-pad').subtitleMaxLines, 2);
      expect(find.byType(ColorIcon), findsNothing);
      expect(
        find.byKey(FrontEntityPreviewKeys.estimate('ice-pad')),
        findsNothing,
      );
      expect(
        item(tester, 'ice-pad').semanticsLabel,
        'Check the ice-pad weather window, In Progress',
      );
    });

    testWidgets('a category the app does not know is left out', (
      tester,
    ) async {
      await pump(tester, load: (_) async => ice(oneLiner: null));

      expect(find.byType(ColorIcon), findsNothing);
      expect(subtitle(tester, 'ice-pad'), startsWith('In Progress   '));
    });

    for (final (name, status, label) in [
      ('done', TaskStatus.done(id: 's', createdAt: at, utcOffset: 0), 'Done'),
      (
        'rejected',
        TaskStatus.rejected(id: 's', createdAt: at, utcOffset: 0),
        'Rejected',
      ),
    ]) {
      testWidgets('a $name task says so, without a due date or an estimate', (
        tester,
      ) async {
        await pump(
          tester,
          load: (_) async => ice(status: status, oneLiner: null),
        );

        expect(subtitle(tester, 'ice-pad'), label);
        expect(find.byType(DueDateText), findsNothing);
        expect(
          find.byKey(FrontEntityPreviewKeys.estimate('ice-pad')),
          findsNothing,
        );
      });
    }

    testWidgets('a task with a cover leads with it, cropped as the task '
        'crops it, in place of its status glyph', (tester) async {
      await pump(tester, load: (_) async => ice(coverArtId: 'cover-1'));

      final cover = find.byKey(FrontEntityPreviewKeys.cover('ice-pad'));
      expect(cover, findsOneWidget);
      final thumbnail = tester.widget<CoverArtThumbnail>(
        find.descendant(of: cover, matching: find.byType(CoverArtThumbnail)),
      );
      expect(thumbnail.imageId, 'cover-1');
      expect(thumbnail.cropX, 0.2);
      expect(thumbnail.size, ControlSizes.iconChip);
      expect(find.byType(StatusGlyph), findsNothing);
      // How it stands is still said, in words.
      expect(subtitle(tester, 'ice-pad'), contains('In Progress'));
    });

    testWidgets('a tap on a loaded task opens it', (tester) async {
      await pump(tester, load: (_) async => ice());

      await tester.tap(find.text('Check the ice-pad weather window'));

      expect(opened, [iceRef]);
    });

    testWidgets('stays on screen while the task under it reloads, then '
        'changes in place', (tester) async {
      Task task(String title) => testTask.copyWith(
        meta: testTask.meta.copyWith(id: 'ice-pad'),
        data: testTask.data.copyWith(title: title, status: inProgress()),
      );
      var reload = Completer<TaskPreview?>()
        ..complete(TaskPreview(task: task('Check the ice-pad weather window')));
      await pump(tester, loadTask: (_) => reload.future);
      expect(find.text('Check the ice-pad weather window'), findsOneWidget);

      // The task changed — a rename, a new report: the card's preview
      // reloads because what it depends on did.
      reload = Completer<TaskPreview?>();
      ProviderScope.containerOf(
        tester.element(find.byType(FrontEntityPreviewList)),
      ).invalidate(taskPreviewProvider('ice-pad'));
      await tester.pump();

      // Reloading: the task as it was, never the bare title it was made
      // with.
      expect(find.text('Check the ice-pad weather window'), findsOneWidget);
      expect(find.text(iceRef.title), findsNothing);

      reload.complete(
        TaskPreview(task: task('Check the ice-pad weather window — go')),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Check the ice-pad weather window — go'),
        findsOneWidget,
      );
    });

    testWidgets("sits on the card surface, the design system's medium radius "
        'and a hairline border', (tester) async {
      await pump(tester, load: (_) async => ice());
      final context = tester.element(find.byType(FrontEntityPreviewList));
      final tokens = context.designTokens;

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(FrontEntityPreviewKeys.card('ice-pad')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, dsCardSurface(context));
      expect(
        decoration.borderRadius,
        BorderRadius.circular(tokens.radii.m),
      );
      final border = decoration.border! as Border;
      expect(border.top.width, 0.5);
      expect(border.top.color, tokens.colors.decorative.level01);
    });
  });

  group('FrontEntityPreviewRichCard', () {
    testWidgets('a list draws a task as the compact card and an event as the '
        'rich one', (tester) async {
      await pump(
        tester,
        references: [iceRef, rehearsalRef],
        load: (_) async => null,
      );

      expect(
        find.descendant(
          of: find.byKey(FrontEntityPreviewKeys.card('ice-pad')),
          matching: find.byType(FrontEntityPreviewCompactCard),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(FrontEntityPreviewKeys.card(rehearsalRef.id)),
          matching: find.byType(FrontEntityPreviewRichCard),
          matchRoot: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('an event is drawn as the app draws a linked event, and a tap '
        'is handed to the chat rather than opening the page behind it', (
      tester,
    ) async {
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;
      addTearDown(() => beamToNamedOverride = null);
      await pump(
        tester,
        references: [rehearsalRef],
        load: (_) async => FrontEventPreview(testRehearsalEvent),
      );

      final card = tester.widget<LinkedEventCard>(find.byType(LinkedEventCard));
      expect(card.event, testRehearsalEvent);
      expect(find.byType(EventSummaryCard), findsOneWidget);
      expect(find.text('Launch-day rehearsal at the ice pad'), findsOneWidget);
      expect(find.text(rehearsalRef.title), findsNothing);

      await tester.tap(find.byType(EventSummaryCard));
      await tester.pump();

      expect(opened, [rehearsalRef]);
      expect(beamed, isEmpty);
    });

    testWidgets('an event that is gone keeps the title it was made with, and '
        'still opens', (tester) async {
      await pump(tester, references: [rehearsalRef], load: (_) async => null);

      expect(find.byType(LinkedEventCard), findsNothing);
      expect(find.text(rehearsalRef.title), findsOneWidget);

      await tester.tap(find.text(rehearsalRef.title));
      expect(opened, [rehearsalRef]);
    });

    testWidgets("a preview of another kind than the card's draws only the "
        'title', (tester) async {
      await pump(
        tester,
        references: [rehearsalRef, iceRef],
        load: (key) async => switch (key.$1) {
          FrontEntityKind.event => ice(),
          FrontEntityKind.task => FrontEventPreview(testRehearsalEvent),
        },
      );

      expect(find.byType(LinkedEventCard), findsNothing);
      expect(find.byType(StatusGlyph), findsNothing);
      expect(find.text(rehearsalRef.title), findsOneWidget);
      expect(find.text(iceRef.title), findsOneWidget);
    });

    testWidgets('stays on screen while the event under it reloads, then '
        'changes in place', (tester) async {
      final id = testRehearsalEvent.meta.id;
      var reload = Completer<JournalEntity?>()..complete(testRehearsalEvent);
      await pump(
        tester,
        references: [rehearsalRef],
        loadEntity: (_) => reload.future,
      );
      expect(find.text('Launch-day rehearsal at the ice pad'), findsOneWidget);

      // The event was renamed: a notification names it.
      reload = Completer<JournalEntity?>();
      updates.add({id});
      await tester.pump();
      await tester.pump();

      expect(find.text('Launch-day rehearsal at the ice pad'), findsOneWidget);
      expect(find.text(rehearsalRef.title), findsNothing);

      reload.complete(
        testRehearsalEvent.copyWith(
          data: testRehearsalEvent.data.copyWith(title: 'Rehearsal, moved'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Rehearsal, moved'), findsOneWidget);
    });
  });
}
