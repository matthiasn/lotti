import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppClipboard default (test env fallback)', () {
    late AppClipboard service;
    String? stored;

    setUp(() async {
      service = makeSuperClipboardService();
      // Mock platform clipboard channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map;
              stored = args['text'] as String?;
              return null;
            }
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': stored};
            }
            return null;
          });
      stored = '';
    });

    tearDown(() {
      // Clear the mock to avoid affecting other tests
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('writes plain text via Flutter Clipboard in tests', () async {
      await service.writePlainText('Hello');
      final data = await Clipboard.getData('text/plain');
      expect(data?.text, 'Hello');
    });

    test('does not write when text is empty', () async {
      stored = 'prev';
      await service.writePlainText('');
      final data = await Clipboard.getData('text/plain');
      expect(data?.text, 'prev');
    });

    test('keeps newlines as-is', () async {
      const value = 'line1\nline2';
      await service.writePlainText(value);
      final data = await Clipboard.getData('text/plain');
      expect(data?.text, value);
    });
  });

  group('appClipboardProvider', () {
    test('exposes a working AppClipboard that writes plain text', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      String? stored;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              stored = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final clipboard = container.read(appClipboardProvider);
      await clipboard.writePlainText('Provider value');

      // The provider returns a real AppClipboard wired to writePlainText; in the
      // test env that routes through Flutter's Clipboard channel.
      expect(stored, 'Provider value');
    });

    test(
      'honors the empty-string guard from makeSuperClipboardService',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        String? stored = 'untouched';
        var setDataCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                setDataCalls++;
                stored = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final clipboard = container.read(appClipboardProvider);
        await clipboard.writePlainText('');

        // The provider wires through makeSuperClipboardService, whose empty-string
        // guard short-circuits before touching the platform channel.
        expect(setDataCalls, 0);
        expect(stored, 'untouched');
      },
    );
  });
}
