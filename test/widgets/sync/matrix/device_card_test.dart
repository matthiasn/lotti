import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/sync/matrix/device_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockDeviceKeys mockDeviceKeys;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockDeviceKeys = MockDeviceKeys();

    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
    when(() => mockDeviceKeys.userId).thenReturn('@user:server');
  });

  testWidgets('deletes device and shows success feedback', (tester) async {
    when(() => mockMatrixService.deleteDevice(mockDeviceKeys))
        .thenAnswer((_) async {});

    var refreshed = false;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DeviceCard(
          mockDeviceKeys,
          refreshListCallback: () {
            refreshed = true;
          },
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
    await tester.pumpAndSettle();

    verify(() => mockMatrixService.deleteDevice(mockDeviceKeys)).called(1);
    expect(refreshed, isTrue);
    expect(
      find.text('Device Pixel 7 deleted successfully'),
      findsOneWidget,
    );
  });

  testWidgets('shows error feedback when deletion fails', (tester) async {
    when(() => mockMatrixService.deleteDevice(mockDeviceKeys))
        .thenThrow(Exception('boom'));

    var refreshed = false;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DeviceCard(
          mockDeviceKeys,
          refreshListCallback: () {
            refreshed = true;
          },
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
    await tester.pumpAndSettle();

    verify(() => mockMatrixService.deleteDevice(mockDeviceKeys)).called(1);
    expect(refreshed, isFalse);
    expect(
      find.text('Failed to delete device: Exception: boom'),
      findsOneWidget,
    );
  });
}
