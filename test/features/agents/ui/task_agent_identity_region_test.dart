import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  const route = InferenceRouteSnapshot(
    providerModelId: 'qwen3.5-plus',
    modelName: 'Qwen 3.5 Plus',
    publisherName: 'Alibaba',
    servingProviderType: InferenceProviderType.melious,
    servingProviderName: 'Melious.ai',
    runtimeSettings: {},
  );
  const routeLabel = 'Qwen 3.5 Plus · Alibaba · via Melious.ai';

  // The route that wrote an older report — different from [route], so the
  // region renders two distinct identity lines.
  const priorRoute = InferenceRouteSnapshot(
    providerModelId: 'glm-5.2',
    modelName: 'GLM 5.2',
    publisherName: 'Z.ai',
    servingProviderType: InferenceProviderType.openRouter,
    servingProviderName: 'OpenRouter',
    runtimeSettings: {},
  );
  const priorRouteLabel = 'GLM 5.2 · Z.ai · via OpenRouter';

  /// Pumps the region at an explicit width so the truncation and ink-extent
  /// assertions can address a known measure. Without [width] the region takes
  /// the default phone bench width.
  Future<void> pumpRegion(
    WidgetTester tester, {
    required TaskAgentModelIdentityViewData data,
    VoidCallback? onSetupTap,
    double? width,
  }) {
    if (width != null) {
      // MediaQuery alone does not resize the surface — the render view does,
      // and a SizedBox wider than the view is simply clamped to it.
      tester.view
        ..physicalSize = Size(width, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    return tester.pumpWidget(
      makeTestableWidget(
        TaskAgentIdentityRegion(
          data: data,
          onSetupTap: onSetupTap ?? () {},
        ),
      ),
    );
  }

  Finder setupRowInk() => find.descendant(
    of: find.byType(TaskAgentIdentityRegion),
    matching: find.byType(InkWell),
  );

  /// Whether [finder]'s text was truncated rather than wrapped.
  bool isTruncated(WidgetTester tester, Finder finder) =>
      tester.renderObject<RenderParagraph>(finder).didExceedMaxLines;

  testWidgets('combined row is tappable, accessible, and at least step6 high', (
    tester,
  ) async {
    var taps = 0;
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.combined,
        currentRoute: route,
        reportRoute: route,
      ),
      onSetupTap: () => taps++,
    );

    expect(find.text(routeLabel), findsOneWidget);
    final inkWell = setupRowInk();
    final context = tester.element(find.byType(TaskAgentIdentityRegion));
    expect(
      tester.getSize(inkWell).height,
      greaterThanOrEqualTo(context.designTokens.spacing.step6),
    );
    for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
      expect(icon.color, context.designTokens.colors.aiCard.metaText);
    }
    expect(
      find.bySemanticsLabel(
        RegExp('This report and current setup use Qwen 3.5 Plus'),
      ),
      findsOneWidget,
    );
    await tester.tap(inkWell);
    expect(taps, 1);
  });

  testWidgets('split state keeps the historical report attribution line', (
    tester,
  ) async {
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.split,
        currentRoute: route,
        reportAttributionUnavailable: true,
      ),
    );

    expect(find.text(routeLabel), findsOneWidget);
    expect(find.text('This report'), findsOneWidget);
    expect(find.text('Attribution unavailable'), findsOneWidget);
    // "Current setup" wording moved into the semantics label; visually the
    // placement and glyph carry it.
    expect(find.text('Current setup'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Current setup: Qwen 3.5 Plus')),
      findsOneWidget,
    );
  });

  testWidgets('the card keeps its bottom margin with or without attribution', (
    tester,
  ) async {
    // The two states differ only in whether the attribution row exists, so
    // the air under the last line must not: otherwise the card's bottom
    // margin visibly changes as a report ages into a different route.
    //
    // Measured ink-to-ink, not by reading the declared padding back — an
    // earlier revision kept the *declared* geometry constant and still
    // shifted on screen, because the tappable row's minimum-height ink box
    // centres its glyph and contributes optical air that a bare text row
    // does not.
    double trailingAir(WidgetTester tester) {
      final region = find.byType(TaskAgentIdentityRegion);
      final lastText = find.descendant(of: region, matching: find.byType(Text));
      final bottomOfInk = tester.widgetList<Text>(lastText).isEmpty
          ? 0.0
          : tester.getRect(lastText.last).bottom;
      return tester.getRect(region).bottom - bottomOfInk;
    }

    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.combined,
        currentRoute: route,
        reportRoute: route,
      ),
      width: 600,
    );
    final withoutAttribution = trailingAir(tester);

    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.split,
        currentRoute: route,
        reportRoute: priorRoute,
      ),
      width: 600,
    );
    expect(find.text(priorRouteLabel), findsOneWidget);
    final withAttribution = trailingAir(tester);

    expect(
      withAttribution,
      moreOrLessEquals(withoutAttribution, epsilon: 1),
      reason:
          'attribution present: $withAttribution, absent: $withoutAttribution',
    );
  });

  testWidgets('no setup is a visible error with a concrete recovery hint', (
    tester,
  ) async {
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.disabled,
      ),
    );

    expect(
      find.text(
        'Choose a saved setup or thinking model before this agent can run.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LottiIcons.error), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('No AI setup')),
      findsOneWidget,
    );
  });

  testWidgets('broken setup keeps historical report attribution visible', (
    tester,
  ) async {
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.broken,
        reportRoute: route,
      ),
    );

    expect(find.text('Selected AI setup is unavailable'), findsOneWidget);
    expect(find.text('This report'), findsOneWidget);
    expect(find.text(routeLabel), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Current setup. Selected AI setup is unavailable',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the tappable row hugs its content instead of the full width', (
    tester,
  ) async {
    // Comfortably wider than the row's natural width. The test font advances
    // ~1em per glyph, so a 40-character route measures far wider here than it
    // does in the app — a realistic 420px measure would fill and prove
    // nothing.
    const width = 900.0;
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.combined,
        currentRoute: route,
        reportRoute: route,
      ),
      width: width,
    );

    final tokens = tester
        .element(find.byType(TaskAgentIdentityRegion))
        .designTokens;
    final ink = tester.getRect(setupRowInk());

    // The whole point: the hover/press/tap band stops at the chevron rather
    // than running the width of the footer it sits in.
    expect(tester.getSize(find.byType(TaskAgentIdentityRegion)).width, width);
    expect(ink.width, lessThan(width));
    expect(
      ink.right,
      moreOrLessEquals(
        tester.getRect(find.byIcon(LottiIcons.chevronRight)).right +
            tokens.spacing.step2,
        epsilon: 0.5,
      ),
    );
    // ...and it is inset from the glyph, so the rounded ink corners do not
    // clip into the icon.
    expect(
      tester.getRect(find.byIcon(LottiIcons.reasoning)).left - ink.left,
      moreOrLessEquals(tokens.spacing.step2, epsilon: 0.5),
    );
    expect(ink.height, greaterThanOrEqualTo(tokens.spacing.step6));
  });

  testWidgets('a squeezed route sheds whole segments, not characters', (
    tester,
  ) async {
    // Widths here are calibrated against the test font, whose glyphs advance
    // ~1em each — far wider than Inter — so the rung a given pixel width
    // selects is not the rung the same width selects in the app.
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.split,
        currentRoute: route,
        reportRoute: priorRoute,
      ),
      width: 520,
    );

    // The full wording no longer fits, so the publisher and the connective
    // word go — rather than an ellipsis eating the serving provider, which is
    // the fact the row exists to disclose.
    expect(find.text(routeLabel), findsNothing);
    expect(find.text('Qwen 3.5 Plus · Melious.ai'), findsOneWidget);
    expect(find.text(priorRouteLabel), findsNothing);
    expect(find.text('GLM 5.2 · OpenRouter'), findsOneWidget);

    final tokens = tester
        .element(find.byType(TaskAgentIdentityRegion))
        .designTokens;
    final caption = tokens.typography.styles.others.caption;
    for (final label in [
      'Qwen 3.5 Plus · Melious.ai',
      'GLM 5.2 · OpenRouter',
      'This report',
    ]) {
      expect(
        isTruncated(tester, find.text(label)),
        isFalse,
        reason: '"$label" was chopped instead of stepping down a tier',
      );
      expect(
        tester.getSize(find.text(label)).height,
        lessThan(caption.fontSize! * caption.height! * 2),
        reason: '"$label" wrapped to a second line',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bare model name survives even the narrowest measure', (
    tester,
  ) async {
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.combined,
        currentRoute: route,
        reportRoute: route,
      ),
      width: 260,
    );

    // Last rung of the ladder: everything but the model is gone, and the
    // model itself is still whole.
    expect(find.text('Qwen 3.5 Plus'), findsOneWidget);
  });

  testWidgets('the attribution label never gives ground, only its route', (
    tester,
  ) async {
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.split,
        currentRoute: route,
        reportRoute: priorRoute,
      ),
      width: 520,
    );

    // "This rep…" tells the reader strictly less than nothing, so the fixed
    // label holds while the route steps down a tier.
    expect(isTruncated(tester, find.text('This report')), isFalse);
    expect(find.text(priorRouteLabel), findsNothing);
    expect(find.text('GLM 5.2 · OpenRouter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hovering the setup row brightens its own ink instead of painting an '
    'overlay',
    (tester) async {
      await pumpRegion(
        tester,
        data: const TaskAgentModelIdentityViewData(
          presentation: TaskAgentIdentityPresentation.combined,
          currentRoute: route,
          reportRoute: route,
        ),
        width: 900,
      );

      final ai = tester
          .element(find.byType(TaskAgentIdentityRegion))
          .designTokens
          .colors
          .aiCard;
      Color? routeInk() =>
          tester.widget<Text>(find.text(routeLabel)).style?.color;
      expect(routeInk(), ai.metaText);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text(routeLabel)));
      await tester.pump();

      // A quiet link: the caption and its glyphs lift meta -> body...
      expect(routeInk(), ai.bodyText);
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.reasoning)).color,
        ai.bodyText,
      );
      // ...and no Material overlay may paint a phantom button around them.
      final inkWell = tester.widget<InkWell>(setupRowInk());
      expect(inkWell.hoverColor, Colors.transparent);
      expect(
        inkWell.overlayColor?.resolve({WidgetState.hovered}),
        Colors.transparent,
      );
    },
  );
}
