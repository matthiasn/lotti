import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/app_lifecycle_rescan_observer.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    // Required by mocktail when using any<StackTrace>() matchers.
    registerFallbackValue(StackTrace.empty);
  });

  testWidgets('triggers forceRescan on app resume', (tester) async {
    final mockService = MockMatrixService();
    when(() => mockService.forceRescan(
        includeCatchUp: any(named: 'includeCatchUp'))).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockService),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: AppLifecycleRescanObserver(child: SizedBox.shrink()),
        ),
      ),
    );

    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    verify(
      () => mockService.forceRescan(
        includeCatchUp: any(named: 'includeCatchUp'),
      ),
    ).called(1);
  });

  testWidgets('logs if forceRescan future completes with error',
      (tester) async {
    final mockService = MockMatrixService();
    final mockLogging = MockLoggingService();
    when(() => mockService.forceRescan(
            includeCatchUp: any(named: 'includeCatchUp')))
        .thenAnswer(
            (_) => Future<void>.error(Exception('boom'), StackTrace.current));
    when(() => mockLogging.captureException(
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockService),
          loggingServiceProvider.overrideWithValue(mockLogging),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: AppLifecycleRescanObserver(child: SizedBox.shrink()),
        ),
      ),
    );

    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    verify(() => mockLogging.captureException(
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          domain: 'AppLifecycleRescanObserver',
          subDomain: 'didChangeAppLifecycleState',
        )).called(1);
  });
}
