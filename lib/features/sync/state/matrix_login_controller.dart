import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';

/// Streams the sync session's login-state transitions.
final StreamProvider<SyncLoginState> loginStateStreamProvider =
    StreamProvider.autoDispose<SyncLoginState>(
      loginStateStream,
      name: 'loginStateStreamProvider',
    );
Stream<SyncLoginState> loginStateStream(Ref ref) {
  return ref.watch(matrixServiceProvider).loginStateChanges;
}
