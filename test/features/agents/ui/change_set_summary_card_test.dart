import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockChangeSetConfirmationService mockConfirmationService;
  late MockUpdateNotifications mockUpdateNotifications;

  const taskId = 'task-001';

  setUp(() async {
    mockConfirmationService = MockChangeSetConfirmationService();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.notify(any())).thenReturn(null);

    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  Widget buildWidget({
    List<AgentDomainEntity> changeSets = const [],
  }) {
    return ProviderScope(
      overrides: [
        pendingChangeSetsProvider(taskId).overrideWith(
          (ref) async => changeSets,
        ),
        changeSetConfirmationServiceProvider
            .overrideWithValue(mockConfirmationService),
        updateNotificationsProvider.overrideWithValue(mockUpdateNotifications),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeSetSummaryCard(taskId: taskId),
          ),
        ),
      ),
    );
  }

  group('ChangeSetSummaryCard', () {
    testWidgets('renders nothing when change sets list is empty',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ChangeSetSummaryCard), findsOneWidget);
      // Should render SizedBox.shrink when no change sets.
      expect(find.text('Proposed changes'), findsNothing);
    });

    testWidgets('renders card with title and item summaries', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'New Title'},
            humanSummary: 'Set title to "New Title"',
          ),
        ],
      );

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Proposed changes'), findsOneWidget);
      expect(find.text('Set estimate to 2 hours'), findsOneWidget);
      expect(find.text('Set title to "New Title"'), findsOneWidget);
      expect(find.text('2 pending'), findsOneWidget);
    });

    testWidgets('confirm button calls confirmItem', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: 'Done',
        ),
      );

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      // Tap the confirm icon button (check_circle_outline).
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      verify(
        () => mockConfirmationService.confirmItem(changeSet, 0),
      ).called(1);
    });

    testWidgets('reject button calls rejectItem', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
        ],
      );

      when(
        () => mockConfirmationService.rejectItem(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      // Tap the reject icon button (cancel_outlined).
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pumpAndSettle();

      verify(
        () => mockConfirmationService.rejectItem(changeSet, 0),
      ).called(1);
    });

    testWidgets('Confirm All button confirms all pending items',
        (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'New'},
            humanSummary: 'Set title',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmAll(any()),
      ).thenAnswer(
        (_) async => [
          const ToolExecutionResult(success: true, output: 'Done'),
          const ToolExecutionResult(success: true, output: 'Done'),
        ],
      );

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm all'));
      await tester.pumpAndSettle();

      verify(
        () => mockConfirmationService.confirmAll(changeSet),
      ).called(1);
    });

    testWidgets('resolved items show status icon', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Confirmed item',
            status: ChangeItemStatus.confirmed,
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Rejected'},
            humanSummary: 'Rejected item',
            status: ChangeItemStatus.rejected,
          ),
        ],
        status: ChangeSetStatus.resolved,
      );

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      // Both resolved items should show, with strikethrough style.
      expect(find.text('Confirmed item'), findsOneWidget);
      expect(find.text('Rejected item'), findsOneWidget);

      // Check icons: check_circle for confirmed, cancel for rejected.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // No pending count badge when all resolved (pendingCount == 0).
      expect(find.text('0 pending'), findsNothing);

      // Confirm All button should not appear (no pending items).
      expect(find.text('Confirm all'), findsNothing);
    });

    testWidgets('shows error snackbar when confirm fails', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenThrow(Exception('Test error'));

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('shows error snackbar when confirm returns failure result',
        (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will fail silently',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: false,
          output: 'Task not found',
          errorMessage: 'Task lookup failed',
        ),
      );

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('shows error snackbar when reject fails', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Reject will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.rejectItem(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(Exception('Reject error'));

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('swipe right triggers confirm', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Swipe to confirm',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: 'Done',
        ),
      );

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      // Swipe right (startToEnd) on the item tile.
      await tester.drag(
        find.text('Swipe to confirm'),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockConfirmationService.confirmItem(changeSet, 0),
      ).called(1);
    });

    testWidgets('swipe left triggers reject', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Swipe to reject',
          ),
        ],
      );

      when(
        () => mockConfirmationService.rejectItem(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      // Swipe left (endToStart) on the item tile.
      await tester.drag(
        find.text('Swipe to reject'),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockConfirmationService.rejectItem(changeSet, 0),
      ).called(1);
    });

    testWidgets('Confirm All shows error snackbar on partial failure',
        (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will succeed',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fail'},
            humanSummary: 'Will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmAll(any()),
      ).thenAnswer(
        (_) async => [
          const ToolExecutionResult(success: true, output: 'Done'),
          const ToolExecutionResult(
            success: false,
            output: 'Task not found',
            errorMessage: 'Failed',
          ),
        ],
      );

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm all'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsOneWidget);
      verify(
        () => mockConfirmationService.confirmAll(changeSet),
      ).called(1);
    });

    testWidgets('Confirm All error shows snackbar', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmAll(any()),
      ).thenThrow(Exception('Confirm all failed'));

      await tester.pumpWidget(
        buildWidget(changeSets: [changeSet]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm all'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsOneWidget);
    });
  });
}
