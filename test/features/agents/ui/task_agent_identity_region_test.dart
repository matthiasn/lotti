import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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

  testWidgets('combined row is tappable, accessible, and at least step8 high', (
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
      greaterThanOrEqualTo(context.designTokens.spacing.step8),
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
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
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
        tester.getRect(find.byIcon(Icons.chevron_right_rounded)).right +
            tokens.spacing.step2,
        epsilon: 0.5,
      ),
    );
    // ...and it is inset from the glyph, so the rounded ink corners do not
    // clip into the icon.
    expect(
      tester.getRect(find.byIcon(Icons.psychology_outlined)).left - ink.left,
      moreOrLessEquals(tokens.spacing.step2, epsilon: 0.5),
    );
    expect(ink.height, greaterThanOrEqualTo(tokens.spacing.step8));
  });

  testWidgets('both identity lines truncate rather than wrap when squeezed', (
    tester,
  ) async {
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.split,
        currentRoute: route,
        reportRoute: priorRoute,
      ),
      width: 200,
    );

    expect(isTruncated(tester, find.text(routeLabel)), isTrue);
    expect(isTruncated(tester, find.text(priorRouteLabel)), isTrue);

    final tokens = tester
        .element(find.byType(TaskAgentIdentityRegion))
        .designTokens;
    final caption = tokens.typography.styles.others.caption;
    final singleLine = caption.fontSize! * caption.height!;
    for (final label in [routeLabel, priorRouteLabel, 'This report']) {
      expect(
        tester.getSize(find.text(label)).height,
        lessThan(singleLine * 2),
        reason: '"$label" wrapped to a second line',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the attribution line keeps the route when space runs out', (
    tester,
  ) async {
    await pumpRegion(
      tester,
      data: const TaskAgentModelIdentityViewData(
        presentation: TaskAgentIdentityPresentation.split,
        currentRoute: route,
        reportRoute: priorRoute,
      ),
      width: 200,
    );

    // The label is a fixed-vocabulary prefix and the route is the payload, so
    // the route must not be the one squeezed out.
    expect(
      tester.getSize(find.text(priorRouteLabel)).width,
      greaterThan(tester.getSize(find.text('This report')).width),
    );
  });
}
