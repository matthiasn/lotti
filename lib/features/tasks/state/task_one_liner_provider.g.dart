// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_one_liner_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches the AI-generated one-liner subtitle for a task from its agent
/// report.
///
/// Watches [agentUpdateStreamProvider] so the value refreshes automatically
/// when the agent report changes (e.g. after an agent run completes).
/// Auto-disposes when the list item scrolls off-screen.

@ProviderFor(taskOneLiner)
final taskOneLinerProvider = TaskOneLinerFamily._();

/// Fetches the AI-generated one-liner subtitle for a task from its agent
/// report.
///
/// Watches [agentUpdateStreamProvider] so the value refreshes automatically
/// when the agent report changes (e.g. after an agent run completes).
/// Auto-disposes when the list item scrolls off-screen.

final class TaskOneLinerProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Fetches the AI-generated one-liner subtitle for a task from its agent
  /// report.
  ///
  /// Watches [agentUpdateStreamProvider] so the value refreshes automatically
  /// when the agent report changes (e.g. after an agent run completes).
  /// Auto-disposes when the list item scrolls off-screen.
  TaskOneLinerProvider._({
    required TaskOneLinerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskOneLinerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskOneLinerHash();

  @override
  String toString() {
    return r'taskOneLinerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return taskOneLiner(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskOneLinerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskOneLinerHash() => r'64be305ef856099bf11d966719158a99845f9cdd';

/// Fetches the AI-generated one-liner subtitle for a task from its agent
/// report.
///
/// Watches [agentUpdateStreamProvider] so the value refreshes automatically
/// when the agent report changes (e.g. after an agent run completes).
/// Auto-disposes when the list item scrolls off-screen.

final class TaskOneLinerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  TaskOneLinerFamily._()
    : super(
        retry: null,
        name: r'taskOneLinerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the AI-generated one-liner subtitle for a task from its agent
  /// report.
  ///
  /// Watches [agentUpdateStreamProvider] so the value refreshes automatically
  /// when the agent report changes (e.g. after an agent run completes).
  /// Auto-disposes when the list item scrolls off-screen.

  TaskOneLinerProvider call(String taskId) =>
      TaskOneLinerProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskOneLinerProvider';
}
