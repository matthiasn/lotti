import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../../widget_test_utils.dart';

class _RecordingSavedController extends SavedTaskFiltersController {
  _RecordingSavedController();

  final List<TasksFilter> created = [];

  @override
  Future<List<SavedTaskFilter>> build() async => const [];

  @override
  Future<SavedTaskFilter> create({
    required String name,
    required TasksFilter filter,
  }) async {
    created.add(filter);
    return SavedTaskFilter(id: 'new', name: name, filter: filter);
  }
}

class _ThrowingSavedController extends SavedTaskFiltersController {
  _ThrowingSavedController();

  @override
  Future<List<SavedTaskFilter>> build() async => const [];

  @override
  Future<SavedTaskFilter> create({
    required String name,
    required TasksFilter filter,
  }) async {
    throw StateError('create failed');
  }
}

class _Harness extends ConsumerWidget {
  const _Harness({required this.onDone});

  final ValueChanged<SavedTaskFilter?> onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('go'),
          onPressed: () async {
            onDone(await promptSaveCurrentTaskFilter(context, ref));
          },
          child: const Text('go'),
        ),
      ),
    );
  }
}

Future<({_RecordingSavedController saved, List<SavedTaskFilter?> results})>
_pump(
  WidgetTester tester, {
  JournalPageState pageState = const JournalPageState(
    selectedTaskStatuses: {'OPEN'},
  ),
}) async {
  final saved = _RecordingSavedController();
  final results = <SavedTaskFilter?>[];
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      _Harness(onDone: results.add),
      overrides: [
        journalPageControllerProvider(
          true,
        ).overrideWith(() => FakeJournalPageController(pageState)),
        savedTaskFiltersControllerProvider.overrideWith(() => saved),
      ],
    ),
  );
  await tester.pump();
  return (saved: saved, results: results);
}

void main() {
  testWidgets('persists the live filter under the entered name', (
    tester,
  ) async {
    final bench = await _pump(tester);

    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(SaveCurrentTaskFilterKeys.nameField),
      'Open work',
    );
    await tester.pump();
    await tester.tap(find.byKey(SaveCurrentTaskFilterKeys.saveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The captured filter mirrors the live page state.
    expect(bench.saved.created.single.selectedTaskStatuses, {'OPEN'});
    // The created filter is returned to the caller.
    expect(bench.results.single?.name, 'Open work');
  });

  testWidgets('promotes the new filter in the MRU order', (tester) async {
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Harness)),
    );

    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(SaveCurrentTaskFilterKeys.nameField),
      'Open work',
    );
    await tester.pump();
    await tester.tap(find.byKey(SaveCurrentTaskFilterKeys.saveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(savedTaskFilterMruProvider), contains('new'));
  });

  testWidgets('dismissing the name modal saves nothing', (tester) async {
    final bench = await _pump(tester);

    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dismiss without entering a name (tap the scrim / press back).
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(bench.saved.created, isEmpty);
    expect(bench.results.single, isNull);
  });

  testWidgets('committing the name via the keyboard action saves', (
    tester,
  ) async {
    final bench = await _pump(tester);

    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(SaveCurrentTaskFilterKeys.nameField),
      'Via keyboard',
    );
    await tester.pump();
    // Press the on-screen keyboard's "done" action instead of the button.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(bench.saved.created.single.selectedTaskStatuses, {'OPEN'});
    expect(bench.results.single?.name, 'Via keyboard');
  });

  testWidgets('logs and swallows a create failure, returning null', (
    tester,
  ) async {
    final logger = MockDomainLogger();
    getIt.registerSingleton<DomainLogger>(logger);
    addTearDown(() => getIt.unregister<DomainLogger>());

    final results = <SavedTaskFilter?>[];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        _Harness(onDone: results.add),
        overrides: [
          journalPageControllerProvider(true).overrideWith(
            () => FakeJournalPageController(
              const JournalPageState(selectedTaskStatuses: {'OPEN'}),
            ),
          ),
          savedTaskFiltersControllerProvider.overrideWith(
            _ThrowingSavedController.new,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(SaveCurrentTaskFilterKeys.nameField),
      'Boom',
    );
    await tester.pump();
    await tester.tap(find.byKey(SaveCurrentTaskFilterKeys.saveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => logger.error(
        LogDomain.tasks,
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'saveCurrentFilter',
      ),
    ).called(1);
    expect(results.single, isNull);
  });
}
