import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJournalPageController fakeController;

  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<UserActivityService>(UserActivityService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  JournalPageState state() => const JournalPageState(
    showTasks: true,
    taskStatuses: ['OPEN'],
    selectedTaskStatuses: {'OPEN'},
    selectedEntryTypes: ['Task'],
  );

  Widget buildSubject({required bool enabled}) {
    fakeController = FakeJournalPageController(state());

    return makeTestableWidgetNoScroll(
      const TasksRootPage(),
      overrides: [
        configFlagProvider(enableTasksRedesignFlag).overrideWith(
          (ref) => Stream.value(enabled),
        ),
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
      ],
    );
  }

  testWidgets('shows legacy infinite journal page when flag is off', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(enabled: false));
    await tester.pump();

    expect(find.byType(InfiniteJournalPage), findsOneWidget);
    expect(find.byType(TasksTabPage), findsNothing);
  });

  testWidgets('shows new tasks tab page when flag is on', (tester) async {
    await tester.pumpWidget(buildSubject(enabled: true));
    await tester.pump();

    expect(find.byType(TasksTabPage), findsOneWidget);
    expect(find.byType(InfiniteJournalPage), findsNothing);
  });
}
