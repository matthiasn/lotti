import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/main.dart' as app;
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';
import 'widget_test_utils.dart';

void main() {
  late Completer<void> closeCompleter;
  late MockWindowService windowService;

  setUp(() async {
    closeCompleter = Completer<void>();
    addTearDown(() {
      if (!closeCompleter.isCompleted) closeCompleter.complete();
    });
    windowService = MockWindowService();
    when(windowService.closeWindow).thenAnswer((_) => closeCompleter.future);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<WindowService>(windowService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  test('exit request awaits the platform-aware window close path', () async {
    final responseFuture = app.handleAppExitRequested();
    var responseCompleted = false;
    unawaited(
      responseFuture.then((_) {
        responseCompleted = true;
      }),
    );

    await Future<void>.value();
    expect(responseCompleted, isFalse);

    closeCompleter.complete();
    final response = await responseFuture;

    expect(response, AppExitResponse.exit);
    verify(windowService.closeWindow).called(1);
    verifyNever(windowService.shutdown);
  });
}
