import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

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

  testWidgets('shows success state when verification is done', (tester) async {
    final runner = MockKeyVerificationRunner();

    when(() => runner.lastStep).thenReturn('m.key.verification.done');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(mockKeyVerification);
    when(() => mockKeyVerification.isDone).thenReturn(true);

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

    expect(find.byIcon(MdiIcons.shieldCheck), findsOneWidget);
    final context = tester.element(find.byType(IncomingVerificationModal));
    expect(
      find.text(context.messages.settingsMatrixVerificationSuccessConfirm),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping Accept transitions to awaiting other device state',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final emojis = List.generate(
        8,
        (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
      );

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(emojis);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(runner.cancelVerification).thenAnswer((_) async {});
      when(runner.acceptEmojiVerification).thenAnswer((_) async {});

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

      await tester.tap(find.text('Accept'));
      await tester.pump();

      verify(runner.acceptEmojiVerification).called(1);
      final context = tester.element(find.byType(IncomingVerificationModal));
      expect(
        find.text(context.messages.settingsMatrixContinueVerificationLabel),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'cancel button calls runner cancellation',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final emojis = List.generate(
        8,
        (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
      );

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(emojis);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(runner.cancelVerification).thenAnswer((_) async {});

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

      expect(
          find.byKey(const Key('matrix_cancel_verification')), findsOneWidget);
      await tester.tap(find.byKey(const Key('matrix_cancel_verification')));
      await tester.pump();

      verify(runner.cancelVerification).called(1);
    },
  );

  testWidgets('displays device display name from unverified list',
      (tester) async {
    final runner = MockKeyVerificationRunner();
    final mockDeviceKeys = MockDeviceKeys();

    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('My Pixel');
    when(() => mockMatrixService.getUnverifiedDevices())
        .thenReturn([mockDeviceKeys]);
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

    expect(find.text('My Pixel'), findsOneWidget);
  });

  testWidgets(
    'auto-accept failure keeps verify button visible',
    (tester) async {
      final runner = MockKeyVerificationRunner();

      when(() => runner.lastStep).thenReturn('');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(runner.acceptVerification).thenThrow(Exception('network error'));

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

      // Verify button should still be visible as fallback
      expect(find.text('Verify'), findsOneWidget);
    },
  );
}

class MockDeviceKeys extends Mock implements DeviceKeys {}
