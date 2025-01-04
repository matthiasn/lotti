import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tasks_count_controller.g.dart';

@Riverpod(keepAlive: true)
class TasksCountController extends _$TasksCountController {
  final subscribedIds = <String>{taskNotification};
  StreamSubscription<Set<String>>? _updateSubscription;

  void listen() {
    _updateSubscription =
        getIt<UpdateNotifications>().updateStream.listen((affectedIds) async {
      if (affectedIds.intersection(subscribedIds).isNotEmpty) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<int> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());

    final count = await _fetch();
    listen();
    return count;
  }

  Future<int> _fetch() async {
    return getIt<JournalDb>().getInProgressTasksCount();
  }
}
