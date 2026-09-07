import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/features/plaza/state/project_plaza_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';

void main() {
  final project = makeTestProject(id: 'project');
  final first = ProjectPlazaData(
    project: project,
    tasks: const [],
    dependencyIds: const {'project', 'task', 'item'},
  );
  final second = ProjectPlazaData(
    project: project.copyWith(data: project.data.copyWith(title: 'Updated')),
    tasks: const [],
    dependencyIds: const {'project', 'task', 'new-item'},
  );
  late MockPlazaRepository repository;
  late StreamController<Set<String>> updates;
  late ProviderContainer container;

  setUp(() {
    repository = MockPlazaRepository();
    updates = StreamController<Set<String>>.broadcast();
    when(
      () => repository.loadProject('project'),
    ).thenAnswer((_) async => first);
    container = ProviderContainer.test(
      overrides: [
        plazaRepositoryProvider.overrideWithValue(repository),
        plazaUpdatesProvider.overrideWithValue(updates.stream),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    unawaited(updates.close());
  });

  testWidgets(
    'production providers resolve services and stream scoped category updates',
    (tester) async {
      final cache = MockEntitiesCacheService();
      final persistence = MockPersistenceLogic();
      final services = await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<EntitiesCacheService>(cache)
            ..registerSingleton<PersistenceLogic>(persistence);
        },
      );
      addTearDown(tearDownTestGetIt);
      when(
        () => services.updateNotifications.updateStream,
      ).thenAnswer((_) => updates.stream);
      final category = ManualDemoWorld.penguinLogistics(
        now: manualDemoNow,
      ).categories.first;
      when(() => cache.getCategoryById(category.id)).thenReturn(category);
      when(() => cache.lockedCategoryIds).thenReturn({});
      when(
        () => services.journalDb.getProjectsForCategory(category.id),
      ).thenAnswer((_) async => []);
      final live = ProviderContainer.test();
      addTearDown(live.dispose);
      final subscription = live.listen(
        categoryPlazaProvider(category.id),
        (_, _) {},
      );
      await tester.pump();
      expect(subscription.read().value!.category, category);
      expect(subscription.read().value!.projects, isEmpty);
      when(() => cache.lockedCategoryIds).thenReturn({category.id});
      updates.add({categoriesNotification});
      await tester.pump();
      expect(subscription.read().hasValue, isTrue);
      expect(subscription.read().value, isNull);
      verify(
        () => services.journalDb.getProjectsForCategory(category.id),
      ).called(1);
    },
  );

  testWidgets('resuming after suspension refreshes the attention day', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 8);
    await withClock(Clock(() => now), () async {
      final subscription = container.listen(plazaDayProvider, (_, _) {});
      expect(subscription.read(), now);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2026, 9, 10);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(subscription.read(), now);
      subscription.close();
      container.dispose();
      await tester.pump();
    });
  });

  testWidgets('loads once and ignores unrelated task notifications', (
    tester,
  ) async {
    final subscription = container.listen(
      projectPlazaProvider('project'),
      (_, _) {},
    );
    await tester.pump();
    expect(subscription.read().value, same(first));
    updates.add({'unrelated-task'});
    await tester.pump();
    verify(() => repository.loadProject('project')).called(1);
  });

  testWidgets('keeps rendered data while a checklist refresh is in flight', (
    tester,
  ) async {
    final subscription = container.listen(
      projectPlazaProvider('project'),
      (_, _) {},
    );
    await tester.pump();
    final pending = Completer<ProjectPlazaData?>();
    when(
      () => repository.loadProject('project'),
    ).thenAnswer((_) => pending.future);
    updates.add({'item'});
    await tester.pump();
    expect(subscription.read().value, same(first));
    expect(subscription.read().isLoading, isFalse);
    pending.complete(second);
    await tester.pump();
    expect(subscription.read().value, same(second));
    verify(() => repository.loadProject('project')).called(2);
  });

  testWidgets('coalesces a burst and rejects a superseded in-flight snapshot', (
    tester,
  ) async {
    final pending = Completer<ProjectPlazaData?>();
    var calls = 0;
    when(() => repository.loadProject('project')).thenAnswer((_) {
      calls++;
      return calls == 1 ? pending.future : Future.value(second);
    });
    final seen = <ProjectPlazaData?>[];
    final subscription = container.listen(projectPlazaProvider('project'), (
      _,
      next,
    ) {
      if (next.hasValue) seen.add(next.value);
    });
    updates
      ..add({'project'})
      ..add({'project'})
      ..add({'project'});
    await tester.pump();
    pending.complete(first);
    await tester.pump();
    expect(subscription.read().value, same(second));
    expect(seen, [second]);
    expect(calls, 2);
  });

  testWidgets('refreshes membership and clears a removed or hidden project', (
    tester,
  ) async {
    final subscription = container.listen(
      projectPlazaProvider('project'),
      (_, _) {},
    );
    await tester.pump();
    when(() => repository.loadProject('project')).thenAnswer((_) async => null);
    updates.add({projectNotification});
    await tester.pump();
    expect(subscription.read().hasValue, isTrue);
    expect(subscription.read().value, isNull);
  });

  testWidgets(
    'recovers from a failed refresh on the next relevant notification',
    (tester) async {
      final subscription = container.listen(
        projectPlazaProvider('project'),
        (_, _) {},
      );
      await tester.pump();
      when(
        () => repository.loadProject('project'),
      ).thenThrow(StateError('read failed'));
      updates.add({linkNotification});
      await tester.pump();
      expect(subscription.read().hasError, isTrue);
      when(
        () => repository.loadProject('project'),
      ).thenAnswer((_) async => second);
      updates.add({privateToggleNotification});
      await tester.pump();
      expect(subscription.read().value, same(second));
      expect(subscription.read().hasError, isFalse);
    },
  );

  testWidgets('child notifications during discovery supersede the first read', (
    tester,
  ) async {
    final pending = Completer<ProjectPlazaData?>();
    var calls = 0;
    when(
      () => repository.loadProject('project'),
    ).thenAnswer((_) => ++calls == 1 ? pending.future : Future.value(second));
    final seen = <ProjectPlazaData?>[];
    final subscription = container.listen(projectPlazaProvider('project'), (
      _,
      next,
    ) {
      if (next.hasValue) seen.add(next.value);
    });
    updates.add({'new-item'});
    await tester.pump();
    pending.complete(first);
    await tester.pump();
    expect(subscription.read().value, same(second));
    expect(seen, [second]);
  });

  testWidgets('visibility changes immediately discard the old snapshot', (
    tester,
  ) async {
    final subscription = container.listen(
      projectPlazaProvider('project'),
      (_, _) {},
    );
    await tester.pump();
    final pending = Completer<ProjectPlazaData?>();
    when(
      () => repository.loadProject('project'),
    ).thenAnswer((_) => pending.future);
    updates.add({privateToggleNotification});
    await tester.pump();
    expect(subscription.read().hasValue, isTrue);
    expect(subscription.read().value, isNull);
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(subscription.read().value, isNull);
  });

  testWidgets(
    'shared attention clock advances at UTC midnight without task edits',
    (tester) async {
      var now = DateTime.utc(2026, 9, 8, 23, 59, 59);
      await withClock(Clock(() => now), () async {
        final subscription = container.listen(plazaDayProvider, (_, _) {});
        expect(subscription.read(), now);
        now = DateTime.utc(2026, 9, 9);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(subscription.read(), now);
        subscription.close();
        container.dispose();
        await tester.pump();
      });
    },
  );

  testWidgets('disposal cancels updates and ignores a pending read', (
    tester,
  ) async {
    final pending = Completer<ProjectPlazaData?>();
    when(
      () => repository.loadProject('project'),
    ).thenAnswer((_) => pending.future);
    container.listen(projectPlazaProvider('project'), (_, _) {});
    await tester.pump();
    container.dispose();
    pending.complete(first);
    await tester.pump();
    expect(updates.hasListener, isFalse);
    verify(() => repository.loadProject('project')).called(1);
    expect(tester.takeException(), isNull);
  });
}
