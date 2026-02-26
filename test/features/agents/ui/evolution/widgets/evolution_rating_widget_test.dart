import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_rating_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({double initialRating = 0.5}) {
    return makeTestableWidgetWithScaffold(
      EvolutionRatingWidget(
        onRatingChanged: (_) {},
        initialRating: initialRating,
      ),
    );
  }

  group('EvolutionRatingWidget', () {
    testWidgets('shows rating prompt text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionRatingWidget));
      expect(
        find.text(context.messages.agentEvolutionRatingPrompt),
        findsOneWidget,
      );
    });

    testWidgets('shows label anchors', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionRatingWidget));
      expect(
        find.text(context.messages.agentEvolutionRatingNeedsWork),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionRatingAdequate),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionRatingExcellent),
        findsOneWidget,
      );
    });

    testWidgets('shows initial rating as percentage', (tester) async {
      await tester.pumpWidget(buildSubject(initialRating: 0.7));
      await tester.pumpAndSettle();

      expect(find.text('70%'), findsOneWidget);
    });

    testWidgets('contains a slider widget', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.5);
    });
  });
}
