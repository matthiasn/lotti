import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/ui/app_lifecycle_rescan_observer.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
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
}
