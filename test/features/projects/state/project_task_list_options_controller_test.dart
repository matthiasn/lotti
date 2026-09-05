import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/projects/state/project_task_list_options_controller.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  const projectId = 'project-1';
  final key = projectTaskListOptionsSettingsKey(projectId);
  late TestGetItMocks mocks;
  late ProviderContainer container;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mocks = await setUpTestGetIt();
    when(
      () => mocks.settingsDb.itemByKey(any<String>()),
    ).thenAnswer((_) async => null);
    when(
      () => mocks.settingsDb.saveSettingsItem(any<String>(), any<String>()),
    ).thenAnswer((_) async => 1);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  /// Drains the pending microtasks of the controller's async load.
  Future<void> awaitHydration() async {
    for (var i = 0; i < 16; i++) {
      await Future<void>.value();
    }
  }

  ProjectTaskListOptions read() =>
      container.read(projectTaskListOptionsProvider(projectId));

  /// Swaps a mock logger into getIt and returns it.
  MockDomainLogger installMockLogger() {
    final logger = MockDomainLogger();
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
        message: any<String>(named: 'message'),
      ),
    ).thenReturn(null);
    getIt
      ..unregister<DomainLogger>()
      ..registerSingleton<DomainLogger>(logger);
    return logger;
  }

  test('keys the preference by project', () {
    expect(key, 'PROJECT_TASK_LIST_OPTIONS_project-1');
    expect(
      projectTaskListOptionsSettingsKey('other'),
      isNot(key),
    );
  });

  test('starts with the defaults and hydrates a stored preference', () async {
    const stored = ProjectTaskListOptions(
      groupBy: ProjectTaskGroupBy.status,
      sortBy: ProjectTaskSortBy.title,
      keepDoneInGroups: true,
    );
    when(
      () => mocks.settingsDb.itemByKey(key),
    ).thenAnswer((_) async => jsonEncode(stored.toJson()));

    expect(read(), ProjectTaskListOptions.defaults);
    await awaitHydration();

    expect(read(), stored);
  });

  test('a corrupt or foreign preference leaves the defaults', () async {
    when(
      () => mocks.settingsDb.itemByKey(key),
    ).thenAnswer((_) async => '{not json');
    read();
    await awaitHydration();
    expect(read(), ProjectTaskListOptions.defaults);

    container.dispose();
    container = ProviderContainer();
    when(() => mocks.settingsDb.itemByKey(key)).thenAnswer((_) async => '[1]');
    read();
    await awaitHydration();
    expect(read(), ProjectTaskListOptions.defaults);
  });

  test('update applies at once and persists as JSON', () async {
    const chosen = ProjectTaskListOptions(
      groupBy: ProjectTaskGroupBy.dueWindow,
      keepDoneInGroups: true,
    );

    container
        .read(projectTaskListOptionsProvider(projectId).notifier)
        .update(
          chosen,
        );

    expect(read(), chosen);
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        key,
        jsonEncode(chosen.toJson()),
      ),
    ).called(1);
  });

  test('a load that lands after an edit does not clobber it', () async {
    final load = Completer<String?>();
    when(() => mocks.settingsDb.itemByKey(key)).thenAnswer((_) => load.future);
    const chosen = ProjectTaskListOptions(groupBy: ProjectTaskGroupBy.none);

    read();
    container
        .read(projectTaskListOptionsProvider(projectId).notifier)
        .update(
          chosen,
        );
    load.complete(
      jsonEncode(
        const ProjectTaskListOptions(
          groupBy: ProjectTaskGroupBy.priority,
        ).toJson(),
      ),
    );
    await awaitHydration();

    expect(read(), chosen);
  });

  test(
    'a settings read that fails leaves the defaults and is logged',
    () async {
      final logger = installMockLogger();
      final failure = StateError('database closed');
      when(() => mocks.settingsDb.itemByKey(key)).thenThrow(failure);

      read();
      await awaitHydration();

      expect(read(), ProjectTaskListOptions.defaults);
      verify(
        () => logger.error(
          LogDomain.settings,
          failure,
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'projectTaskListOptions.load',
        ),
      ).called(1);
    },
  );

  test('a failed write keeps the in-memory choice and is logged', () async {
    final logger = installMockLogger();
    final failure = StateError('disk full');
    when(
      () => mocks.settingsDb.saveSettingsItem(key, any<String>()),
    ).thenAnswer((_) async => throw failure);
    const chosen = ProjectTaskListOptions(sortBy: ProjectTaskSortBy.priority);

    container
        .read(projectTaskListOptionsProvider(projectId).notifier)
        .update(chosen);
    await awaitHydration();

    expect(read(), chosen);
    verify(
      () => logger.error(
        LogDomain.settings,
        failure,
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'projectTaskListOptions.persist',
      ),
    ).called(1);
  });

  test('a failure without a registered logger is still contained', () async {
    getIt.unregister<DomainLogger>();
    when(
      () => mocks.settingsDb.itemByKey(key),
    ).thenAnswer((_) async => throw StateError('database closed'));
    when(
      () => mocks.settingsDb.saveSettingsItem(key, any<String>()),
    ).thenThrow(StateError('disk full'));
    const chosen = ProjectTaskListOptions(groupBy: ProjectTaskGroupBy.status);

    read();
    container
        .read(projectTaskListOptionsProvider(projectId).notifier)
        .update(chosen);
    await awaitHydration();

    expect(read(), chosen);
  });

  test('works without a settings database', () async {
    await tearDownTestGetIt();
    expect(getIt.isRegistered<SettingsDb>(), isFalse);
    final bare = ProviderContainer();
    addTearDown(bare.dispose);
    const chosen = ProjectTaskListOptions(sortBy: ProjectTaskSortBy.estimate);

    bare
        .read(projectTaskListOptionsProvider(projectId).notifier)
        .update(chosen);
    await awaitHydration();

    expect(bare.read(projectTaskListOptionsProvider(projectId)), chosen);
  });
}
