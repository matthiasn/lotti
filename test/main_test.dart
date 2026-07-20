import 'dart:ui' show AppExitResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/main.dart' as app;
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';
import 'widget_test_utils.dart';

void main() {
  late MockWindowService windowService;

  setUp(() async {
    windowService = MockWindowService();
    when(windowService.closeWindow).thenAnswer((_) async {});
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<WindowService>(windowService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  test('exit request awaits the platform-aware window close path', () async {
    final response = await app.handleAppExitRequested();

    expect(response, AppExitResponse.exit);
    verify(windowService.closeWindow).called(1);
    verifyNever(windowService.shutdown);
  });
}
