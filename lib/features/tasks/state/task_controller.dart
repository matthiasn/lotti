import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_controller.g.dart';

@riverpod
class TaskController extends _$TaskController {
  TaskController() {}
  JournalEntity? _prev;

  @override
  create() {}

  @override
  Future<Task?> build({required String id}) async {
    final entry = ref.watch(entityByIdProvider(id: id)).value;

    if (entry is Task) {
      if (entry != _prev) {
        debugPrint('TaskController build $id');
        _prev = entry;
        return entry;
      }
    }

    return null;
  }
}

@riverpod
class TaskController1 extends _$TaskController {
  TaskController1() {
    _controller = StreamController();
  }
  late final StreamController<JournalEntity?> _controller;

  @override
  Future<Task?> build({required String id}) async {
    return null;
  }
}

@riverpod
Stream<JournalEntity?> entityById(
  EntityByIdRef ref, {
  required String id,
}) {
  debugPrint('entityById $id');
  final filter = makeDuplicateFilter<JournalEntity?>();
  return getIt<JournalDb>().watchEntityById(id).asBroadcastStream();
//      .where(filter);
}
