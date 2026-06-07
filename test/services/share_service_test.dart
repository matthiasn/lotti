import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/share_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
// Transitive via share_plus; only the platform interface exposes the
// settable instance seam.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _MockSharePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements SharePlatform {}

void main() {
  late _MockSharePlatform platform;
  late ShareService service;

  setUpAll(() {
    registerFallbackValue(ShareParams(text: 'fallback'));
  });

  setUp(() {
    platform = _MockSharePlatform();
    // Bind the service to its own SharePlus built around the mock platform.
    // Going through `SharePlus.instance` would be order-dependent in the
    // batched suite: that lazy static captures whatever SharePlatform was
    // installed when the FIRST test in the isolate touched it.
    service = ShareService(sharePlus: SharePlus.custom(platform));
    when(() => platform.share(any())).thenAnswer(
      (_) async => const ShareResult('ok', ShareResultStatus.success),
    );
  });

  test('shareText forwards text and subject as ShareParams', () async {
    await service.shareText(
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
    await service.shareText(text: 'just text');

    final params =
        verify(() => platform.share(captureAny())).captured.single
            as ShareParams;
    expect(params.text, 'just text');
    expect(params.subject, isNull);
  });
}
