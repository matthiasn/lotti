import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';

void main() {
  group('maskApiKey', () {
    test('canonical examples', () {
      expect(maskApiKey(''), '');
      expect(maskApiKey('   '), '');
      expect(maskApiKey('ab'), '\u2022\u2022');
      expect(maskApiKey('abcd'), '\u2022\u2022\u2022\u2022');
      expect(maskApiKey('sk-12345678'), '\u2022\u2022\u2022\u2022 5678');
    });

    glados.Glados(
      glados.any.apiKeyScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('masks everything except the trailing four characters', (
      scenario,
    ) {
      final masked = maskApiKey(scenario.padded);
      final trimmed = scenario.key;

      // Whitespace-insensitive: padding never changes the result.
      expect(masked, maskApiKey(trimmed));

      if (trimmed.isEmpty) {
        expect(masked, '');
      } else if (trimmed.length <= 4) {
        // Fully masked: same length, no character of the key revealed.
        expect(masked, '\u2022' * trimmed.length);
      } else {
        // Only the last four characters are revealed.
        expect(masked, startsWith('\u2022\u2022\u2022\u2022 '));
        expect(masked.substring(5), trimmed.substring(trimmed.length - 4));
        // The secret prefix never leaks into the output.
        final prefix = trimmed.substring(0, trimmed.length - 4);
        if (prefix.length >= 5) {
          expect(masked.contains(prefix), isFalse);
        }
      }
    }, tags: 'glados');
  });
}

/// Deterministic API-key scenario: a key drawn from a mixed charset plus
/// whitespace padding, both derived from (length, seed) ints.
class _ApiKeyScenario {
  _ApiKeyScenario(int length, int seed) {
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.writeCharCode(
        charset.codeUnitAt((seed + i * 31) % charset.length),
      );
    }
    key = buffer.toString();
    padded = '${' ' * (seed % 3)}$key${' ' * ((seed ~/ 3) % 3)}';
  }

  late final String key;
  late final String padded;
}

extension _AnyApiKey on glados.Any {
  glados.Generator<_ApiKeyScenario> get apiKeyScenario => combine2(
    glados.IntAnys(this).intInRange(0, 40),
    glados.IntAnys(this).intInRange(0, 1 << 20),
    _ApiKeyScenario.new,
  );
}
