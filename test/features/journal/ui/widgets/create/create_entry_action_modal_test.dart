import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

/// Resolves the host id to a Task so the sheet's task-host rows render.
class _TaskEntryController extends EntryController {
  _TaskEntryController(this._task);

  final Task _task;

  @override
  Future<EntryState?> build() async {
    return EntryState.saved(
      entryId: id,
      entry: _task,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

void main() {
  group('CreateEntryModal', () {
    late MockNavService mockNavService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockJournalDb mockDb;

    setUp(() {
      mockNavService = MockNavService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockDb = MockJournalDb();

      // Mock watchConfigFlags to return enableEventsFlag: true
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      getIt
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<JournalDb>(mockDb);
    });

    tearDown(getIt.reset);

    /// Pumps a host button wired to CreateEntryModal.show and opens the
    /// modal (bottom-sheet route — the settle after the tap is required).
    Future<void> pumpAndOpenModal(
      WidgetTester tester, {
      String? linkedFromId = 'test-linked-id',
      String? categoryId = 'test-category-id',
      List<Override> extraOverrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            ...extraOverrides,
          ],
          child: makeTestableWidget2(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: linkedFromId,
                    categoryId: categoryId,
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows modal with all menu items when events enabled', (
      tester,
    ) async {
      await pumpAndOpenModal(tester);

      // "All" means all: with events enabled and a linked id, the five
      // core items must each be present exactly once (screenshot items are
      // platform-conditional and intentionally not pinned here).
      final context = tester.element(
        find.byType(DsActionRow).first,
      );
      final messages = AppLocalizations.of(context)!;
      for (final label in [
        messages.addActionAddEvent,
        messages.addActionCreateLinkedTask,
        messages.taskFirstRunRecordAudio,
        messages.addActionStartTimer,
        messages.taskFirstRunWriteNote,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets(
      'the sheet draws no rules at all — the rows separate themselves',
      (tester) async {
        await pumpAndOpenModal(tester);

        final rows = find.byType(DsActionRow);
        expect(rows.evaluate().length, greaterThan(1));
        // Rounded hover targets replaced the hairlines: a rule through a
        // rounded highlight is the reason the sheet used to need a whole
        // hover-index mechanism to fade the pair bracketing the pointer.
        expect(find.byType(DesignSystemDivider), findsNothing);
        expect(
          find.descendant(of: rows.first, matching: find.byType(Divider)),
          findsNothing,
        );
      },
    );

    testWidgets('every row is an accent-tone create row with a description', (
      tester,
    ) async {
      await pumpAndOpenModal(tester);

      final rows = tester.widgetList<DsActionRow>(find.byType(DsActionRow));
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(
          row.tone,
          DsActionRowTone.accent,
          reason: '${row.title} must read as a create, not an entry action',
        );
        expect(
          row.subtitle,
          isNotNull,
          reason: '${row.title} must say what the tap does',
        );
        expect(
          row.trailing,
          isNot(DsActionRowTrailing.none),
          reason: '${row.title} must report whether it creates or opens',
        );
      }
    });

    testWidgets('shows Timer item when linkedFromId is provided', (
      tester,
    ) async {
      await pumpAndOpenModal(tester);

      // Verify Timer item is present (timer icon)
      expect(find.byIcon(LottiIcons.timer), findsOneWidget);
    });

    testWidgets(
      'a TASK host adds the checklist row and drops the Timer row — the '
      "bar's Track time pill is that same action",
      (tester) async {
        final now = DateTime(2026, 8, 4);
        final hostTask = Task(
          meta: Metadata(
            id: 'host-task',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            title: 'Host',
            status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
            dateFrom: now,
            dateTo: now,
            statusHistory: const [],
          ),
        );
        // The overridden controller still runs EntryController's field
        // initializers, which resolve these from getIt.
        getIt.registerSingleton<EditorStateService>(MockEditorStateService());
        final updates = MockUpdateNotifications();
        when(
          () => updates.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        getIt.registerSingleton<UpdateNotifications>(updates);

        await pumpAndOpenModal(
          tester,
          linkedFromId: 'host-task',
          extraOverrides: [
            entryControllerProvider(
              'host-task',
            ).overrideWith(() => _TaskEntryController(hostTask)),
          ],
        );

        final context = tester.element(
          find.byType(DsActionRow).first,
        );
        final messages = AppLocalizations.of(context)!;
        expect(
          find.text(messages.taskFirstRunAddChecklist),
          findsOneWidget,
        );
        expect(find.byIcon(LottiIcons.timer), findsNothing);
      },
    );

    testWidgets('hides Timer item when linkedFromId is null', (tester) async {
      await pumpAndOpenModal(tester, linkedFromId: null);

      // Verify Timer item is NOT present
      expect(find.byIcon(LottiIcons.timer), findsNothing);
    });

    testWidgets('hides Event item when enableEventsFlag is false', (
      tester,
    ) async {
      // Override to disable events
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: false,
            ),
          },
        ]),
      );

      await pumpAndOpenModal(tester, linkedFromId: null);

      // Verify Event item is NOT present
      expect(find.byIcon(LottiIcons.calendar), findsNothing);
    });

    testWidgets(
      'hides the Event row while the flag is still loading — an unresolved '
      'flag is not permission',
      (tester) async {
        final flagController = StreamController<Set<ConfigFlag>>();
        when(
          () => mockDb.watchConfigFlags(),
        ).thenAnswer((_) => flagController.stream);

        await pumpAndOpenModal(tester, linkedFromId: null);

        expect(find.byIcon(LottiIcons.calendar), findsNothing);

        await flagController.close();
      },
    );

    testWidgets('hides the Event row when the flag stream errors', (
      tester,
    ) async {
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.error(Exception('flag backend down')),
      );

      await pumpAndOpenModal(tester, linkedFromId: null);

      expect(find.byIcon(LottiIcons.calendar), findsNothing);
    });

    testWidgets(
      'offers the Paste row only when the clipboard actually holds an image '
      '— resolved before the list is assembled, so no orphan divider',
      (tester) async {
        // Default clipboard (empty) — no row.
        await pumpAndOpenModal(tester);
        expect(find.byIcon(LottiIcons.copy), findsNothing);

        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();

        // Clipboard holds an image — the row appears.
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpAndOpenModal(
          tester,
          extraOverrides: [
            imagePasteControllerProvider((
              linkedFromId: 'test-linked-id',
              categoryId: 'test-category-id',
            )).overrideWithBuild((ref, notifier) async => true),
          ],
        );
        expect(find.byIcon(LottiIcons.copy), findsOneWidget);
      },
    );

    testWidgets('displays correct icons for all standard menu items', (
      tester,
    ) async {
      await pumpAndOpenModal(
        tester,
        linkedFromId: 'test-id',
        categoryId: 'test-category',
      );

      // Verify core icons are present
      expect(find.byIcon(LottiIcons.calendar), findsOneWidget);
      expect(find.byIcon(LottiIcons.addTask), findsOneWidget);
      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
      expect(find.byIcon(LottiIcons.timer), findsOneWidget);
      expect(find.byIcon(LottiIcons.note), findsOneWidget);
    });
  });
}
