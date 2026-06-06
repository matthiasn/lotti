import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';

void main() {
  group('agentCardDarkGradient', () {
    test(
      'builds a two-stop gradient from the dark surface toward the accent',
      () {
        const accent = Color(0xFF1CB0F6);
        final gradient = agentCardDarkGradient(accent);

        expect(gradient.colors, hasLength(2));
        expect(gradient.colors.first, AgentPalette.surfaceDarkElevated);
        expect(
          gradient.colors.last,
          Color.lerp(AgentPalette.surfaceDarkElevated, accent, 0.08),
        );
        expect(gradient.begin, Alignment.topLeft);
        expect(gradient.end, Alignment.bottomRight);
      },
    );

    test('different accents tint the second stop differently', () {
      final blue = agentCardDarkGradient(AgentPalette.blue);
      final red = agentCardDarkGradient(AgentPalette.red);

      expect(blue.colors.last, isNot(red.colors.last));
      // The tint is subtle: both stay close to the base surface.
      expect(blue.colors.first, red.colors.first);
    });
  });
}
