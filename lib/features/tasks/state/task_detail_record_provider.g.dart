// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_detail_record_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Builds a [TaskRecord] from real data for display in the desktop detail view.
///
/// Bridges the showcase data model with live providers, enabling reuse
/// of the existing showcase detail widgets with real task data.

@ProviderFor(taskDetailRecord)
final taskDetailRecordProvider = TaskDetailRecordFamily._();

/// Builds a [TaskRecord] from real data for display in the desktop detail view.
///
/// Bridges the showcase data model with live providers, enabling reuse
/// of the existing showcase detail widgets with real task data.

final class TaskDetailRecordProvider
    extends
        $FunctionalProvider<
          AsyncValue<TaskRecord?>,
          TaskRecord?,
          FutureOr<TaskRecord?>
        >
    with $FutureModifier<TaskRecord?>, $FutureProvider<TaskRecord?> {
  /// Builds a [TaskRecord] from real data for display in the desktop detail view.
  ///
  /// Bridges the showcase data model with live providers, enabling reuse
  /// of the existing showcase detail widgets with real task data.
  TaskDetailRecordProvider._({
    required TaskDetailRecordFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskDetailRecordProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskDetailRecordHash();

  @override
  String toString() {
    return r'taskDetailRecordProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TaskRecord?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TaskRecord?> create(Ref ref) {
    final argument = this.argument as String;
    return taskDetailRecord(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskDetailRecordProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskDetailRecordHash() => r'60b1f59af21391c4bbca9f994c5dfc41bf644650';

/// Builds a [TaskRecord] from real data for display in the desktop detail view.
///
/// Bridges the showcase data model with live providers, enabling reuse
/// of the existing showcase detail widgets with real task data.

final class TaskDetailRecordFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TaskRecord?>, String> {
  TaskDetailRecordFamily._()
    : super(
        retry: null,
        name: r'taskDetailRecordProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Builds a [TaskRecord] from real data for display in the desktop detail view.
  ///
  /// Bridges the showcase data model with live providers, enabling reuse
  /// of the existing showcase detail widgets with real task data.

  TaskDetailRecordProvider call(String taskId) =>
      TaskDetailRecordProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskDetailRecordProvider';
}
