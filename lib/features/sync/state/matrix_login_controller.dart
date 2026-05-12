import 'dart:async';

import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_login_controller.g.dart';

@riverpod
class MatrixLoginController extends _$MatrixLoginController {
  @override
  Future<LoginState?> build() async {
    return ref.watch(loginStateStreamProvider).value;
  }
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
  final loginState =
      ref.watch(loginStateStreamProvider).value ??
      matrixService.client.onLoginStateChanged.value;

  if (loginState == LoginState.loggedIn) {
    return matrixService.client.userID;
  }

  return null;
}
