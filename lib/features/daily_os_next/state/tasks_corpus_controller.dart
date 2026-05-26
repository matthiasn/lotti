// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';

/// Combined filter inputs the Tasks corpus screen owns.
@immutable
class TasksCorpusFilter {
  const TasksCorpusFilter({
    this.stateFilter = TaskCorpusState.all,
    this.categoryId,
    this.query = '',
  });

  final TaskCorpusState stateFilter;
  final String? categoryId;
  final String query;

  TasksCorpusFilter copyWith({
    TaskCorpusState? stateFilter,
    Object? categoryId = _unset,
    String? query,
  }) {
    return TasksCorpusFilter(
      stateFilter: stateFilter ?? this.stateFilter,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      query: query ?? this.query,
    );
  }
}

const _unset = Object();

/// Drives the Tasks corpus screen.
///
/// Owns the filter inputs locally and re-queries
/// `surfaceTaskCorpus` whenever any of them change. The corpus
/// itself is read-only from the UI's perspective — there is no
/// agent involvement per the design.
class TasksCorpusController extends Notifier<TasksCorpusFilter> {
  @override
  TasksCorpusFilter build() => const TasksCorpusFilter();

  void setStateFilter(TaskCorpusState next) {
    state = state.copyWith(stateFilter: next);
  }

  void setCategory(String? id) {
    state = state.copyWith(categoryId: id);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }
}

final tasksCorpusControllerProvider =
    NotifierProvider.autoDispose<TasksCorpusController, TasksCorpusFilter>(
      TasksCorpusController.new,
    );

/// Async list of corpus items for the current [TasksCorpusFilter].
final tasksCorpusItemsProvider =
    FutureProvider.autoDispose<List<TaskCorpusItem>>((ref) async {
      final filter = ref.watch(tasksCorpusControllerProvider);
      final agent = ref.read(dayAgentProvider);
      return agent.surfaceTaskCorpus(
        stateFilter: filter.stateFilter,
        categoryId: filter.categoryId,
        query: filter.query,
      );
    });
