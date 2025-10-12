import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppClipboard default (test env fallback)', () {
    late AppClipboard service;
    String? stored;

    setUp(() async {
      service = makeSuperClipboardService();
      // Mock platform clipboard channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall call) async {
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
}
