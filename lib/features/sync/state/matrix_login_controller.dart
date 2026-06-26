import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';

/// Exposes the current Matrix [LoginState] (or null before the first event),
/// driven by [loginStateStream], for sync UI that gates on login.
final AsyncNotifierProvider<MatrixLoginController, LoginState?>
matrixLoginControllerProvider =
    AsyncNotifierProvider.autoDispose<MatrixLoginController, LoginState?>(
      MatrixLoginController.new,
      name: 'matrixLoginControllerProvider',
    );

class MatrixLoginController extends AsyncNotifier<LoginState?> {
  @override
  Future<LoginState?> build() async {
    return ref.watch(loginStateStreamProvider).value;
  }
}

/// Streams the Matrix client's login-state transitions.
final StreamProvider<LoginState> loginStateStreamProvider =
    StreamProvider.autoDispose<LoginState>(
      loginStateStream,
      name: 'loginStateStreamProvider',
    );
Stream<LoginState> loginStateStream(Ref ref) {
  return ref.watch(matrixServiceProvider).client.onLoginStateChanged.stream;
}

/// True once the session reaches [LoginState.loggedIn].
final FutureProvider<bool> isLoggedInProvider =
    FutureProvider.autoDispose<bool>(
      isLoggedIn,
      name: 'isLoggedInProvider',
    );
Future<bool> isLoggedIn(Ref ref) async {
  final loginState = ref.watch(loginStateStreamProvider).value;
  return loginState == LoginState.loggedIn;
}

/// The logged-in Matrix user id, or null when not logged in. Falls back to the
/// client's last-known login state if the stream has not yet emitted.
final FutureProvider<String?> loggedInUserIdProvider =
    FutureProvider.autoDispose<String?>(
      loggedInUserId,
      name: 'loggedInUserIdProvider',
    );
Future<String?> loggedInUserId(Ref ref) async {
  final matrixService = ref.watch(matrixServiceProvider);
  final loginState =
      ref.watch(loginStateStreamProvider).value ??
      matrixService.client.onLoginStateChanged.value;

  if (loginState == LoginState.loggedIn) {
    return matrixService.client.userID;
  }

  return null;
}
