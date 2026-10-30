import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/on_device_embedding/embedding_model.dart';
import 'package:lotti/features/ai/ui/settings/embedding_model_section.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockOnDeviceEmbeddingRepository repository;
  late ValueNotifier<bool> ready;
  late List<Uri> opened;

  setUp(() {
    repository = MockOnDeviceEmbeddingRepository();
    ready = ValueNotifier(false);
    opened = [];
    when(() => repository.model).thenReturn(embeddingGemma);
    when(() => repository.isInstalling).thenReturn(false);
  });
  tearDown(() => ready.dispose());

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        EmbeddingModelSection(
          repository: repository,
          ready: ready,
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pump();
  }

  void stubInstalled({required bool installed}) =>
      when(repository.isInstalled).thenAnswer((_) async => installed);

  testWidgets('follows a download that is already running', (tester) async {
    final download = Completer<void>();
    when(() => repository.isInstalling).thenReturn(true);
    when(
      () => repository.install(onProgress: any(named: 'onProgress')),
    ).thenAnswer((invocation) {
      (invocation.namedArguments[#onProgress] as void Function(double))(0.6);
      return download.future;
    });

    await pumpSection(tester);
    await tester.pump();

    final bar = tester.widget<DesignSystemProgressBar>(
      find.byType(DesignSystemProgressBar),
    );
    expect(bar.value, 0.6);
    expect(find.text('Download'), findsNothing);
    verifyNever(repository.isInstalled);

    download.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('On this device'), findsOneWidget);
    expect(ready.value, isTrue);
  });

  testWidgets('a joined download that fails offers to try again', (
    tester,
  ) async {
    when(() => repository.isInstalling).thenReturn(true);
    var attempts = 0;
    when(
      () => repository.install(onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async {
      if (attempts++ == 0) throw Exception('offline');
    });

    await pumpSection(tester);
    await tester.pump();
    await tester.pump();

    expect(find.byType(DesignSystemSpinner), findsNothing);
    expect(
      find.text(
        "The download didn't finish. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(ready.value, isFalse);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('On this device'), findsOneWidget);
    expect(ready.value, isTrue);
  });

  testWidgets('shows a spinner while it checks for the model', (tester) async {
    final check = Completer<bool>();
    when(repository.isInstalled).thenAnswer((_) => check.future);

    await pumpSection(tester);

    expect(find.byType(DesignSystemSpinner), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    check.complete(true);
    await tester.pump();
    expect(find.byType(DesignSystemSpinner), findsNothing);
  });

  testWidgets('a check that fails says so and can be run again', (
    tester,
  ) async {
    var checks = 0;
    when(repository.isInstalled).thenAnswer((_) async {
      if (checks++ == 0) throw const FileSystemException('unreadable');
      return true;
    });

    await pumpSection(tester);

    expect(find.byType(DesignSystemSpinner), findsNothing);
    expect(
      find.text("Couldn't check the model on this device."),
      findsOneWidget,
    );
    expect(ready.value, isFalse);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(checks, 2);
    expect(find.textContaining("Couldn't check"), findsNothing);
    expect(find.text('On this device'), findsOneWidget);
    expect(ready.value, isTrue);
  });

  testWidgets('offers the download, with its size, purpose and terms', (
    tester,
  ) async {
    stubInstalled(installed: false);

    await pumpSection(tester);

    expect(find.text('EmbeddingGemma 300M'), findsOneWidget);
    expect(find.text('217.6 MB'), findsOneWidget);
    expect(
      find.text(
        'Search by meaning runs on this device. Download the model once to '
        'use it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Download'), findsOneWidget);
    expect(ready.value, isFalse);

    await tester.tap(find.text('Gemma Terms of Use'));
    expect(opened, [Uri.parse('https://ai.google.dev/gemma/terms')]);
  });

  testWidgets('an installed model is ready and needs no explanation', (
    tester,
  ) async {
    stubInstalled(installed: true);

    await pumpSection(tester);

    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    expect(find.textContaining('Search by meaning'), findsNothing);
    expect(find.text('Gemma Terms of Use'), findsOneWidget);
    expect(ready.value, isTrue);
  });

  testWidgets('downloads with progress, then is ready', (tester) async {
    stubInstalled(installed: false);
    final download = Completer<void>();
    when(
      () => repository.install(onProgress: any(named: 'onProgress')),
    ).thenAnswer((invocation) {
      (invocation.namedArguments[#onProgress] as void Function(double))(0.42);
      return download.future;
    });

    await pumpSection(tester);
    await tester.tap(find.text('Download'));
    await tester.pump();

    final bar = tester.widget<DesignSystemProgressBar>(
      find.byType(DesignSystemProgressBar),
    );
    expect(bar.value, 0.42);
    expect(bar.progressText, '42%');
    expect(bar.label, 'Downloading');
    // The bar stands for the download; the button is gone meanwhile.
    expect(find.text('Download'), findsNothing);
    expect(ready.value, isFalse);

    download.complete();
    await tester.pump();

    expect(find.byType(DesignSystemProgressBar), findsNothing);
    expect(find.text('On this device'), findsOneWidget);
    expect(ready.value, isTrue);
  });

  testWidgets('a failed download says so and can be tried again', (
    tester,
  ) async {
    stubInstalled(installed: false);
    var attempts = 0;
    when(
      () => repository.install(onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async {
      if (attempts++ == 0) throw Exception('offline');
    });

    await pumpSection(tester);
    await tester.tap(find.text('Download'));
    await tester.pump();

    expect(
      find.text(
        "The download didn't finish. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.byType(DesignSystemProgressBar), findsNothing);
    expect(ready.value, isFalse);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.textContaining("didn't finish"), findsNothing);
    expect(ready.value, isTrue);
  });
}
