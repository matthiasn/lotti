import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// A reusable helper for controllers that need to listen to [UpdateNotifications].
///
/// This encapsulates the common pattern of:
/// 1. Tracking subscribed IDs
/// 2. Listening to the update stream
/// 3. Re-fetching when relevant IDs are affected
/// 4. Updating state only when the value changes
///
/// Usage:
/// ```dart
/// class MyController extends _$MyController {
///   late final UpdateStreamListener<MyState> _listener;
///
///   @override
///   Future<MyState?> build({required String id}) async {
///     _listener = UpdateStreamListener(
///       initialIds: {id},
///       fetcher: _fetch,
///       getState: () => state.value,
///       setState: (value) => state = AsyncData(value),
///     );
///     ref.onDispose(_listener.dispose);
///
///     final result = await _fetch();
///     _listener.start();
///     return result;
///   }
/// }
/// ```
class UpdateStreamListener<T> {
  UpdateStreamListener({
    required Future<T?> Function() fetcher,
    required T? Function() getState,
    required void Function(T?) setState,
    Set<String>? initialIds,
  })  : _fetcher = fetcher,
        _getState = getState,
        _setState = setState,
        subscribedIds = initialIds ?? <String>{};

  final Future<T?> Function() _fetcher;
  final T? Function() _getState;
  final void Function(T?) _setState;

  /// IDs this listener is tracking for updates.
  final Set<String> subscribedIds;

  StreamSubscription<Set<String>>? _subscription;

  /// Starts listening to the update stream.
  void start() {
    _subscription = getIt<UpdateNotifications>()
        .updateStream
        .listen(_onUpdate);
  }

  Future<void> _onUpdate(Set<String> affectedIds) async {
    if (affectedIds.intersection(subscribedIds).isNotEmpty) {
      final latest = await _fetcher();
      if (latest != _getState()) {
        _setState(latest);
      }
    }
  }

  /// Adds additional IDs to track.
  void addIds(Iterable<String> ids) {
    subscribedIds.addAll(ids);
  }

  /// Disposes of the subscription.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Extension on [Ref] to simplify listener setup with automatic disposal.
extension UpdateStreamListenerRefExtension on Ref {
  /// Creates and registers an [UpdateStreamListener] with automatic disposal.
  UpdateStreamListener<T> createUpdateStreamListener<T>({
    required Future<T?> Function() fetcher,
    required T? Function() getState,
    required void Function(T?) setState,
    Set<String>? initialIds,
  }) {
    final listener = UpdateStreamListener<T>(
      fetcher: fetcher,
      getState: getState,
      setState: setState,
      initialIds: initialIds,
    );
    onDispose(listener.dispose);
    return listener;
  }
}
