import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/status_indicator.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class _FakeMatrixUnverifiedController extends MatrixUnverifiedController {
  _FakeMatrixUnverifiedController(this.devices);

  final List<DeviceKeys> devices;

  @override
  Future<List<DeviceKeys>> build() async => devices;
}

class MockDeviceKeys extends Mock implements DeviceKeys {}

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
  });

  testWidgets('shows status indicator when there are no unverified devices',
      (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const UnverifiedDevices(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixUnverifiedControllerProvider
              .overrideWith(() => _FakeMatrixUnverifiedController(const [])),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No unverified devices'), findsOneWidget);
    expect(find.byType(StatusIndicator), findsOneWidget);
  });

  testWidgets('renders device list and refresh action', (tester) async {
    final device = MockDeviceKeys();
    when(() => device.deviceDisplayName).thenReturn('Pixel 7');
    when(() => device.deviceId).thenReturn('DEVICE1');
    when(() => device.userId).thenReturn('@user:server');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const UnverifiedDevices(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixUnverifiedControllerProvider.overrideWith(
            () => _FakeMatrixUnverifiedController([device]),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unverified devices'), findsOneWidget);
    expect(find.byType(DeviceCard), findsOneWidget);

    final refreshButton = find.byIcon(MdiIcons.refresh);
    expect(refreshButton, findsOneWidget);

    await tester.tap(refreshButton);
    await tester.pumpAndSettle();
  });

  testWidgets('unverifiedDevicesPage sticky actions navigate', (tester) async {
    final pageIndexNotifier = ValueNotifier<int>(3);
    addTearDown(pageIndexNotifier.dispose);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            final page = unverifiedDevicesPage(
              context: context,
              pageIndexNotifier: pageIndexNotifier,
            );

            return page.stickyActionBar ?? const SizedBox.shrink();
          },
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixUnverifiedControllerProvider.overrideWith(
            () => _FakeMatrixUnverifiedController(const []),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(pageIndexNotifier.value, 3);

    await tester.tap(find.text('Previous Page'));
    await tester.pump();
    expect(pageIndexNotifier.value, 2);

    await tester.tap(find.text('Next Page'));
    await tester.pump();
    expect(pageIndexNotifier.value, 3);
  });
}
