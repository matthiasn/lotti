import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final AsyncNotifierProviderFamily<TaskAppBarController, double, String>
taskAppBarControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TaskAppBarController, double, String>(
      TaskAppBarController.new,
      name: 'taskAppBarControllerProvider',
    );

class TaskAppBarController extends AsyncNotifier<double> {
  TaskAppBarController([this.id = '']);

  final String id;

  @override
  Future<double> build() async {
    return 0.0;
  }

  void updateOffset(double offset) {
    state = AsyncData(offset);
  }
}
