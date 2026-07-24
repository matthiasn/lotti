import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_relationship_sections.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
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

      expect(find.text('Blocked by'), findsNothing);
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

        expect(find.text('Blocked by'), findsOneWidget);
        expect(find.text('Blocks'), findsOneWidget);
        expect(find.text('Blocker Task'), findsOneWidget);
        expect(find.text('Blocked Task'), findsOneWidget);
        // Split sections carry no per-row direction caption/glyph.
        expect(find.text('Is blocked by'), findsNothing);
      },
    );

    testWidgets(
      'renders a merged Follow-ups section with per-row phrase captions',
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

        expect(find.text('Follow-ups'), findsOneWidget);
        expect(find.text('Follows up on'), findsOneWidget);
        expect(find.text('Has follow-up'), findsOneWidget);
      },
    );

    testWidgets(
      'orders sections Blocked by, Blocks, Follow-ups, Duplicates, Fixes, '
      'Supersedes',
      (tester) async {
        await pumpSections(
          tester,
          TaskLinkGroups(
            flat: const [],
            typed: [
              entry(
                // Incoming direction, so its row caption reads the inverse
                // phrase ("Is superseded by") rather than "Supersedes" —
                // avoiding a text collision with this section's own header
                // in the assertion below.
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
                // Incoming direction for the same reason ("Is fixed by" vs.
                // the "Fixes" section header).
                id: 'fixes-1',
                title: 'Fixes entry',
                kind: TaskLinkKind.fixes,
                direction: TaskLinkDirection.incoming,
              ),
            ],
          ),
        );

        final headers = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where(
              (text) => [
                'Blocked by',
                'Blocks',
                'Follow-ups',
                'Duplicates',
                'Fixes',
                'Supersedes',
              ].contains(text),
            )
            .toList();

        expect(headers, ['Blocked by', 'Fixes', 'Supersedes']);
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
      await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
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
      await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
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
  });
}
