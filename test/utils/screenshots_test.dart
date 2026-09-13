import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../widget_test_utils.dart';

void main() {
  final capturedAt = DateTime(2026, 8, 15, 12, 34);
  late MockScreenshotHost host;
  late MockProcess process;
  late MockDomainLogger logger;

  Future<ImageData> capture() => withClock(
    Clock.fixed(capturedAt),
    () => takeScreenshot(host: host),
  );

  Future<void> advanceCapture(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  setUpAll(registerAllFallbackValues);
  setUp(() async {
    host = MockScreenshotHost();
    process = MockProcess();
    logger = MockDomainLogger();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(logger);
      },
    );
    when(() => host.operatingSystem).thenReturn('linux');
    when(() => host.shouldUsePortal).thenReturn(false);
    when(() => host.createDirectory(any())).thenAnswer(
      (_) async => '/documents/images/2026-08-15',
    );
    when(host.minimizeWindow).thenAnswer((_) async {});
    when(host.showWindow).thenAnswer((_) async {});
    when(() => host.run(any(), any())).thenAnswer(
      (_) async => ProcessResult(1, 0, '', ''),
    );
    when(
      () => host.start(
        any(),
        any(),
        workingDirectory: any(named: 'workingDirectory'),
      ),
    ).thenAnswer((_) async => process);
    when(() => host.forwardOutput(process)).thenAnswer((_) async {});
    when(() => process.exitCode).thenAnswer((_) async => 0);
    when(() => process.kill()).thenReturn(true);
  });
  tearDown(tearDownTestGetIt);

  test('default host drains stdout and stderr concurrently', () {
    fakeAsync((async) {
      final outputSink = MockStdout();
      final errorSink = MockStdout();
      final outputClosed = Completer<void>();
      final errorClosed = Completer<void>();
      final outputStream = Stream<List<int>>.value([1, 2]);
      final errorStream = Stream<List<int>>.value([3, 4]);
      when(() => process.stdout).thenAnswer((_) => outputStream);
      when(() => process.stderr).thenAnswer((_) => errorStream);
      when(
        () => outputSink.addStream(outputStream),
      ).thenAnswer((_) => outputClosed.future);
      when(
        () => errorSink.addStream(errorStream),
      ).thenAnswer((_) => errorClosed.future);
      var completed = false;
      IOOverrides.runZoned(
        () => unawaited(
          const ScreenshotHost().forwardOutput(process).then((_) {
            completed = true;
          }),
        ),
        stdout: () => outputSink,
        stderr: () => errorSink,
      );
      async.flushMicrotasks();
      verify(() => outputSink.addStream(outputStream)).called(1);
      verify(() => errorSink.addStream(errorStream)).called(1);
      expect(completed, isFalse);
      outputClosed.complete();
      async.flushMicrotasks();
      expect(completed, isFalse, reason: 'stderr has not finished');
      errorClosed.complete();
      async.flushMicrotasks();
      expect(completed, isTrue);
    });
  });

  group('command discovery', () {
    for (final exitCode in [0, 1, 127]) {
      test('uses which and treats exit code $exitCode correctly', () async {
        when(() => host.run(any(), any())).thenAnswer(
          (_) async => ProcessResult(1, exitCode, '', ''),
        );
        expect(await isCommandAvailable('scrot', host: host), exitCode == 0);
        verify(() => host.run('which', ['scrot'])).called(1);
      });
    }

    test('a process launch failure means unavailable', () async {
      when(() => host.run(any(), any())).thenAnswer(
        (_) async => throw const ProcessException('which', []),
      );
      expect(await isCommandAvailable('scrot', host: host), isFalse);
    });

    test('selects the first installed tool and stops searching', () async {
      when(() => host.run(any(), any())).thenAnswer((invocation) async {
        final arguments = invocation.positionalArguments[1] as List<String>;
        return ProcessResult(1, arguments.single == 'scrot' ? 0 : 1, '', '');
      });
      expect(await findAvailableScreenshotTool(host: host), 'scrot');
      verifyInOrder([
        () => host.run('which', ['spectacle']),
        () => host.run('which', ['gnome-screenshot']),
        () => host.run('which', ['scrot']),
      ]);
      verifyNoMoreInteractions(host);
    });

    test('returns null after exhausting all tools', () async {
      when(() => host.run(any(), any())).thenAnswer(
        (_) async => ProcessResult(1, 1, '', ''),
      );
      expect(await findAvailableScreenshotTool(host: host), isNull);
      verifyInOrder([
        () => host.run('which', ['spectacle']),
        () => host.run('which', ['gnome-screenshot']),
        () => host.run('which', ['scrot']),
        () => host.run('which', ['import']),
      ]);
      verifyNoMoreInteractions(host);
    });
  });

  group('Linux capture', () {
    const argumentsByTool = {
      'spectacle': ['-f', '-b', '-n', '-o', 'capture.jpg'],
      'gnome-screenshot': ['-f', 'capture.jpg'],
      'scrot': ['capture.jpg'],
      'import': ['-window', 'root', 'capture.jpg'],
    };
    for (final tool in argumentsByTool.entries) {
      test('${tool.key} receives the filename and working directory', () async {
        await takeLinuxScreenshot(
          tool.key,
          'capture.jpg',
          '/documents/images',
          host: host,
        );
        verify(
          () => host.start(
            tool.key,
            tool.value,
            workingDirectory: '/documents/images',
          ),
        ).called(1);
        verify(() => host.forwardOutput(process)).called(1);
        verifyNever(() => process.kill());
      });
    }

    test('rejects unknown tools before launching a process', () async {
      await expectLater(
        takeLinuxScreenshot('unknown', 'capture.jpg', '/documents', host: host),
        throwsA(
          isException.having(
            (e) => e.toString(),
            'message',
            contains('Unsupported screenshot tool'),
          ),
        ),
      );
      verifyZeroInteractions(host);
    });

    test('propagates launch errors', () async {
      const error = ProcessException('scrot', [], 'permission denied');
      when(
        () => host.start(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer((_) async => throw error);
      await expectLater(
        takeLinuxScreenshot('scrot', 'capture.jpg', '/documents', host: host),
        throwsA(same(error)),
      );
    });

    test('rejects a nonzero exit code', () async {
      when(() => process.exitCode).thenAnswer((_) async => 7);
      await expectLater(
        takeLinuxScreenshot('scrot', 'capture.jpg', '/documents', host: host),
        throwsA(
          isException.having(
            (e) => e.toString(),
            'message',
            allOf(contains('scrot'), contains('7')),
          ),
        ),
      );
    });

    test('kills a hung process at the timeout boundary', () {
      fakeAsync((async) {
        final exitCode = Completer<int>();
        when(() => process.exitCode).thenAnswer((_) => exitCode.future);
        Object? failure;
        unawaited(
          takeLinuxScreenshot(
            'scrot',
            'capture.jpg',
            '/documents',
            host: host,
          ).catchError((Object error) {
            failure = error;
          }),
        );
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 29));
        expect(failure, isNull);
        verifyNever(() => process.kill());
        async.elapse(const Duration(seconds: 1));
        expect(
          failure,
          isException.having(
            (e) => e.toString(),
            'message',
            contains('scrot timed out after 30s'),
          ),
        );
        verify(() => process.kill()).called(1);
        exitCode.complete(-1);
        async.flushMicrotasks();
      });
    });
  });

  group('capture workflow', () {
    test('uses the canonical documents-relative path', () {
      expect(screenshotRelativePath(capturedAt), '/images/2026-08-15/');
    });

    for (final os in ['linux', 'macos']) {
      testWidgets('$os captures metadata and restores the window', (
        tester,
      ) async {
        when(() => host.operatingSystem).thenReturn(os);
        final future = capture();
        await tester.pump();
        verify(host.minimizeWindow).called(1);
        verifyNever(
          () => host.start(
            any(),
            any(),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final result = await future;
        expect(result.capturedAt, capturedAt);
        expect(result.imageDirectory, '/images/2026-08-15/');
        expect(result.imageId, isNotEmpty);
        expect(result.imageFile, '${result.imageId}.screenshot.jpg');
        verify(() => host.createDirectory('/images/2026-08-15/')).called(1);
        verifyInOrder([
          () => host.start(
            os == 'linux' ? 'spectacle' : 'screencapture',
            os == 'linux'
                ? ['-f', '-b', '-n', '-o', result.imageFile]
                : ['-tjpg', result.imageFile],
            workingDirectory: '/documents/images/2026-08-15',
          ),
          () => host.forwardOutput(process),
          host.showWindow,
        ]);
      });

      testWidgets('$os times out even while process output stays open', (
        tester,
      ) async {
        when(() => host.operatingSystem).thenReturn(os);
        final output = Completer<void>();
        final exitCode = Completer<int>();
        when(
          () => host.forwardOutput(process),
        ).thenAnswer((_) => output.future);
        when(() => process.exitCode).thenAnswer((_) => exitCode.future);
        Object? failure;
        final future = capture().then<ImageData?>(
          (value) => value,
          onError: (Object error) {
            failure = error;
            return null;
          },
        );
        await advanceCapture(tester);
        await tester.pump(const Duration(seconds: 29));
        expect(failure, isNull);
        verifyNever(() => process.kill());
        await tester.pump(const Duration(seconds: 1));
        // Drain controlled effects even when the regression assertion fails.
        output.complete();
        exitCode.complete(-1);
        await tester.pump();
        await future;
        expect(
          failure,
          isException.having(
            (e) => e.toString(),
            'message',
            contains('timed out after 30s'),
          ),
        );
        verify(() => process.kill()).called(1);
        verify(host.showWindow).called(1);
      });

      testWidgets('$os restores the window after capture fails', (
        tester,
      ) async {
        when(() => host.operatingSystem).thenReturn(os);
        when(() => process.exitCode).thenAnswer((_) async => 9);
        final assertion = expectLater(
          capture(),
          throwsA(
            isException.having(
              (e) => e.toString(),
              'message',
              contains('9'),
            ),
          ),
        );
        await advanceCapture(tester);
        await assertion;
        verify(host.showWindow).called(1);
        verify(
          () => logger.error(
            LogDomain.screenshots,
            any(),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    }

    testWidgets('reports missing Linux tools and restores the window', (
      tester,
    ) async {
      when(
        () => host.run(any(), any()),
      ).thenAnswer((_) async => ProcessResult(1, 1, '', ''));
      final assertion = expectLater(
        capture(),
        throwsA(
          isException.having(
            (e) => e.toString(),
            'message',
            contains('spectacle, gnome-screenshot, scrot, import'),
          ),
        ),
      );
      await advanceCapture(tester);
      await assertion;
      verifyNever(
        () => host.start(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      );
      verify(host.showWindow).called(1);
    });

    testWidgets('rejects unsupported platforms and restores the window', (
      tester,
    ) async {
      when(() => host.operatingSystem).thenReturn('windows');
      final assertion = expectLater(
        capture(),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('windows'),
          ),
        ),
      );
      await advanceCapture(tester);
      await assertion;
      verify(host.showWindow).called(1);
    });

    testWidgets('restoration failure preserves the successful capture', (
      tester,
    ) async {
      final error = StateError('window gone');
      when(host.showWindow).thenAnswer((_) async => throw error);
      final future = capture();
      await advanceCapture(tester);
      expect((await future).imageDirectory, '/images/2026-08-15/');
      verify(
        () => logger.error(
          LogDomain.screenshots,
          error,
          subDomain: 'window_restoration',
        ),
      ).called(1);
    });

    testWidgets('restoration failure preserves the original capture error', (
      tester,
    ) async {
      final captureError = StateError('cannot create directory');
      when(
        () => host.createDirectory(any()),
      ).thenAnswer((_) async => throw captureError);
      when(
        host.showWindow,
      ).thenAnswer((_) async => throw StateError('window gone'));
      final assertion = expectLater(capture(), throwsA(same(captureError)));
      await tester.pump();
      await assertion;
      verify(host.showWindow).called(1);
      verifyNever(host.minimizeWindow);
    });

    testWidgets(
      'portal success returns matching metadata without a CLI capture',
      (tester) async {
        when(() => host.shouldUsePortal).thenReturn(true);
        when(host.isPortalAvailable).thenAnswer((_) async => true);
        when(
          () => host.captureWithPortal(
            directory: any(named: 'directory'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => '/documents/capture.jpg');
        final future = capture();
        await tester.pump();
        final result = await future;
        expect(result.capturedAt, capturedAt);
        expect(result.imageDirectory, '/images/2026-08-15/');
        expect(result.imageFile, '${result.imageId}.screenshot.jpg');
        verify(
          () => host.captureWithPortal(
            directory: '/documents/images/2026-08-15',
            filename: result.imageFile,
          ),
        ).called(1);
        verifyNever(host.minimizeWindow);
        verifyNever(() => host.run(any(), any()));
        verifyNever(
          () => host.start(
            any(),
            any(),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        );
        verify(host.showWindow).called(1);
      },
    );

    for (final available in [false, true]) {
      testWidgets(
        'portal ${available ? 'cancellation' : 'unavailability'} falls back to CLI',
        (tester) async {
          when(() => host.shouldUsePortal).thenReturn(true);
          when(host.isPortalAvailable).thenAnswer((_) async => available);
          when(
            () => host.captureWithPortal(
              directory: any(named: 'directory'),
              filename: any(named: 'filename'),
            ),
          ).thenAnswer((_) async => null);
          final future = capture();
          await advanceCapture(tester);
          final result = await future;
          verify(
            () => host.start('spectacle', [
              '-f',
              '-b',
              '-n',
              '-o',
              result.imageFile,
            ], workingDirectory: '/documents/images/2026-08-15'),
          ).called(1);
          verify(host.minimizeWindow).called(1);
          verify(host.showWindow).called(1);
          verify(
            () => logger.error(
              LogDomain.screenshots,
              any(),
              subDomain: 'portal_fallback',
            ),
          ).called(1);
        },
      );
    }
  });
}
