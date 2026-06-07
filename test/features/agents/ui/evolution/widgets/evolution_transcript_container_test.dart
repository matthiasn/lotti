import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcript_container.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpContainer(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        EvolutionTranscriptContainer(child: child),
      ),
    );
    await tester.pump();
  }

  group('EvolutionTranscriptContainer', () {
    testWidgets('renders its child inside the styled surface', (tester) async {
      await pumpContainer(tester, const Text('partial transcript…'));

      expect(find.text('partial transcript…'), findsOneWidget);

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('partial transcript…'),
          matching: find.byType(Container),
        ),
      );

      final context = tester.element(
        find.byType(EvolutionTranscriptContainer),
      );
      final colorScheme = Theme.of(context).colorScheme;
      final tokens = context.designTokens;

      // Surface chrome: themed fill, 22px radius, soft outline + shadow.
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, colorScheme.surface);
      expect(decoration.borderRadius, BorderRadius.circular(22));
      expect(
        (decoration.border! as Border).top.color,
        colorScheme.outlineVariant.withValues(alpha: 0.5),
      );
      expect(decoration.boxShadow, hasLength(1));

      // Spacing comes from the design-system tokens.
      expect(
        container.padding,
        EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step4,
        ),
      );
    });

    testWidgets('caps the transcript height at 120 logical pixels', (
      tester,
    ) async {
      // A child taller than the cap must be constrained, not overflow.
      await pumpContainer(
        tester,
        const SizedBox(height: 500, width: 100),
      );

      final box = tester.renderObject<RenderBox>(
        find.byType(EvolutionTranscriptContainer),
      );
      expect(box.size.height, 120);
      expect(tester.takeException(), isNull);
    });
  });
}
