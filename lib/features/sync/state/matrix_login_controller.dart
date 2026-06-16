import 'dart:async';

import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_login_controller.g.dart';

/// Exposes the current Matrix [LoginState] (or null before the first event),
/// driven by [loginStateStream], for sync UI that gates on login.
@riverpod
class MatrixLoginController extends _$MatrixLoginController {
  @override
  Future<LoginState?> build() async {
    return ref.watch(loginStateStreamProvider).value;
  }
}

/// Streams the Matrix client's login-state transitions.
@riverpod
Stream<LoginState> loginStateStream(Ref ref) {
  return ref.watch(matrixServiceProvider).client.onLoginStateChanged.stream;
}

/// True once the session reaches [LoginState.loggedIn].
@riverpod
Future<bool> isLoggedIn(Ref ref) async {
  final loginState = ref.watch(loginStateStreamProvider).value;
  return loginState == LoginState.loggedIn;
}

/// The logged-in Matrix user id, or null when not logged in. Falls back to the
/// client's last-known login state if the stream has not yet emitted.
@riverpod
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
