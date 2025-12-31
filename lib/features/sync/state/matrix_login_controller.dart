import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_login_controller.g.dart';

@riverpod
class MatrixLoginController extends _$MatrixLoginController {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);

  @override
  Future<LoginState?> build() async {
    return ref.watch(loginStateStreamProvider).value;
  }

  Future<void> login() => _matrixService.login();
  Future<void> logout() => _matrixService.logout();
}

@riverpod
Stream<LoginState> loginStateStream(Ref ref) {
  return ref.watch(matrixServiceProvider).client.onLoginStateChanged.stream;
}

@riverpod
Future<bool> isLoggedIn(Ref ref) async {
  final loginState = ref.watch(loginStateStreamProvider).value;
  return loginState == LoginState.loggedIn;
}

@riverpod
Future<String?> loggedInUserId(Ref ref) async {
  final matrixService = ref.watch(matrixServiceProvider);
  final loginState = ref.watch(loginStateStreamProvider).value ??
      matrixService.client.onLoginStateChanged.value;

  if (loginState == LoginState.loggedIn) {
    return matrixService.client.userID;
  }

  return null;
}
