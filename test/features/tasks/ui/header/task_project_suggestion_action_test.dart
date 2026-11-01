import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/tasks/state/task_project_suggestion_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_project_suggestion_action.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _taskId = 'task-1';
const TaskProjectSuggestion _work = (projectId: 'work', projectTitle: 'Work');

void main() {
  late MockProjectRepository repository;
  late TestGetItMocks mocks;

  setUp(() async {
    repository = MockProjectRepository();
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpAction(
    WidgetTester tester, {
    TaskProjectSuggestion? suggestion = _work,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const TaskProjectSuggestionAction(taskId: _taskId),
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          taskProjectSuggestionProvider(
            _taskId,
          ).overrideWith((ref) async => suggestion),
        ],
      ),
    );
    await tester.pump();
  }

  Finder offer() => find.text('Add to Work?');
  Finder dismissControl() => find.byTooltip('Not this project');

  void stubLink(Future<bool> Function() answer) {
    when(
      () => repository.linkUnassignedTaskToProject(
        projectId: any(named: 'projectId'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) => answer());
  }

  testWidgets('offers the suggested project by name, with a dismiss control '
      'and a screen-reader label that says what the tap does', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpAction(tester);

      expect(offer(), findsOneWidget);
      expect(dismissControl(), findsOneWidget);
      expect(
        find.bySemanticsLabel('Suggested project: Work. Add this task to it'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the dismiss control sits right after the label, however wide '
      'the crumb is', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox(
          width: 800,
          child: Row(
            children: [
              Flexible(child: TaskProjectSuggestionAction(taskId: _taskId)),
            ],
          ),
        ),
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          taskProjectSuggestionProvider(
            _taskId,
          ).overrideWith((ref) async => _work),
        ],
      ),
    );
    await tester.pump();

    // The inline action would otherwise align itself across all 800 px and
    // leave the ✕ stranded at the far end, detached from what it dismisses.
    final labelEnd = tester.getTopRight(offer()).dx;
    final dismissStart = tester.getTopLeft(dismissControl()).dx;
    expect(dismissStart - labelEnd, lessThan(48));
    expect(tester.getTopRight(dismissControl()).dx, lessThan(400));
  });

  testWidgets('renders nothing when there is no suggestion', (tester) async {
    await pumpAction(tester, suggestion: null);

    expect(find.textContaining('Add to'), findsNothing);
    expect(dismissControl(), findsNothing);
  });

  testWidgets('one tap on the offer files the task under the project, and the '
      'offer leaves at once — before the write lands', (tester) async {
    final write = Completer<bool>();
    stubLink(() => write.future);
    await pumpAction(tester);

    await tester.tap(offer());
    await tester.pump();

    verify(
      () => repository.linkUnassignedTaskToProject(
        projectId: 'work',
        taskId: _taskId,
      ),
    ).called(1);
    expect(offer(), findsNothing);

    write.complete(true);
    await tester.pump();
    expect(offer(), findsNothing);
    expect(find.byType(DesignSystemToast), findsNothing);
  });

  for (final (name, answer) in <(String, Future<bool> Function())>[
    ('refuses the link', () async => false),
    ('throws', () => Future<bool>.error(StateError('db closed'))),
  ]) {
    testWidgets('when the repository $name, an error toast explains it and '
        'the offer comes back', (tester) async {
      stubLink(answer);
      await pumpAction(tester);

      await tester.tap(offer());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.error);
      expect(
        toast.title,
        "Could not change this task's project. Check its category and "
        'privacy, then try again.',
      );
      expect(offer(), findsOneWidget);
    });
  }

  testWidgets('dismissing hides the offer and remembers the project for this '
      'task', (tester) async {
    await pumpAction(tester);

    await tester.tap(dismissControl());
    await tester.pump();

    expect(offer(), findsNothing);
    verifyNever(
      () => repository.linkUnassignedTaskToProject(
        projectId: any(named: 'projectId'),
        taskId: any(named: 'taskId'),
      ),
    );
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        taskProjectSuggestionDismissedKey(_taskId),
        '["work"]',
      ),
    ).called(1);
  });
}
