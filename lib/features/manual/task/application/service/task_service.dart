import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskService {
  TaskService();

  
} 

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService();
});