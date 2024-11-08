import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_login_provider.g.dart';

@riverpod
class MatrixLoginController extends _$MatrixLoginController {
  final _matrixService = getIt<MatrixService>();

  @override
  Future<LoginState?> build() async {
    return ref.watch(loginStateStreamProvider).value;
  }

  Future<void> login() => _matrixService.login();
  Future<void> logout() => _matrixService.logout();
}

@riverpod
Stream<LoginState> loginStateStream(Ref ref) {
  return getIt<MatrixService>().client.onLoginStateChanged.stream;
}

@riverpod
Future<bool> isLoggedIn(Ref ref) async {
  final loginState = ref.watch(loginStateStreamProvider).value;
  return loginState == LoginState.loggedIn;
}

@riverpod
Future<String?> loggedInUserId(Ref ref) async {
  final matrixService = getIt<MatrixService>();
  final loginState = ref.watch(loginStateStreamProvider).valueOrNull ??
      matrixService.client.onLoginStateChanged.value;

  if (loginState == LoginState.loggedIn) {
    return matrixService.client.userID;
  }

  return null;
}
