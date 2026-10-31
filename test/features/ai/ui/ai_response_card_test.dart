import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_card.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../test_helper.dart';

void main() {
  final testDateTime = DateTime(2025);
  final response = AiResponseEntry(
    meta: Metadata(
      id: 'card-response-id',
      dateFrom: testDateTime,
      dateTo: testDateTime,
      createdAt: testDateTime,
      updatedAt: testDateTime,
    ),
    data: const AiResponseData(
      model: 'penguin-model-1',
      temperature: 0.7,
      systemMessage: 'System',
      prompt: 'Prompt',
      thoughts: '',
      response: 'The colony counted 42 sardines.',
      type: AiResponseType.imageAnalysis,
    ),
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    ThemeData? theme,
    Widget? header,
    Widget? body,
    bool? collapsed,
    VoidCallback? onToggleCollapsed,
  }) {
    return tester.pumpWidget(
      WidgetTestBench(
        theme: theme,
        child: AiResponseCard(
          aiResponse: response,
          header: header,
          body: body,
          collapsed: collapsed,
          onToggleCollapsed: onToggleCollapsed,
        ),
      ),
    );
  }

  BoxDecoration cardDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AiResponseCard),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  for (final (name, theme, tokens) in [
    ('light', DesignSystemTheme.light(), dsTokensLight),
    ('dark', DesignSystemTheme.dark(), dsTokensDark),
  ]) {
    group('in the $name theme', () {
      testWidgets(
        'paints the half-strength aiCard tint with the soft accent hairline '
        'and no shadow',
        (tester) async {
          await pumpCard(tester, theme: theme, body: const Text('Body'));

          final decoration = cardDecoration(tester);
          final ai = tokens.colors.aiCard;
          expect(decoration.color, ai.background.withValues(alpha: 0.5));
          expect((decoration.border! as Border).top.color, ai.borderSoft);
          expect(
            decoration.borderRadius,
            BorderRadius.circular(tokens.radii.l),
          );
          expect(decoration.boxShadow, isNull);
        },
      );

      testWidgets('draws the toggle in the AI accent color', (tester) async {
        await pumpCard(
          tester,
          theme: theme,
          collapsed: true,
          onToggleCollapsed: () {},
        );

        final accent = tokens.colors.aiCard.accent;
        final icon = tester.widget<Icon>(find.byIcon(LottiIcons.expand));
        expect(icon.color, accent);
        final label = tester.widget<Text>(find.text('Show more'));
        expect(label.style?.color, accent);
      });

      testWidgets('bodyStyle is the body.bodySmall measure in AI body text', (
        tester,
      ) async {
        await pumpCard(tester, theme: theme);

        final style = AiResponseCard.bodyStyle(
          tester.element(find.byType(AiResponseCard)),
        );
        final bodySmall = tokens.typography.styles.body.bodySmall;
        expect(style.fontSize, bodySmall.fontSize);
        expect(style.fontWeight, bodySmall.fontWeight);
        expect(style.color, tokens.colors.aiCard.bodyText);
      });
    });
  }

  testWidgets('lays out header, body, then the caption naming the model', (
    tester,
  ) async {
    await pumpCard(
      tester,
      header: const Text('Header'),
      body: const Text('Body'),
    );

    final headerY = tester.getTopLeft(find.text('Header')).dy;
    final bodyY = tester.getTopLeft(find.text('Body')).dy;
    final captionY = tester.getTopLeft(find.byType(AiAttributionSummary)).dy;
    expect(headerY, lessThan(bodyY));
    expect(bodyY, lessThan(captionY));

    final caption = tester.widget<AiAttributionSummary>(
      find.byType(AiAttributionSummary),
    );
    expect(caption.asCaption, isTrue);
    expect(caption.artifact.id, 'card-response-id');
    expect(caption.unrecordedModel, 'penguin-model-1');
  });

  for (final (name, theme, tokens) in [
    ('light', DesignSystemTheme.light(), dsTokensLight),
    ('dark', DesignSystemTheme.dark(), dsTokensDark),
  ]) {
    testWidgets(
      'unframed keeps the AI text treatment but draws no surface ($name)',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            theme: theme,
            child: AiResponseCard(
              aiResponse: response,
              framed: false,
              body: const Text('Body'),
              collapsed: true,
              onToggleCollapsed: () {},
            ),
          ),
        );

        final decorated = find.descendant(
          of: find.byType(AiResponseCard),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration != null,
          ),
        );
        expect(decorated, findsNothing);
        expect(
          tester.getTopLeft(find.text('Body')),
          tester.getTopLeft(find.byType(AiResponseCard)),
          reason: 'No inset: the entry card around it already pads it.',
        );
        final label = tester.widget<Text>(find.text('Show more'));
        expect(label.style?.color, tokens.colors.aiCard.accent);
        expect(find.byType(AiAttributionSummary), findsOneWidget);
      },
    );
  }

  testWidgets('without a collapse state there is no toggle', (tester) async {
    await pumpCard(tester, body: const Text('Body'));

    expect(find.byKey(AiResponseCard.collapseToggleKey), findsNothing);
  });

  testWidgets('the toggle labels the state and reports taps', (tester) async {
    var taps = 0;
    await pumpCard(tester, collapsed: false, onToggleCollapsed: () => taps++);

    expect(find.text('Show less'), findsOneWidget);
    expect(find.byIcon(LottiIcons.collapse), findsOneWidget);

    await tester.tap(find.byKey(AiResponseCard.collapseToggleKey));
    expect(taps, 1);
  });
}
