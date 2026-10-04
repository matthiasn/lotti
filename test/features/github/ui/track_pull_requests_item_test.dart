import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/track_pull_requests_item.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  const taskId = 'task-1';
  late MockPullRequestRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockPullRequestRepository();
    container = ProviderContainer(
      overrides: [pullRequestRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // The page keeps the intent alive; here a listener stands in for it.
    container.listen(taskFocusControllerProvider(taskId), (_, _) {});
  });

  /// Opens a sheet holding the row, as the Add sheet does.
  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidget2(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const TrackPullRequestsItem(taskId),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'turns tracking on, closes the sheet and asks the page to scroll to the '
    'new section',
    (tester) async {
      when(() => repository.track(taskId)).thenAnswer((_) async => true);
      await pumpSheet(tester);

      expect(find.text('Pull request tracking'), findsOneWidget);
      expect(
        find.text(
          'Adds a section for the pull requests that implement this task.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(TrackPullRequestsItem));
      await tester.pumpAndSettle();

      verify(() => repository.track(taskId)).called(1);
      expect(find.byType(TrackPullRequestsItem), findsNothing);
      final intent = container.read(taskFocusControllerProvider(taskId));
      expect(intent?.target, TaskFocusTarget.pullRequests);
      expect(intent?.taskId, taskId);
    },
  );

  testWidgets('asks for no scroll when tracking could not be turned on', (
    tester,
  ) async {
    when(() => repository.track(taskId)).thenAnswer((_) async => false);
    await pumpSheet(tester);

    await tester.tap(find.byType(TrackPullRequestsItem));
    await tester.pumpAndSettle();

    expect(find.byType(TrackPullRequestsItem), findsNothing);
    expect(container.read(taskFocusControllerProvider(taskId)), isNull);
  });
}
