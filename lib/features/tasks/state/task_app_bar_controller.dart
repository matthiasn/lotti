import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_app_bar_controller.g.dart';

@riverpod
class TaskAppBarController extends _$TaskAppBarController {
  TaskAppBarController();

  @override
  Future<double> build({required String id}) async {
    return 0.0;
  }

  void updateOffset(double offset) {
    state = AsyncData(offset);
  }
}
