import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/sync/matrix/verification_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockDeviceKeys extends Mock implements DeviceKeys {}

class MockKeyVerificationRunner extends Mock implements KeyVerificationRunner {}

class MockKeyVerification extends Mock implements KeyVerification {}

class _FakeDeviceKeys extends Fake implements DeviceKeys {}

class FakeKeyVerificationEmoji extends Fake implements KeyVerificationEmoji {
  FakeKeyVerificationEmoji(this.emoji, this.name);

  @override
  final String emoji;

  @override
  final String name;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeDeviceKeys());
  });

  late MockMatrixService mockMatrixService;
  late MockDeviceKeys mockDeviceKeys;
  late StreamController<KeyVerificationRunner> controller;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockDeviceKeys = MockDeviceKeys();
    controller = StreamController<KeyVerificationRunner>.broadcast();

    when(() => mockMatrixService.keyVerificationStream)
        .thenAnswer((_) => controller.stream);
    when(() => mockMatrixService.verifyDevice(any())).thenAnswer((_) async {});
    when(() => mockDeviceKeys.userId).thenReturn('@user:server');
    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');

    getIt.allowReassignment = true;
    getIt.registerSingleton<MatrixService>(mockMatrixService);
  });

  tearDown(() async {
    await controller.close();
    await getIt.reset();
  });

  testWidgets('starts verification and shows start button when idle',
      (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
      ),
    );

    await tester.pump();

    verify(() => mockMatrixService.verifyDevice(mockDeviceKeys)).called(1);
    expect(find.byKey(const Key('matrix_start_verify')), findsOneWidget);
  });

  testWidgets('shows continue message when waiting for acceptance',
      (tester) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();

    when(() => runner.lastStep).thenReturn('');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(false);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(
      find.text('Accept on other device to continue'),
      findsOneWidget,
    );
  });

  testWidgets('displays emojis and actions when verification key is shown',
      (tester) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();
    final emojis = List.generate(
      8,
      (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
    );

    when(() => runner.lastStep).thenReturn('m.key.verification.key');
    when(() => runner.emojis).thenReturn(emojis);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(false);
    when(runner.cancelVerification).thenAnswer((_) async {});

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('They match'), findsOneWidget);
    final cancelFinder = find.byKey(const Key('matrix_cancel_verification'));
    expect(cancelFinder, findsOneWidget);

    await tester.tap(cancelFinder);
    await tester.pumpAndSettle();

    verify(runner.cancelVerification).called(1);
  });

  testWidgets('shows success state when verification is complete',
      (tester) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();

    when(() => runner.lastStep).thenReturn('m.key.verification.done');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(true);

    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(
      find.text("You've successfully verified Pixel 7 (DEVICE1)"),
      findsOneWidget,
    );
    expect(find.byIcon(MdiIcons.shieldCheck), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('shows cancelled message when verification stops elsewhere',
      (tester) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();

    when(() => runner.lastStep).thenReturn('m.key.verification.cancel');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(false);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('Cancelled on other device...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
  });
}
