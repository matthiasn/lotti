import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';

/// Streams the Matrix client's login-state transitions.
final StreamProvider<LoginState> loginStateStreamProvider =
    StreamProvider.autoDispose<LoginState>(
      loginStateStream,
      name: 'loginStateStreamProvider',
    );
Stream<LoginState> loginStateStream(Ref ref) {
  return ref.watch(matrixServiceProvider).client.onLoginStateChanged.stream;
}
