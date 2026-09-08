import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';

final plazaRepositoryProvider = Provider<PlazaRepository>(
  (ref) => PlazaRepository(
    db: getIt<JournalDb>(),
    cache: getIt<EntitiesCacheService>(),
    persistence: getIt<PersistenceLogic>(),
  ),
);

final plazaUpdatesProvider = Provider<Stream<Set<String>>>(
  (ref) => getIt<UpdateNotifications>().updateStream,
);

/// Attention uses UTC calendar days. Share one clock per visible plaza route
/// tree, and refresh it after midnight or desktop suspension.
final Provider<DateTime> plazaDayProvider = Provider.autoDispose<DateTime>((
  ref,
) {
  final now = clock.now().toUtc();
  final midnight = DateTime.utc(now.year, now.month, now.day + 1);
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
  return now;
});

/// Live, project-scoped data for the scene. Reads are serialized and a burst
/// during a read schedules at most one replacement, so older snapshots cannot
/// overwrite newer ones. Background refresh does not emit a loading shell.
final StreamProviderFamily<ProjectPlazaData?, String> projectPlazaProvider =
    StreamProvider.autoDispose.family<ProjectPlazaData?, String>((
      ref,
      projectId,
    ) {
      final repository = ref.watch(plazaRepositoryProvider);
      return _watchPlaza(
        ref,
        projectId,
        load: () => repository.loadProject(projectId),
        dependenciesOf: (data) => data.dependencyIds,
      );
    });

final StreamProviderFamily<CategoryPlazaData?, String> categoryPlazaProvider =
    StreamProvider.autoDispose.family<CategoryPlazaData?, String>((
      ref,
      categoryId,
    ) {
      final repository = ref.watch(plazaRepositoryProvider);
      return _watchPlaza(
        ref,
        categoryId,
        load: () => repository.loadCategory(categoryId),
        dependenciesOf: (data) => data.dependencyIds,
      );
    });

Stream<T?> _watchPlaza<T>(
  Ref ref,
  String scopeId, {
  required Future<T?> Function() load,
  required Set<String> Function(T data) dependenciesOf,
}) {
  final updates = ref.watch(plazaUpdatesProvider);
  final output = StreamController<T?>();
  var dependencies = <String>{scopeId};
  var loading = false;
  var pending = false;
  var disposed = false;

  Future<void> reload() async {
    if (loading) {
      pending = true;
      return;
    }
    loading = true;
    do {
      pending = false;
      try {
        final data = await load();
        if (disposed) return;
        // If sync advanced while loading, publish only the replacement.
        if (pending) continue;
        dependencies = data == null ? {scopeId} : dependenciesOf(data);
        output.add(data);
      } catch (error, stackTrace) {
        if (disposed) return;
        if (!pending) output.addError(error, stackTrace);
      }
    } while (pending && !disposed);
    loading = false;
  }

  final subscription = updates.listen((ids) {
    // A deliberate visibility change must not retain the former private data
    // while a read is in flight (or after a failed refresh).
    if (ids.contains(privateToggleNotification)) output.add(null);
    if (loading ||
        ids.any(dependencies.contains) ||
        ids.contains(projectNotification) ||
        ids.contains(linkNotification) ||
        ids.contains(categoriesNotification) ||
        ids.contains(privateToggleNotification)) {
      unawaited(reload());
    }
  });
  ref.onDispose(() {
    disposed = true;
    unawaited(subscription.cancel());
    unawaited(output.close());
  });
  unawaited(reload());
  return output.stream;
}
