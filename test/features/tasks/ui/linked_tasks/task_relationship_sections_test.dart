import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_relationship_sections.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

class _FakeTaskLinkGroupsController extends TaskLinkGroupsController {
  _FakeTaskLinkGroupsController(this._groups);
  final TaskLinkGroups _groups;

  @override
  Future<TaskLinkGroups> build() async => _groups;
}

void main() {
  const anchorTaskId = 'anchor-task';

  setUp(() {
    registerAllFallbackValues();
    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await getIt.reset();
  });

  TaskLinkEntry entry({
    required String id,
    required String title,
    required TaskLinkKind kind,
    required TaskLinkDirection direction,
  }) => TaskLinkEntry(
    linkId: 'link-$id',
    task: TestTaskFactory.create(id: id, title: title),
    kind: kind,
    direction: direction,
  );

  Future<MockJournalRepository> pumpSections(
    WidgetTester tester,
    TaskLinkGroups groups, {
    bool manageMode = false,
  }) async {
    final journalRepo = MockJournalRepository();
    when(
      () => journalRepo.removeTypedLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
        linkType: any(named: 'linkType'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => journalRepo.updateLinkType(
        linkId: any(named: 'linkId'),
        newType: any(named: 'newType'),
        swapDirection: any(named: 'swapDirection'),
      ),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskLinkGroupsControllerProvider(
            anchorTaskId,
          ).overrideWith(() => _FakeTaskLinkGroupsController(groups)),
          journalRepositoryProvider.overrideWithValue(journalRepo),
        ],
        child: WidgetTestBench(
          child: TaskRelationshipSections(
            taskId: anchorTaskId,
            manageMode: manageMode,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return journalRepo;
  }

  group('TaskRelationshipSections', () {
    testWidgets('renders nothing when there are no typed relationships', (
      tester,
    ) async {
      await pumpSections(tester, TaskLinkGroups.empty);

      expect(find.text('Is blocked by'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets(
      'renders split Blocked-by/Blocks sections with no per-row caption',
      (tester) async {
        await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                id: 'blocker',
                title: 'Blocker Task',
                kind: TaskLinkKind.blocks,
                direction: TaskLinkDirection.incoming,
              ),
              entry(
                id: 'blocked',
                title: 'Blocked Task',
                kind: TaskLinkKind.blocks,
                direction: TaskLinkDirection.outgoing,
              ),
            ],
          ),
        );

        // Each direction is its own section, titled with the very phrase the
        // picker offers for it.
        expect(find.text('Is blocked by'), findsOneWidget);
        expect(find.text('Blocks'), findsOneWidget);
        expect(find.text('Blocker Task'), findsOneWidget);
        expect(find.text('Blocked Task'), findsOneWidget);
      },
    );

    testWidgets(
      'splits a bidirectional kind into one section per direction, each '
      'titled with that direction own phrase',
      (tester) async {
        await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                id: 'followup-out',
                title: 'Outgoing Follow-up',
                kind: TaskLinkKind.followsUp,
                direction: TaskLinkDirection.outgoing,
              ),
              entry(
                id: 'followup-in',
                title: 'Incoming Follow-up',
                kind: TaskLinkKind.followsUp,
                direction: TaskLinkDirection.incoming,
              ),
            ],
          ),
        );

        // Two direction-specific headers, not one merged "Follow-ups" group.
        expect(find.text('Follows up on'), findsOneWidget);
        expect(find.text('Has follow-up'), findsOneWidget);
        expect(find.text('Follow-ups'), findsNothing);
        // Each row sits under its own header, so no row repeats the phrase.
        expect(find.text('Outgoing Follow-up'), findsOneWidget);
        expect(find.text('Incoming Follow-up'), findsOneWidget);
      },
    );

    testWidgets(
      'orders sections Blocked by first, then by kind and direction, '
      'skipping every empty one',
      (tester) async {
        await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                id: 'supersedes-1',
                title: 'Supersedes entry',
                kind: TaskLinkKind.supersedes,
                direction: TaskLinkDirection.incoming,
              ),
              entry(
                id: 'blockedby-1',
                title: 'Blocked-by entry',
                kind: TaskLinkKind.blocks,
                direction: TaskLinkDirection.incoming,
              ),
              entry(
                id: 'fixes-1',
                title: 'Fixes entry',
                kind: TaskLinkKind.fixes,
                direction: TaskLinkDirection.incoming,
              ),
            ],
          ),
        );

        const allHeaders = [
          'Blocks',
          'Is blocked by',
          'Follows up on',
          'Has follow-up',
          'Duplicates',
          'Is duplicated by',
          'Fixes',
          'Is fixed by',
          'Supersedes',
          'Is superseded by',
        ];
        final headers = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where(allHeaders.contains)
            .toList();

        // Blocked-by leads; the two incoming entries render their inverse
        // phrases; the outgoing counterpart sections stay absent.
        expect(headers, ['Is blocked by', 'Is fixed by', 'Is superseded by']);
      },
    );

    testWidgets(
      'accents only the Blocked-by header, leaving every other section and '
      'row neutral',
      (tester) async {
        await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                id: 'blocker',
                title: 'Blocker Task',
                kind: TaskLinkKind.blocks,
                direction: TaskLinkDirection.incoming,
              ),
              entry(
                id: 'blocked',
                title: 'Blocked Task',
                kind: TaskLinkKind.blocks,
                direction: TaskLinkDirection.outgoing,
              ),
            ],
          ),
        );

        final headers = tester
            .widgetList<LinkedTaskSectionHeader>(
              find.byType(LinkedTaskSectionHeader),
            )
            .toList();
        final blockedBy = headers.firstWhere((h) => h.title == 'Is blocked by');
        final blocks = headers.firstWhere((h) => h.title == 'Blocks');

        expect(blockedBy.accent, isNotNull);
        expect(blocks.accent, isNull);
        // The accent brings a leading glyph tying the section to the header
        // chip; it is the only one on the card.
        expect(find.byIcon(Icons.block), findsOneWidget);
      },
    );

    testWidgets('unlinking a typed row calls removeTypedLink with its own '
        'db type string', (tester) async {
      final repo = await pumpSections(
        tester,
        TaskLinkGroups(
          flat: const [],
          typed: [
            entry(
              id: 'blocker',
              title: 'Blocker Task',
              kind: TaskLinkKind.blocks,
              direction: TaskLinkDirection.incoming,
            ),
          ],
        ),
        manageMode: true,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(DesignSystemButton, 'UNLINK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => repo.removeTypedLink(
          fromId: 'blocker',
          toId: anchorTaskId,
          linkType: 'BlocksLink',
        ),
      ).called(1);
    });

    testWidgets('unlinking an outgoing row uses the anchor task as fromId', (
      tester,
    ) async {
      final repo = await pumpSections(
        tester,
        TaskLinkGroups(
          flat: const [],
          typed: [
            entry(
              id: 'blocked',
              title: 'Blocked Task',
              kind: TaskLinkKind.blocks,
              direction: TaskLinkDirection.outgoing,
            ),
          ],
        ),
        manageMode: true,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(DesignSystemButton, 'UNLINK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => repo.removeTypedLink(
          fromId: anchorTaskId,
          toId: 'blocked',
          linkType: 'BlocksLink',
        ),
      ).called(1);
    });

    testWidgets(
      'editing an incoming row opens the modal pre-selected to its type and '
      'direction, and Save persists it unchanged (identity round-trip)',
      (tester) async {
        final repo = await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                id: 'blocker',
                title: 'Blocker Task',
                kind: TaskLinkKind.blocks,
                direction: TaskLinkDirection.incoming,
              ),
            ],
          ),
          manageMode: true,
        );

        await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Edit relationship'), findsOneWidget);

        await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => repo.updateLinkType(
            linkId: 'link-blocker',
            newType: EntryLinkType.blocks,
            swapDirection: false,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'editing an outgoing row also round-trips unchanged through Save',
      (tester) async {
        final repo = await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                id: 'blocked',
                title: 'Blocked Task',
                kind: TaskLinkKind.blocks,
                direction: TaskLinkDirection.outgoing,
              ),
            ],
          ),
          manageMode: true,
        );

        await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => repo.updateLinkType(
            linkId: 'link-blocked',
            newType: EntryLinkType.blocks,
            swapDirection: false,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'changing the type before Save persists the newly selected type',
      (tester) async {
        final repo = await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                id: 'followup',
                title: 'Follow-up Task',
                kind: TaskLinkKind.followsUp,
                direction: TaskLinkDirection.outgoing,
              ),
            ],
          ),
          manageMode: true,
        );

        await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch the relation from "Follows up on" to "Blocks" before saving.
        final dropdown = tester.widget<DesignSystemDropdown>(
          find.byType(DesignSystemDropdown),
        );
        dropdown.onItemPressed!(
          dropdown.items.firstWhere((item) => item.label == 'Blocks'),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => repo.updateLinkType(
            linkId: 'link-followup',
            newType: EntryLinkType.blocks,
            swapDirection: false,
          ),
        ).called(1);
      },
    );
  });
}
