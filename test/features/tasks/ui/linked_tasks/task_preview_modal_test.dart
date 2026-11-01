import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_preview_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _taskId = 'census';

TaskPreview _preview({String notes = '', String? oneLiner, String? tldr}) =>
    TaskPreview(
      task: TestTaskFactory.create(
        id: _taskId,
        title: 'Colony census export',
        plainText: notes,
      ),
      oneLiner: oneLiner,
      tldr: tldr,
    );

void main() {
  late MockNavService nav;

  setUp(() async {
    nav = MockNavService();
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<NavService>(nav),
    );
  });
  tearDown(tearDownTestGetIt);

  /// Opens the preview from a button, as a host does, with the preview
  /// answered by [preview].
  Future<void> open(
    WidgetTester tester,
    Future<TaskPreview?> Function() preview,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTaskPreviewModal(context: context, taskId: _taskId),
              child: const Text('open'),
            ),
          ),
        ),
        mediaQueryData: desktopLayoutMediaQueryData,
        overrides: [
          taskPreviewProvider(_taskId).overrideWith((ref) => preview()),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets("shows the title, the agent's one-liner and its TL;DR", (
    tester,
  ) async {
    await open(
      tester,
      () async => _preview(
        notes: 'The notes, which the TL;DR replaces.',
        oneLiner: 'Waiting on the radio relay',
        tldr: 'Counted **37** penguins.',
      ),
    );

    expect(find.text('Colony census export'), findsOneWidget);
    expect(find.text('Waiting on the radio relay'), findsOneWidget);
    expect(find.textContaining('penguins', findRichText: true), findsWidgets);
    expect(find.textContaining('The notes'), findsNothing);
    expect(find.text('No summary yet.'), findsNothing);
  });

  testWidgets('without a TL;DR, shows the task notes instead', (
    tester,
  ) async {
    await open(tester, () async => _preview(notes: 'Export the roll call.'));

    expect(
      find.textContaining('Export the roll call.', findRichText: true),
      findsWidgets,
    );
    expect(find.text('No summary yet.'), findsNothing);
  });

  testWidgets('with neither a TL;DR nor notes, says there is no summary', (
    tester,
  ) async {
    await open(tester, () async => _preview());

    expect(find.text('No summary yet.'), findsOneWidget);
    expect(find.text('Open task'), findsOneWidget);
  });

  testWidgets('Open task closes the preview and stacks the task over the '
      'current one', (tester) async {
    await open(tester, () async => _preview(tldr: 'Counted.'));

    await tester.tap(find.text('Open task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => nav.pushDesktopTaskDetail(_taskId)).called(1);
    expect(find.byType(TaskPreviewContent), findsNothing);
  });

  testWidgets('shows a spinner while loading, and still offers the task '
      'when the preview cannot be read', (tester) async {
    final loading = Completer<TaskPreview?>();
    await open(tester, () => loading.future);

    expect(find.byType(DesignSystemSpinner), findsOneWidget);
    expect(find.text('Open task'), findsNothing);

    loading.completeError(StateError('db closed'));
    await tester.pump();

    expect(find.byType(DesignSystemSpinner), findsNothing);
    expect(find.text('Open task'), findsOneWidget);
  });

  testWidgets('a task that is gone shows nothing to open', (tester) async {
    await open(tester, () async => null);

    expect(find.byType(TaskPreviewContent), findsOneWidget);
    expect(find.text('Open task'), findsNothing);
    expect(find.text('Colony census export'), findsNothing);
  });
}
