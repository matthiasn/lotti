import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class TaskScrollController {
  TaskScrollController({
    required this.taskId,
    required this.scrollController,
    required this.listController,
  });

  final String taskId;
  final ScrollController scrollController;
  final ListController listController;
  final Map<String, int> linkedEntryIndices = {};

  void scrollToEntry(String entryId) {
    final entryIndex = linkedEntryIndices[entryId];
    if (entryIndex != null && scrollController.hasClients) {
      listController.animateToItem(
        index: entryIndex,
        scrollController: scrollController,
        alignment: 0.2,
        duration: (estimatedDistance) => const Duration(milliseconds: 500),
        curve: (estimatedDistance) => Curves.easeInOut,
      );
    }
  }

  void scrollToSection(int sectionIndex) {
    if (scrollController.hasClients) {
      listController.animateToItem(
        index: sectionIndex,
        scrollController: scrollController,
        alignment: 0.2,
        duration: (estimatedDistance) => const Duration(milliseconds: 500),
        curve: (estimatedDistance) => Curves.easeInOut,
      );
    }
  }

  void updateIndices(Map<String, int> indices) {
    linkedEntryIndices
      ..clear()
      ..addAll(indices);
  }

  void dispose() {
    scrollController.dispose();
    listController.dispose();
  }
}

// Provider to manage task scroll controllers
final StateNotifierProviderFamily<TaskScrollControllerNotifier,
        TaskScrollController?, String> taskScrollControllerProvider =
    StateNotifierProvider.family<TaskScrollControllerNotifier,
        TaskScrollController?, String>(
  (ref, taskId) => TaskScrollControllerNotifier(taskId: taskId),
);

class TaskScrollControllerNotifier
    extends StateNotifier<TaskScrollController?> {
  TaskScrollControllerNotifier({required this.taskId}) : super(null) {
    // Initialize the controller when the notifier is created
    state = TaskScrollController(
      taskId: taskId,
      scrollController: ScrollController(),
      listController: ListController(),
    );
  }

  final String taskId;

  void updateIndices(Map<String, int> indices) {
    state?.updateIndices(indices);
  }

  void scrollToEntry(String entryId) {
    state?.scrollToEntry(entryId);
  }

  void scrollToSection(int sectionIndex) {
    state?.scrollToSection(sectionIndex);
  }

  @override
  void dispose() {
    state?.dispose();
    super.dispose();
  }
}
