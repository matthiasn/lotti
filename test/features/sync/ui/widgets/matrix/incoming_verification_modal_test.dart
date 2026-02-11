import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockKeyVerificationRunner extends Mock implements KeyVerificationRunner {}

class MockKeyVerification extends Mock implements KeyVerification {}

class FakeKeyVerificationEmoji extends Fake implements KeyVerificationEmoji {
  FakeKeyVerificationEmoji(this.emoji, this.name);

  @override
  final String emoji;

  @override
  final String name;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockKeyVerification mockKeyVerification;
  late StreamController<KeyVerificationRunner> controller;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockKeyVerification = MockKeyVerification();
    controller = StreamController<KeyVerificationRunner>.broadcast();

    when(() => mockMatrixService.incomingKeyVerificationRunnerStream)
        .thenAnswer((_) => controller.stream);
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(() => mockKeyVerification.deviceId).thenReturn('DEVICE1');
    when(() => mockKeyVerification.isDone).thenReturn(false);
  });

  tearDown(() async {
    await controller.close();
  });

  testWidgets('shows verify action before emoji step', (tester) async {
    final runner = MockKeyVerificationRunner();

    when(() => runner.lastStep).thenReturn('');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(mockKeyVerification);
    when(runner.acceptVerification).thenAnswer((_) async {});

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(mockKeyVerification),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('Verify'), findsOneWidget);
    verify(runner.acceptVerification).called(1);
  });

  testWidgets('shows cancel label in emoji verification step', (tester) async {
    final runner = MockKeyVerificationRunner();
    final emojis = List.generate(
      8,
      (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
    );

    when(() => runner.lastStep).thenReturn('m.key.verification.key');
    when(() => runner.emojis).thenReturn(emojis);
    when(() => runner.keyVerification).thenReturn(mockKeyVerification);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(mockKeyVerification),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.byKey(const Key('matrix_cancel_verification')), findsOneWidget);
  });
}
