import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/main.dart' as app;
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';
import 'widget_test_utils.dart';

class _ThrowingDiagnosticsProperty extends DiagnosticsProperty<String> {
  _ThrowingDiagnosticsProperty() : super('widget', 'unstable widget');

  @override
  String toStringDeep({
    String prefixLineOne = '',
    String? prefixOtherLines,
    TextTreeConfiguration? parentConfiguration,
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
    int wrapWidth = 65,
  }) => throw StateError('render failed');
}

void main() {
  late Completer<void> closeCompleter;
  late MockWindowService windowService;
  late MockDomainLogger domainLogger;

  setUp(() async {
    app.resetFrameworkErrorSuppressionForTesting();
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

  test('identical framework errors do not repeat full diagnostics', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);

    final exception = StateError('repeating framework failure');
    final stack = StackTrace.fromString('framework.dart 10:2 build');
    final details = FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'widgets library',
    );

    app.handleFlutterFrameworkError(details);
    app.handleFlutterFrameworkError(details);

    expect(presented, hasLength(1));
    verify(
      () => domainLogger.error(
        LogDomain.general,
        exception,
        stackTrace: stack,
        subDomain: 'widgets library',
      ),
    ).called(1);
  });

  test('framework error count threshold emits a stack-free summary', () {
    app.resetFrameworkErrorSuppressionForTesting(
      summaryEvery: 3,
      summaryInterval: const Duration(minutes: 10),
    );
    final presented = <FlutterErrorDetails>[];
    final printed = <String?>[];
    final previousPresenter = FlutterError.presentError;
    final previousPrint = debugPrint;
    FlutterError.presentError = presented.add;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    addTearDown(() {
      FlutterError.presentError = previousPresenter;
      debugPrint = previousPrint;
    });

    final exception = StateError('counted framework failure');
    final stack = StackTrace.fromString('framework.dart 20:4 layout');
    final details = FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'rendering library',
    );

    for (var i = 0; i < 4; i++) {
      app.handleFlutterFrameworkError(details);
    }

    expect(presented, hasLength(1));
    expect(
      printed.single,
      allOf(
        contains('Repeated Flutter framework error'),
        contains('observed=3'),
        contains('suppressed=3'),
        contains('total=4'),
        isNot(contains('counted framework failure')),
        isNot(contains('framework.dart')),
      ),
    );
    verify(
      () => domainLogger.error(
        LogDomain.general,
        exception,
        stackTrace: stack,
        subDomain: 'rendering library',
      ),
    ).called(1);
    final capturedSummary = verify(
      () => domainLogger.error(
        LogDomain.general,
        captureAny<Object>(that: isNot(same(exception))),
        subDomain: 'rendering library',
        message: captureAny<String>(named: 'message'),
      ),
    ).captured;
    expect(
      capturedSummary.first.toString(),
      'Repeated Flutter framework error',
    );
    expect(
      capturedSummary.last,
      allOf(
        contains('observed=3'),
        contains('suppressed=3'),
        contains('total=4'),
      ),
    );
  });

  test('framework error interval flushes a stopped repeat burst', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);

    final details = FlutterErrorDetails(
      exception: StateError('interval framework failure'),
      stack: StackTrace.fromString('framework.dart 30:6 paint'),
      library: 'painting library',
    );

    fakeAsync((async) {
      app.resetFrameworkErrorSuppressionForTesting(
        scheduleIntervalSummaries: true,
      );
      app.handleFlutterFrameworkError(details);
      async.elapse(const Duration(seconds: 30));
      app.handleFlutterFrameworkError(details);
      verifyNever(
        () => domainLogger.error(
          LogDomain.general,
          any<Object>(),
          subDomain: 'painting library',
          message: any<String>(named: 'message'),
        ),
      );
      async.elapse(const Duration(seconds: 31));
    });

    expect(presented, hasLength(1));
    verify(
      () => domainLogger.error(
        LogDomain.general,
        any<Object>(),
        subDomain: 'painting library',
        message: any<String>(
          named: 'message',
          that: allOf(
            contains('observed=1'),
            contains('suppressed=1'),
            contains('total=2'),
          ),
        ),
      ),
    ).called(1);
  });

  test('distinct framework errors retain independent full diagnostics', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);

    final first = StateError('same framework failure');
    final second = StateError('same framework failure');
    final firstStack = StackTrace.fromString('framework.dart 40:8 build');
    final secondStack = StackTrace.fromString('framework.dart 50:9 build');
    final firstDetails = FlutterErrorDetails(
      exception: first,
      stack: firstStack,
      library: 'widgets library',
    );
    final secondDetails = FlutterErrorDetails(
      exception: second,
      stack: secondStack,
      library: 'widgets library',
    );

    app.handleFlutterFrameworkError(firstDetails);
    app.handleFlutterFrameworkError(firstDetails);
    app.handleFlutterFrameworkError(secondDetails);
    app.handleFlutterFrameworkError(secondDetails);

    expect(presented.map((details) => details.exception), [first, second]);
    verify(
      () => domainLogger.error(
        LogDomain.general,
        first,
        stackTrace: firstStack,
        subDomain: 'widgets library',
      ),
    ).called(1);
    verify(
      () => domainLogger.error(
        LogDomain.general,
        second,
        stackTrace: secondStack,
        subDomain: 'widgets library',
      ),
    ).called(1);
  });

  test('collected diagnostics distinguish otherwise identical errors', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);

    final exception = StateError('same framework failure');
    final stack = StackTrace.fromString('framework.dart 60:10 build');
    FlutterErrorDetails detailsFor(String widgetName) => FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'widgets library',
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('widget', widgetName),
      ],
    );

    app.handleFlutterFrameworkError(detailsFor('first widget'));
    app.handleFlutterFrameworkError(detailsFor('second widget'));

    expect(presented, hasLength(2));
    expect(
      presented
          .map(
            (details) => details.informationCollector!().single.toDescription(),
          )
          .toList(),
      [contains('first widget'), contains('second widget')],
    );
    final capturedDiagnostics = verify(
      () => domainLogger.errorWithDiagnostics(
        LogDomain.general,
        exception,
        stackTrace: stack,
        subDomain: 'widgets library',
        diagnostics: captureAny<String>(named: 'diagnostics'),
      ),
    ).captured;
    expect(capturedDiagnostics, hasLength(2));
    expect(capturedDiagnostics.first, contains('first widget'));
    expect(capturedDiagnostics.last, contains('second widget'));
  });

  test(
    'collected diagnostics are evaluated once and reused for presentation',
    () {
      var collectorCalls = 0;
      final presentedDiagnostics = <String>[];
      final previousPresenter = FlutterError.presentError;
      FlutterError.presentError = (details) {
        presentedDiagnostics.addAll(
          details.informationCollector!().map((node) => node.toStringDeep()),
        );
      };
      addTearDown(() => FlutterError.presentError = previousPresenter);

      final exception = StateError('single collector evaluation');
      final stack = StackTrace.fromString('framework.dart 70:11 build');
      final details = FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widgets library',
        informationCollector: () {
          collectorCalls++;
          return <DiagnosticsNode>[
            DiagnosticsProperty<String>('widget', 'stable widget'),
          ];
        },
      );

      app.handleFlutterFrameworkError(details);

      expect(collectorCalls, 1);
      expect(presentedDiagnostics.single, contains('stable widget'));
      verify(
        () => domainLogger.errorWithDiagnostics(
          LogDomain.general,
          exception,
          stackTrace: stack,
          subDomain: 'widgets library',
          diagnostics: any<String>(
            named: 'diagnostics',
            that: contains('stable widget'),
          ),
        ),
      ).called(1);
    },
  );

  test('collector invocation failure does not mask the framework error', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);

    final exception = StateError('collector invocation failed');
    final stack = StackTrace.fromString('framework.dart 80:12 build');
    final details = FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'widgets library',
      informationCollector: () => throw StateError('collector failed'),
    );

    expect(() => app.handleFlutterFrameworkError(details), returnsNormally);

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

  test('diagnostic rendering failure does not mask the framework error', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);
    final diagnostic = _ThrowingDiagnosticsProperty();

    final exception = StateError('diagnostic rendering failed');
    final stack = StackTrace.fromString('framework.dart 90:13 build');
    final details = FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'widgets library',
      informationCollector: () => <DiagnosticsNode>[diagnostic],
    );

    expect(() => app.handleFlutterFrameworkError(details), returnsNormally);

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

  test('shutdown drain emits a pending repeat summary immediately', () {
    final details = FlutterErrorDetails(
      exception: StateError('shutdown framework failure'),
      stack: StackTrace.fromString('framework.dart 100:14 build'),
      library: 'widgets library',
    );

    app.handleFlutterFrameworkError(details);
    app.handleFlutterFrameworkError(details);
    verifyNever(
      () => domainLogger.error(
        LogDomain.general,
        any<Object>(),
        subDomain: 'widgets library',
        message: any<String>(named: 'message'),
      ),
    );

    app.flushPendingFrameworkErrorSummaries();

    verify(
      () => domainLogger.error(
        LogDomain.general,
        any<Object>(),
        subDomain: 'widgets library',
        message: any<String>(
          named: 'message',
          that: allOf(contains('observed=1'), contains('total=2')),
        ),
      ),
    ).called(1);
  });

  test('framework error fingerprints evict the least recently used entry', () {
    final presented = <FlutterErrorDetails>[];
    final previousPresenter = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = previousPresenter);

    final oldestException = StateError('framework failure 0');
    final oldestDetails = FlutterErrorDetails(
      exception: oldestException,
      stack: StackTrace.fromString('framework.dart 0:1 build'),
      library: 'widgets library',
    );
    app.handleFlutterFrameworkError(oldestDetails);
    for (var i = 1; i <= 256; i++) {
      app.handleFlutterFrameworkError(
        FlutterErrorDetails(
          exception: StateError('framework failure $i'),
          stack: StackTrace.fromString('framework.dart $i:1 build'),
          library: 'widgets library',
        ),
      );
    }

    app.handleFlutterFrameworkError(oldestDetails);

    expect(presented, hasLength(258));
    expect(
      presented.where(
        (details) => identical(details.exception, oldestException),
      ),
      hasLength(2),
    );
    verify(
      () => domainLogger.error(
        LogDomain.general,
        oldestException,
        stackTrace: oldestDetails.stack,
        subDomain: 'widgets library',
      ),
    ).called(2);
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
