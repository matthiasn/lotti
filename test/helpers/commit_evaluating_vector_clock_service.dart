import '../mocks/mocks.dart';

/// A [MockVectorClockService] whose `withVcScope` runs the action and records
/// what `commitWhen` decides for its result.
///
/// The shared mock never evaluates `commitWhen`, so whether a write commits or
/// releases its reserved vector-clock tick is invisible to a test using it.
/// Overriding this one method keeps every other shared stub.
class CommitEvaluatingVectorClockService extends MockVectorClockService {
  /// One entry per scoped write that supplied `commitWhen`, in call order.
  final List<bool> commits = [];

  @override
  Future<T> withVcScope<T>(
    Future<T> Function() action, {
    bool Function(T result)? commitWhen,
  }) async {
    final result = await action();
    if (commitWhen != null) commits.add(commitWhen(result));
    return result;
  }
}
