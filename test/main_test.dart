import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/main.dart' as app;
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';
import 'widget_test_utils.dart';

void main() {
  late Completer<void> closeCompleter;
  late MockWindowService windowService;
  late MockDomainLogger domainLogger;

  setUp(() async {
    closeCompleter = Completer<void>();
    addTearDown(() {
      if (!closeCompleter.isCompleted) closeCompleter.complete();
    });
    windowService = MockWindowService();
    domainLogger = MockDomainLogger();
    when(windowService.closeWindow).thenAnswer((_) => closeCompleter.future);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<WindowService>(windowService)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(domainLogger);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  test('framework errors reach the console and the durable log', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);

    final exception = StateError('deactivated ancestor lookup');
    final stack = StackTrace.current;
    app.handleFlutterFrameworkError(
      FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widgets library',
      ),
    );

    expect(presented.single.exception, same(exception));
    verify(
      () => domainLogger.error(
        LogDomain.general,
        exception,
        stackTrace: stack,
        subDomain: 'widgets library',
      ),
    ).called(1);
  });

  test('uncaught zone errors always echo to the console', () {
    final printed = <String?>[];
    final previousPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    addTearDown(() => debugPrint = previousPrint);

    final error = StateError('boom');
    final stack = StackTrace.current;
    app.handleUncaughtZoneError(error, stack);
    expect(printed.single, contains('boom'));
    verify(
      () => domainLogger.error(
        LogDomain.general,
        error,
        stackTrace: stack,
        subDomain: 'runZonedGuarded',
      ),
    ).called(1);

    // Before logging is registered the handler must still print and must not
    // be masked by the GetIt lookup failing.
    getIt.unregister<DomainLogger>();
    app.handleUncaughtZoneError(StateError('early boom'), stack);
    expect(printed.last, contains('early boom'));
    verifyNoMoreInteractions(domainLogger);
  });

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
