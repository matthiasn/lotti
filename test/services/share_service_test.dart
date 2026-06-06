import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/share_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// Transitive via share_plus; only the platform interface exposes the
// settable instance seam.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _MockSharePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements SharePlatform {}

void main() {
  late _MockSharePlatform platform;

  setUpAll(() {
    registerFallbackValue(ShareParams(text: 'fallback'));
    // SharePlus.instance is a lazy static that captures SharePlatform.instance
    // on first access, so the platform double must be installed once for the
    // whole file rather than per test.
    platform = _MockSharePlatform();
    SharePlatform.instance = platform;
  });

  setUp(() {
    reset(platform);
    when(() => platform.share(any())).thenAnswer(
      (_) async => const ShareResult('ok', ShareResultStatus.success),
    );
  });

  test('shareText forwards text and subject as ShareParams', () async {
    await ShareService.instance.shareText(
      text: 'hello world',
      subject: 'greeting',
    );

    final params =
        verify(() => platform.share(captureAny())).captured.single
            as ShareParams;
    expect(params.text, 'hello world');
    expect(params.subject, 'greeting');
  });

  test('shareText omits the subject when none is given', () async {
    await ShareService.instance.shareText(text: 'just text');

    final params =
        verify(() => platform.share(captureAny())).captured.single
            as ShareParams;
    expect(params.text, 'just text');
    expect(params.subject, isNull);
  });
}
