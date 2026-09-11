import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference.dart';

void main() {
  group('LottiTool', () {
    test('compares its JSON Schema structurally, not by identity', () {
      // Tool lists are rebuilt per turn, so equality has to see through the
      // freshly constructed schema maps.
      expect(
        const LottiTool(name: 'lookup', parameters: {'type': 'object'}),
        const LottiTool(name: 'lookup', parameters: {'type': 'object'}),
      );
      expect(
        const LottiTool(
          name: 'lookup',
          parameters: {'type': 'object'},
        ).hashCode,
        const LottiTool(
          name: 'lookup',
          parameters: {'type': 'object'},
        ).hashCode,
      );
      expect(
        const LottiTool(name: 'lookup', parameters: {'type': 'object'}),
        isNot(const LottiTool(name: 'lookup', parameters: {'type': 'string'})),
      );
    });

    test('a tool with no parameters differs from one with an empty schema', () {
      // Null omits the field on the wire; `{}` sends an empty schema, and
      // providers disagree about accepting it.
      expect(
        const LottiTool(name: 'ping'),
        isNot(const LottiTool(name: 'ping', parameters: {})),
      );
      expect(const LottiTool(name: 'ping').parameters, isNull);
    });

    test('copyWith replaces only the named fields', () {
      const tool = LottiTool(name: 'lookup', description: 'Looks things up');
      expect(tool.copyWith(name: 'search').name, 'search');
      expect(tool.copyWith(name: 'search').description, 'Looks things up');
    });
  });

  group('LottiToolChoice', () {
    test('each policy equals only itself', () {
      const policies = [
        LottiToolChoice.auto(),
        LottiToolChoice.none(),
        LottiToolChoice.required(),
        LottiToolChoice.specific('lookup'),
      ];
      for (var i = 0; i < policies.length; i++) {
        for (var j = 0; j < policies.length; j++) {
          if (i == j) {
            expect(policies[i], policies[j]);
          } else {
            expect(policies[i], isNot(policies[j]));
          }
        }
      }
    });

    test('two specific choices differ by the tool they name', () {
      expect(
        const LottiToolChoice.specific('a'),
        isNot(const LottiToolChoice.specific('b')),
      );
      expect(
        const LottiToolChoice.specific('a'),
        const LottiToolChoice.specific('a'),
      );
    });

    test('only the specific variant pins the call to one tool', () {
      // `conversation_repository` branches on exactly this to decide whether a
      // staging strategy may widen the turn's tool list.
      expect(
        const LottiToolChoice.specific('a'),
        isA<LottiToolChoiceSpecific>(),
      );
      expect(
        const LottiToolChoice.auto(),
        isNot(isA<LottiToolChoiceSpecific>()),
      );
      expect(
        const LottiToolChoice.required(),
        isNot(isA<LottiToolChoiceSpecific>()),
      );
    });
  });
}
