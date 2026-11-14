import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/widgets/event_summary_card.dart';
import 'package:lotti/features/events/ui/widgets/linked_event_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_row.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/header/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/project_lookup_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/journal_image_fixtures.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';

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
    TaskPriority priority = TaskPriority.p2Medium,
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
    priority: priority,
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
    Future<DraftPlan?> Function(DateTime day)? loadPlan,
    CategoryDefinition? category,
    List<Override> extra = const [],
    bool showsGenerated = false,
    Set<String> codingPromptTaskIds = const {},
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
              showsGenerated: showsGenerated,
              codingPromptTaskIds: codingPromptTaskIds,
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
          if (loadPlan != null)
            currentDraftPlanProvider.overrideWith(
              (ref, day) => loadPlan(day),
            ),
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
          ...extra,
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

    testWidgets('a note she attached to a task is on its card, first under '
        'the title, and read out with it', (tester) async {
      await pump(
        tester,
        references: const [
          FrontEntityReference(
            kind: FrontEntityKind.task,
            id: 'ice-pad',
            title: 'Check the ice-pad weather window',
            note: '2h 10m',
          ),
        ],
        load: (_) async => ice(),
      );

      final card = find.byKey(FrontEntityPreviewKeys.card('ice-pad'));
      final subtitle = tester
          .widgetList<RichText>(
            find.descendant(of: card, matching: find.byType(RichText)),
          )
          .map((text) => text.text.toPlainText())
          .firstWhere((text) => text.contains('2h 10m'));
      // The note leads the lines under the title, ahead of the one-liner.
      expect(
        subtitle.indexOf('2h 10m'),
        lessThan(subtitle.indexOf('Crosswind near the 18-knot limit')),
      );
      expect(
        find.bySemanticsLabel(RegExp('weather window.*2h 10m.*Crosswind')),
        findsOneWidget,
      );
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
        'In Progress, Launch Ops, P2, Estimate: 1h 30m',
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
        'Check the ice-pad weather window, In Progress, P2',
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

  group('what is generated for a task her chat made', () {
    late List<String> promptReads;

    /// Pumps the made task's card: [prompt] is the summary of the coding
    /// prompt written for it, and each of [running] and [failed] a
    /// generation in that state.
    Future<ProviderContainer> pumpMade(
      WidgetTester tester, {
      FrontTaskPreview? task,
      String? prompt,
      Set<AiResponseType> running = const {},
      Set<AiResponseType> failed = const {},
      bool showsGenerated = true,
      // Whether a coding prompt was asked for where the task was made.
      bool promptRequested = true,
    }) async {
      promptReads = [];
      await pump(
        tester,
        load: (_) async => task ?? ice(),
        showsGenerated: showsGenerated,
        codingPromptTaskIds: {if (promptRequested) 'ice-pad'},
        extra: [
          frontTaskCodingPromptProvider.overrideWith((ref, id) async {
            promptReads.add(id);
            return prompt;
          }),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontEntityPreviewList)),
      );
      void set(AiResponseType type, InferenceStatus status) => container
          .read(
            inferenceStatusControllerProvider((
              id: 'ice-pad',
              aiResponseType: type,
            )).notifier,
          )
          .setStatus(status);
      for (final type in running) {
        set(type, InferenceStatus.running);
      }
      for (final type in failed) {
        set(type, InferenceStatus.error);
      }
      await tester.pump();
      await tester.pump();
      return container;
    }

    Finder line(String name) =>
        find.byKey(FrontEntityPreviewKeys.generated('ice-pad', name));
    Text textIn(WidgetTester tester, Finder of, String text) =>
        tester.widget<Text>(
          find.descendant(of: of, matching: find.text(text)),
        );
    DsTokens tokensOf(WidgetTester tester) =>
        tester.element(find.byType(FrontEntityPreviewList)).designTokens;

    testWidgets('a task nothing was asked for is the card as it always was', (
      tester,
    ) async {
      await pumpMade(tester);

      expect(find.byType(DesignSystemDivider), findsNothing);
      for (final name in [
        'cover-drawing',
        'cover-failed',
        'prompt',
        'prompt-writing',
        'prompt-failed',
      ]) {
        expect(line(name), findsNothing, reason: name);
      }
      expect(find.byType(StatusGlyph), findsOneWidget);
    });

    group('cover art', () {
      testWidgets('while it is drawn, its place holds a tile in the AI ink '
          'and the card says so', (tester) async {
        await pumpMade(tester, running: {AiResponseType.imageGeneration});

        final tile = find.byKey(
          FrontEntityPreviewKeys.coverDrawing('ice-pad'),
        );
        expect(tile, findsOneWidget);
        expect(tester.getSize(tile), const Size.square(ControlSizes.iconChip));
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: tile, matching: find.byType(Icon)),
              )
              .icon,
          LottiIcons.image,
        );
        // In place of the status glyph, which the words still give.
        expect(find.byType(StatusGlyph), findsNothing);
        expect(subtitle(tester, 'ice-pad'), contains('In Progress'));
        expect(
          textIn(
            tester,
            line('cover-drawing'),
            'Drawing the cover…',
          ).style!.color,
          tokensOf(tester).colors.aiCard.accent,
        );
      });

      testWidgets('once it arrives, the thumbnail takes its place and the '
          'card says no more about it', (tester) async {
        await pumpMade(
          tester,
          task: ice(coverArtId: 'cover-1'),
          // Still reported running for a moment after the cover is set.
          running: {AiResponseType.imageGeneration},
        );

        expect(
          find.byKey(FrontEntityPreviewKeys.cover('ice-pad')),
          findsOneWidget,
        );
        expect(
          find.byKey(FrontEntityPreviewKeys.coverDrawing('ice-pad')),
          findsNothing,
        );
        expect(line('cover-drawing'), findsNothing);
        expect(find.byType(DesignSystemDivider), findsNothing);
      });

      testWidgets('one that could not be drawn says so in the error ink, '
          'the status glyph back in its place', (tester) async {
        await pumpMade(tester, failed: {AiResponseType.imageGeneration});

        expect(
          textIn(
            tester,
            line('cover-failed'),
            'The cover could not be drawn',
          ).style!.color,
          tokensOf(tester).colors.alert.error.ink,
        );
        expect(
          find.byKey(FrontEntityPreviewKeys.coverDrawing('ice-pad')),
          findsNothing,
        );
        expect(find.byType(StatusGlyph), findsOneWidget);
      });

      testWidgets('follows the run as it goes: drawn, then done', (
        tester,
      ) async {
        final container = await pumpMade(
          tester,
          running: {AiResponseType.imageGeneration},
        );
        expect(line('cover-drawing'), findsOneWidget);

        container
            .read(
              inferenceStatusControllerProvider((
                id: 'ice-pad',
                aiResponseType: AiResponseType.imageGeneration,
              )).notifier,
            )
            .setStatus(InferenceStatus.idle);
        await tester.pump();

        expect(line('cover-drawing'), findsNothing);
        expect(find.byType(StatusGlyph), findsOneWidget);
      });
    });

    group('a coding prompt', () {
      testWidgets('while it is written, the card says so', (tester) async {
        await pumpMade(tester, running: {AiResponseType.promptGeneration});

        expect(
          textIn(
            tester,
            line('prompt-writing'),
            'Writing the coding prompt…',
          ).style!.color,
          tokensOf(tester).colors.aiCard.accent,
        );
        expect(line('prompt'), findsNothing);
      });

      testWidgets('once written, its summary is on the card under its '
          'name, cut to three lines', (tester) async {
        await pumpMade(
          tester,
          prompt: 'Confirm the crosswind stays under limits.',
          // Still reported running for a moment after it is stored.
          running: {AiResponseType.promptGeneration},
        );

        expect(promptReads, ['ice-pad']);
        expect(
          find.descendant(
            of: line('prompt'),
            matching: find.text('AI Coding Prompt'),
          ),
          findsOneWidget,
        );
        final summary = textIn(
          tester,
          line('prompt'),
          'Confirm the crosswind stays under limits.',
        );
        expect(summary.maxLines, 3);
        expect(summary.overflow, TextOverflow.ellipsis);
        expect(line('prompt-writing'), findsNothing);
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: line('prompt'),
                  matching: find.byType(Icon),
                ),
              )
              .icon,
          LottiIcons.code,
        );
      });

      testWidgets('one that could not be written says so in the error ink', (
        tester,
      ) async {
        await pumpMade(tester, failed: {AiResponseType.promptGeneration});

        expect(
          textIn(
            tester,
            line('prompt-failed'),
            'The coding prompt could not be written',
          ).style!.color,
          tokensOf(tester).colors.alert.error.ink,
        );
      });

      testWidgets('a task no coding prompt was asked for says nothing of '
          'one being written or failing: a design or research prompt '
          'started on its page reports the same way', (tester) async {
        await pumpMade(
          tester,
          running: {AiResponseType.promptGeneration},
          promptRequested: false,
        );
        expect(line('prompt-writing'), findsNothing);
        expect(find.byType(DesignSystemDivider), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await pumpMade(
          tester,
          failed: {AiResponseType.promptGeneration},
          promptRequested: false,
        );
        expect(line('prompt-failed'), findsNothing);
      });

      testWidgets('a coding prompt that exists is shown whether or not one '
          'was asked for here', (tester) async {
        await pumpMade(
          tester,
          prompt: 'Confirm the crosswind limits.',
          promptRequested: false,
        );

        expect(line('prompt'), findsOneWidget);
      });

      testWidgets('its name is cut to the card on one line, never drawn '
          'past its edge', (tester) async {
        await pumpMade(tester, prompt: 'Confirm the crosswind limits.');

        final name = tester.widget<Text>(
          find.descendant(
            of: line('prompt'),
            matching: find.text('AI Coding Prompt'),
          ),
        );
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(
          find.ancestor(
            of: find.text('AI Coding Prompt'),
            matching: find.byType(Flexible),
          ),
          findsWidgets,
        );
      });

      testWidgets('a tap on its summary opens the task, where the full '
          'prompt is', (tester) async {
        await pumpMade(tester, prompt: 'Confirm the crosswind limits.');

        await tester.tap(find.text('Confirm the crosswind limits.'));

        expect(opened, [iceRef]);
      });
    });

    testWidgets('a cover being drawn and a prompt written share the part '
        'under the task, the cover first, under one rule', (tester) async {
      await pumpMade(
        tester,
        prompt: 'Confirm the crosswind limits.',
        running: {AiResponseType.imageGeneration},
      );

      expect(find.byType(DesignSystemDivider), findsOneWidget);
      expect(
        tester.getTopLeft(line('cover-drawing')).dy,
        lessThan(tester.getTopLeft(line('prompt')).dy),
      );
      // Under the task's own row, inside the one card.
      expect(
        tester.getTopLeft(line('cover-drawing')).dy,
        greaterThan(tester.getBottomLeft(find.text(ice().title)).dy),
      );
      expect(
        find.descendant(
          of: find.byKey(FrontEntityPreviewKeys.card('ice-pad')),
          matching: line('prompt'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a task she only lists shows none of it, and reads no '
        'prompt for it', (tester) async {
      await pumpMade(
        tester,
        prompt: 'Confirm the crosswind limits.',
        running: {AiResponseType.imageGeneration},
        showsGenerated: false,
      );

      expect(promptReads, isEmpty);
      expect(line('prompt'), findsNothing);
      expect(line('cover-drawing'), findsNothing);
      expect(
        find.byKey(FrontEntityPreviewKeys.coverDrawing('ice-pad')),
        findsNothing,
      );
      expect(find.byType(StatusGlyph), findsOneWidget);
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
          FrontEntityKind.project ||
          FrontEntityKind.person ||
          FrontEntityKind.dayPlan => null,
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

  group('a task card, priority', () {
    testWidgets("a task still to do shows its priority's glyph and name "
        'beside the chevron; a settled one neither', (tester) async {
      await pump(
        tester,
        references: const [iceRef, coldRef],
        load: (key) async => key.$2 == 'ice-pad'
            ? ice(priority: TaskPriority.p1High)
            : FrontTaskPreview(
                entityId: 'cold-chain',
                title: 'Audit the cold-chain freezer logs',
                status: TaskStatus.done(id: 's', createdAt: at, utcOffset: 0),
              ),
      );

      final priority = find.byKey(FrontEntityPreviewKeys.priority('ice-pad'));
      expect(
        tester
            .widget<TaskShowcasePriorityGlyph>(
              find.descendant(
                of: priority,
                matching: find.byType(TaskShowcasePriorityGlyph),
              ),
            )
            .priority,
        TaskPriority.p1High,
      );
      expect(
        find.descendant(of: priority, matching: find.text('P1')),
        findsOneWidget,
      );
      expect(
        find.byKey(FrontEntityPreviewKeys.priority('cold-chain')),
        findsNothing,
      );
      expect(
        item(tester, 'cold-chain').semanticsLabel,
        isNot(contains('P2')),
      );
    });

    testWidgets('on a narrow screen a one-liner long enough to be cut never '
        'takes the priority with it', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        load: (_) async =>
            ice(oneLiner: 'Crosswind ' * 40, priority: TaskPriority.p1High),
      );

      final card = tester.getRect(
        find.byKey(FrontEntityPreviewKeys.card('ice-pad')),
      );
      final priority = tester.getRect(
        find.byKey(FrontEntityPreviewKeys.priority('ice-pad')),
      );
      expect(
        card.contains(priority.topLeft) && card.contains(priority.bottomRight),
        isTrue,
      );
      expect(priority.right, lessThanOrEqualTo(320));
    });
  });

  group('a title-only card', () {
    const project = FrontEntityReference(
      kind: FrontEntityKind.project,
      id: 'p-1',
      title: 'Colony census',
    );

    testWidgets('a project is its title under the folder glyph, and opens', (
      tester,
    ) async {
      await pump(tester, references: const [project], load: (_) async => null);

      final card = find.byKey(FrontEntityPreviewKeys.card('p-1'));
      expect(
        find.descendant(of: card, matching: find.text('Colony census')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byIcon(LottiIcons.folder)),
        findsOneWidget,
      );

      await tester.tap(card);
      expect(opened, [project]);
    });

    testWidgets('leads with the glyph of its kind', (tester) async {
      final day = FrontEntityReference(
        kind: FrontEntityKind.dayPlan,
        id: frontDayPlanId(DateTime(2026, 11, 9)),
        title: 'Move the freezer audit',
      );
      await pump(
        tester,
        references: [iceRef, rehearsalRef, day],
        load: (_) async => null,
      );

      IconData glyphOf(String id) => tester
          .widget<Icon>(
            find
                .descendant(
                  of: find.byKey(FrontEntityPreviewKeys.card(id)),
                  matching: find.byType(Icon),
                )
                .first,
          )
          .icon!;
      expect(glyphOf('ice-pad'), LottiIcons.checkboxChecked);
      expect(glyphOf(rehearsalRef.id), LottiIcons.calendar);
      expect(glyphOf(day.id), LottiIcons.calendar);
    });
  });

  group('FrontEntityPreviewDayCard', () {
    final day = DateTime(2026, 11, 9);
    final dayRef = FrontEntityReference(
      kind: FrontEntityKind.dayPlan,
      id: frontDayPlanId(day),
      title: 'Move the freezer audit to the afternoon',
    );

    FrontPlanBlock block(
      String title,
      int startHour, {
      TimeBlockState state = TimeBlockState.committed,
    }) => FrontPlanBlock(
      title: title,
      start: DateTime(2026, 11, 9, startHour),
      end: DateTime(2026, 11, 9, startHour, 45),
      state: state,
    );

    String textOf(WidgetTester tester, Finder finder) =>
        tester.widgetList<Text>(finder).map((t) => t.data).join(' | ');

    testWidgets('says the day, then each block with when it runs, in order, '
        'a done one ticked', (tester) async {
      await pump(
        tester,
        references: [dayRef],
        load: (_) async => FrontDayPlanPreview(
          day: day,
          blocks: [
            block('Weather check', 9, state: TimeBlockState.completed),
            block('Freezer audit', 14),
          ],
        ),
      );

      expect(find.text('Mon, Nov 9'), findsOneWidget);
      final first = find.byKey(FrontEntityPreviewKeys.block(dayRef.id, 0));
      final second = find.byKey(FrontEntityPreviewKeys.block(dayRef.id, 1));
      expect(
        textOf(tester, find.descendant(of: first, matching: find.byType(Text))),
        '9:00 AM–9:45 AM | Weather check',
      );
      expect(
        textOf(
          tester,
          find.descendant(of: second, matching: find.byType(Text)),
        ),
        '2:00 PM–2:45 PM | Freezer audit',
      );
      expect(
        find.descendant(
          of: first,
          matching: find.byIcon(LottiIcons.confirmCircled),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: second,
          matching: find.byIcon(LottiIcons.confirmCircled),
        ),
        findsNothing,
      );
      expect(find.byKey(FrontEntityPreviewKeys.more(dayRef.id)), findsNothing);
      expect(find.text(dayRef.title), findsNothing);
    });

    testWidgets('lists at most five blocks and says how many more there are', (
      tester,
    ) async {
      await pump(
        tester,
        references: [dayRef],
        load: (_) async => FrontDayPlanPreview(
          day: day,
          blocks: [for (var h = 8; h < 15; h++) block('Block $h', h)],
        ),
      );

      expect(
        find.byKey(
          FrontEntityPreviewKeys.block(
            dayRef.id,
            FrontEntityPreviewDayCard.maxBlocks - 1,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          FrontEntityPreviewKeys.block(
            dayRef.id,
            FrontEntityPreviewDayCard.maxBlocks,
          ),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(find.byKey(FrontEntityPreviewKeys.more(dayRef.id)))
            .data,
        '2 more',
      );
    });

    testWidgets('a tap anywhere on it opens the day', (tester) async {
      await pump(
        tester,
        references: [dayRef],
        load: (_) async =>
            FrontDayPlanPreview(day: day, blocks: [block('Audit', 14)]),
      );

      await tester.tap(find.text('Audit'));
      expect(opened, [dayRef]);
    });

    testWidgets('a day with no plan, or a preview of another kind, is the '
        'words that changed it, still opening the day', (tester) async {
      await pump(
        tester,
        references: [dayRef],
        load: (_) async => ice(),
      );

      expect(find.text(dayRef.title), findsOneWidget);
      expect(
        find.byKey(FrontEntityPreviewKeys.block(dayRef.id, 0)),
        findsNothing,
      );

      await tester.tap(find.text(dayRef.title));
      expect(opened, [dayRef]);
    });

    testWidgets('stays on screen while the plan under it reloads, then '
        'changes in place', (tester) async {
      DraftPlan plan(String title) => DraftPlan(
        dayDate: day,
        blocks: [
          TimeBlock(
            id: 'b',
            title: title,
            start: DateTime(2026, 11, 9, 14),
            end: DateTime(2026, 11, 9, 15),
            type: TimeBlockType.ai,
            state: TimeBlockState.committed,
            category: const DayAgentCategory(
              id: 'launch',
              name: 'Launch Ops',
              colorHex: '3B82F6',
            ),
          ),
        ],
        bands: const <EnergyBand>[],
        capacityMinutes: 480,
        scheduledMinutes: 60,
      );
      var reload = Completer<DraftPlan?>()..complete(plan('Freezer audit'));
      await pump(
        tester,
        references: [dayRef],
        loadPlan: (_) => reload.future,
      );
      expect(find.text('Freezer audit'), findsOneWidget);

      reload = Completer<DraftPlan?>();
      ProviderScope.containerOf(
        tester.element(find.byType(FrontEntityPreviewList)),
      ).invalidate(currentDraftPlanProvider(day));
      await tester.pump();

      expect(find.text('Freezer audit'), findsOneWidget);
      expect(find.text(dayRef.title), findsNothing);

      reload.complete(plan('Freezer audit, moved'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Freezer audit, moved'), findsOneWidget);
    });
  });

  group('FrontDueSectionLabel', () {
    final today = DateTime(2026, 11, 9);
    final friday = DateTime(2026, 11, 13);

    for (final (window, through, label) in [
      (FrontDueWindow.today, today, 'Due today'),
      (FrontDueWindow.overdue, today, 'Overdue'),
      (FrontDueWindow.upcoming, today, 'Due today'),
      (FrontDueWindow.upcoming, friday, 'Due through Fri, Nov 13'),
      (FrontDueWindow.all, today, 'Overdue and due today'),
      (FrontDueWindow.all, friday, 'Overdue and due through Fri, Nov 13'),
    ]) {
      testWidgets('${window.name} through ${through.day} reads "$label"', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            FrontDueSectionLabel(
              section: FrontDueSection(
                window: window,
                today: today,
                through: through,
              ),
            ),
          ),
        );

        expect(find.text(label), findsOneWidget);
        final tokens = tester
            .element(find.byType(FrontDueSectionLabel))
            .designTokens;
        expect(
          tester.widget<Text>(find.text(label)).style?.color,
          tokens.colors.text.lowEmphasis,
        );
      });
    }
  });
  group('FrontEntityPreviewProjectCard', () {
    final census = makeTestProject(
      id: 'census',
      title: 'Colony census',
      categoryId: 'launch',
    );
    const censusRef = FrontEntityReference(
      kind: FrontEntityKind.project,
      id: 'census',
      title: 'Start the census (as said)',
    );

    testWidgets('a project is drawn as the Projects list draws it: its title, '
        'category and how many of its tasks are done; a tap opens it', (
      tester,
    ) async {
      await pump(
        tester,
        references: const [censusRef],
        category: launch,
        load: (_) async => FrontProjectPreview(
          project: census,
          totalTaskCount: 8,
          completedTaskCount: 3,
        ),
      );

      final row = tester.widget<ProjectRow>(find.byType(ProjectRow));
      expect(row.item.project, census);
      expect(row.item.category, launch);
      expect(row.item.taskRollup.totalTaskCount, 8);
      expect(row.item.taskRollup.completedTaskCount, 3);
      expect(row.selected, isFalse);
      expect(find.text('Colony census'), findsOneWidget);
      expect(find.text(censusRef.title), findsNothing);

      // Hovering it, as a row of the list would be, opens nothing.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(ProjectRow)));
      await tester.pump();
      expect(opened, isEmpty);

      await tester.tap(find.text('Colony census'));
      expect(opened, [censusRef]);
    });

    testWidgets('a project that is gone keeps its title, under the folder '
        'glyph, and still opens', (tester) async {
      await pump(
        tester,
        references: const [censusRef],
        load: (_) async => null,
      );

      expect(find.byType(ProjectRow), findsNothing);
      final card = find.byKey(FrontEntityPreviewKeys.card('census'));
      expect(
        find.descendant(of: card, matching: find.byIcon(LottiIcons.folder)),
        findsOneWidget,
      );
      await tester.tap(find.text(censusRef.title));
      expect(opened, [censusRef]);
    });
  });

  group('FrontEntityPreviewPersonCard', () {
    final anna = testRelationship.meta.id;
    final annaRef = FrontEntityReference(
      kind: FrontEntityKind.person,
      id: anna,
      title: 'Anna',
    );
    final call =
        JournalEntity.checkIn(
              meta: testRelationship.meta.copyWith(
                id: 'check-in',
                dateFrom: DateTime(2026, 11, 6, 18),
                dateTo: DateTime(2026, 11, 6, 18, 30),
              ),
              data: CheckInData(
                relationshipId: anna,
                interactionType: CheckInInteractionType.call,
              ),
            )
            as CheckInEntry;

    testWidgets('a person is drawn as the People list draws them, with their '
        'newest check-in; a tap opens them', (tester) async {
      await pump(
        tester,
        references: [annaRef],
        load: (_) async =>
            FrontPersonPreview(person: testRelationship, lastCheckIn: call),
      );

      final row = tester.widget<PeopleListRow>(find.byType(PeopleListRow));
      expect(row.item.relationship, testRelationship);
      expect(row.item.lastCheckIn, call);

      await tester.tap(find.byType(PeopleListRow));
      expect(opened, [annaRef]);
    });

    testWidgets('a person who is gone keeps their name, under the person '
        'glyph, and still opens', (tester) async {
      await pump(tester, references: [annaRef], load: (_) async => null);

      expect(find.byType(PeopleListRow), findsNothing);
      final card = find.byKey(FrontEntityPreviewKeys.card(anna));
      expect(
        find.descendant(of: card, matching: find.byIcon(LottiIcons.person)),
        findsOneWidget,
      );
      await tester.tap(find.text('Anna'));
      expect(opened, [annaRef]);
    });
  });

  group('a task card, quick actions', () {
    final stored = testTask.copyWith(
      meta: testTask.meta.copyWith(id: 'ice-pad', categoryId: 'launch'),
      data: testTask.data.copyWith(
        title: 'Check the ice-pad weather window',
        status: inProgress(),
        due: DateTime(2026, 11, 9, 17),
      ),
    );
    final census = makeTestProject(id: 'census', categoryId: 'launch');
    late MockProjectRepository projects;

    Future<void> pumpActions(
      WidgetTester tester, {
      String? categoryId = 'launch',
      Task? task,
    }) async {
      projects = MockProjectRepository();
      when(
        () => projects.getProjectForTask('ice-pad'),
      ).thenAnswer((_) async => census);
      await pump(
        tester,
        load: (_) async => ice(categoryId: categoryId),
        loadTask: (_) async => task == null ? null : TaskPreview(task: task),
        extra: [
          createEntryControllerOverride(stored),
          projectRepositoryProvider.overrideWithValue(projects),
          projectsForCategoryProvider.overrideWith(
            (ref, categoryId) async => [census],
          ),
        ],
      );
      // The pickers write through the task's entry controller.
      getIt
        ..registerSingleton<EditorStateService>(MockEditorStateService())
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        // The project picker can lead on to a new project's page.
        ..registerSingleton<NavService>(MockNavService());
    }

    Finder action(String name) =>
        find.byKey(FrontEntityPreviewKeys.action('ice-pad', name));

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> longPress(WidgetTester tester) async {
      await tester.longPress(
        find.byKey(FrontEntityPreviewKeys.card('ice-pad')),
      );
      await settle(tester);
    }

    testWidgets('a long press offers changing its status, rescheduling it '
        'and moving it to a project — and opens nothing', (tester) async {
      await pumpActions(tester, task: stored);

      await longPress(tester);

      expect(find.text('Change status…'), findsOneWidget);
      expect(find.text('Reschedule…'), findsOneWidget);
      expect(find.text('Move to project…'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('a secondary click offers them too', (tester) async {
      await pumpActions(tester, task: stored);

      await tester.tap(
        find.byKey(FrontEntityPreviewKeys.card('ice-pad')),
        buttons: kSecondaryButton,
      );
      await settle(tester);

      expect(action('status'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('a screen reader reaches them by the long-press action', (
      tester,
    ) async {
      await pumpActions(tester, task: stored);

      final handle = tester.ensureSemantics();
      tester.semantics.performAction(
        find.semantics.byAction(SemanticsAction.longPress).first,
        SemanticsAction.longPress,
      );
      await settle(tester);

      expect(action('due'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a task with no category has nowhere to move to', (
      tester,
    ) async {
      await pumpActions(tester, task: stored, categoryId: null);

      await longPress(tester);

      expect(action('status'), findsOneWidget);
      expect(action('due'), findsOneWidget);
      expect(action('project'), findsNothing);
    });

    testWidgets('changing its status opens the status picker its page opens, '
        'on the task as stored now', (tester) async {
      await pumpActions(tester, task: stored);

      await longPress(tester);
      await tester.tap(action('status'));
      await settle(tester);

      expect(
        tester
            .widget<TaskStatusModalContent>(
              find.byType(TaskStatusModalContent),
            )
            .task,
        stored,
      );
    });

    testWidgets('rescheduling opens the due date picker its page opens', (
      tester,
    ) async {
      await pumpActions(tester, task: stored);

      await longPress(tester);
      await tester.tap(action('due'));
      await settle(tester);

      expect(find.text('Due Date'), findsOneWidget);
    });

    testWidgets('moving it opens the project picker its page opens, in the '
        "task's category, with its project now chosen", (tester) async {
      await pumpActions(tester, task: stored);

      await longPress(tester);
      await tester.tap(action('project'));
      await settle(tester);

      final picker = tester.widget<ProjectSelectionModalContent>(
        find.byType(ProjectSelectionModalContent),
      );
      expect(picker.categoryId, 'launch');
      expect(picker.currentProjectId, 'census');
      expect(picker.taskIsPrivate, isFalse);
      verify(() => projects.getProjectForTask('ice-pad')).called(1);
    });

    testWidgets('a task gone by the time an action is chosen opens nothing', (
      tester,
    ) async {
      await pumpActions(tester);

      await longPress(tester);
      await tester.tap(action('status'));
      await settle(tester);

      expect(find.byType(TaskStatusModalContent), findsNothing);
    });
  });
}
