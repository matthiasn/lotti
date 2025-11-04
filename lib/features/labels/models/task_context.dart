class TaskContext {
  const TaskContext({
    required this.existingLabelIds,
    this.categoryId,
    this.suppressedLabelIds,
  });

  final String? categoryId;
  final List<String> existingLabelIds;
  final List<String>? suppressedLabelIds;
}
