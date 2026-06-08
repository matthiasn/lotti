import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/status_indicator.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
  });

  // The real [MatrixUnverifiedController.build] simply forwards to
  // `matrixServiceProvider.getUnverifiedDevices()`, so driving the page
  // through the service mock exercises the production controller path and
  // lets us verify how often the device list is (re-)fetched.
  testWidgets('shows status indicator when there are no unverified devices', (
    tester,
  ) async {
    when(
      () => mockMatrixService.getUnverifiedDevices(),
    ).thenReturn(<DeviceKeys>[]);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const UnverifiedDevices(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No unverified devices'), findsOneWidget);
    expect(find.byType(StatusIndicator), findsOneWidget);
    expect(find.byType(DeviceCard), findsNothing);
  });

  testWidgets('renders device list and refresh re-fetches the device list', (
    tester,
  ) async {
    final device = MockDeviceKeys();
    when(() => device.deviceDisplayName).thenReturn('Pixel 7');
    when(() => device.deviceId).thenReturn('DEVICE1');
    when(() => device.userId).thenReturn('@user:server');
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([device]);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const UnverifiedDevices(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Unverified devices'), findsOneWidget);
    expect(find.byType(DeviceCard), findsOneWidget);

    // The initial build fetched the device list at least once.
    verify(
      () => mockMatrixService.getUnverifiedDevices(),
    ).called(greaterThanOrEqualTo(1));
    clearInteractions(mockMatrixService);

    // Tapping refresh invalidates the controller provider, which re-runs
    // its build() and therefore fetches the device list again.
    await tester.tap(find.byIcon(MdiIcons.refresh));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(
      () => mockMatrixService.getUnverifiedDevices(),
    ).called(greaterThanOrEqualTo(1));
    // The device list still renders after the refresh-triggered rebuild.
    expect(find.byType(DeviceCard), findsOneWidget);
  });
}
