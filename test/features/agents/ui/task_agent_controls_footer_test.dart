import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/ui/task_agent_automation_row.dart';
import 'package:lotti/features/agents/ui/task_agent_controls_footer.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../widget_test_utils.dart';

/// The footer is a composition root: it owns the band chrome, the shared
/// leading edge, and the order of its three bands. Everything the automation
/// controls themselves do is covered by
/// `task_agent_automation_row_test.dart`, and everything the identity rows do
/// by `task_agent_identity_region_test.dart`.
void main() {
  const route = InferenceRouteSnapshot(
    providerModelId: 'qwen3.5-plus',
    modelName: 'Qwen 3.5 Plus',
    publisherName: 'Alibaba',
    servingProviderType: InferenceProviderType.melious,
    servingProviderName: 'Melious.ai',
    runtimeSettings: {},
  );
  const identityData = TaskAgentModelIdentityViewData(
    presentation: TaskAgentIdentityPresentation.combined,
    currentRoute: route,
    reportRoute: route,
  );

  Widget subject({
    bool automaticUpdatesEnabled = false,
    bool automationBusy = false,
    bool inferenceAvailable = true,
    bool isRunning = false,
    bool showCountdown = false,
    DateTime? nextWakeAt,
    bool hasReportContent = false,
    bool isStale = false,
    ValueChanged<bool>? onAutomaticUpdatesChanged,
    VoidCallback? onRunNow,
    VoidCallback? onSkipScheduledUpdate,
    VoidCallback? onCountdownExpired,
    VoidCallback? onSetupTap,
  }) {
    return TaskAgentControlsFooter(
      automaticUpdatesEnabled: automaticUpdatesEnabled,
      automationBusy: automationBusy,
      inferenceAvailable: inferenceAvailable,
      isRunning: isRunning,
      showCountdown: showCountdown,
      nextWakeAt: nextWakeAt,
      hasReportContent: hasReportContent,
      isStale: isStale,
      onAutomaticUpdatesChanged: onAutomaticUpdatesChanged ?? (_) {},
      onRunNow: onRunNow,
      onSkipScheduledUpdate: onSkipScheduledUpdate ?? () {},
      onCountdownExpired: onCountdownExpired ?? () {},
      identityData: identityData,
      onSetupTap: onSetupTap ?? () {},
    );
  }

  Future<void> pumpFooter(
    WidgetTester tester,
    Widget child, {
    double width = 730,
    Locale? locale,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    tester.view
      ..physicalSize = Size(width, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      makeTestableWidget(
        child,
        mediaQueryData: MediaQueryData(
          size: Size(width, 1200),
          textScaler: textScaler,
        ),
        locale: locale,
      ),
    );
  }

  Finder footer() => find.byKey(const ValueKey('taskAgentControlsFooter'));

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(TaskAgentControlsFooter)).designTokens;

  testWidgets('wires the automation controls and the identity region', (
    tester,
  ) async {
    var runs = 0;
    bool? changedTo;
    var setupTaps = 0;
    await pumpFooter(
      tester,
      subject(
        onRunNow: () => runs++,
        onAutomaticUpdatesChanged: (value) => changedTo = value,
        onSetupTap: () => setupTaps++,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
    expect(runs, 1);

    await tester.tap(
      find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
    );
    expect(changedTo, isTrue);

    await tester.tap(find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'));
    expect(setupTaps, 1);
  });

  testWidgets('the band is the only surface in the footer', (tester) async {
    await pumpFooter(tester, subject(hasReportContent: true, onRunNow: () {}));

    final ai = tokensOf(tester).colors.aiCard;

    // No card in a card. Asserted against the trigger's decorated ancestry
    // rather than every `Container` in the subtree, because controls
    // legitimately paint their own chrome — the switch's track is a rounded,
    // filled, bordered box and always will be. What must not exist is a
    // surface *wrapping* the controls: the band is the only one.
    final wrappingSurfaces = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.byKey(const ValueKey('taskAgentWakeButton')),
            matching: find.descendant(
              of: footer(),
              matching: find.byType(Container),
            ),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .toList();
    expect(
      wrappingSurfaces,
      isEmpty,
      reason: 'a surface reappeared between the band and the controls',
    );

    // The band's own chrome: one wash, one hairline, and that hairline is on
    // the top edge only.
    final band =
        tester.widget<Container>(footer()).decoration! as BoxDecoration;
    expect(band.color, ai.footerWash);
    final border = band.border! as Border;
    expect(border.top.color, ai.borderSoft);
    expect(border.left, BorderSide.none);
    expect(border.right, BorderSide.none);
    expect(border.bottom, BorderSide.none);
  });

  testWidgets('every row starts on the card content edge', (tester) async {
    await pumpFooter(
      tester,
      subject(hasReportContent: true, isStale: true, onRunNow: () {}),
    );

    final tokens = tokensOf(tester);
    final edge = tester.getTopLeft(footer()).dx + tokens.spacing.cardPadding;

    // The band pays step4 and each row adds its own step2, so glyphs land on
    // cardPadding — the same column as the summary prose above — while the
    // interactive rows still get ink that breathes around their content.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('taskAgentStaleGlyph'))).dx,
      moreOrLessEquals(edge, epsilon: 0.5),
    );
    expect(
      tester.getTopLeft(find.byIcon(Icons.psychology_outlined)).dx,
      moreOrLessEquals(edge, epsilon: 0.5),
    );
  });

  testWidgets('identity always sits below the automation controls', (
    tester,
  ) async {
    for (final width in [320.0, 730.0, 1400.0]) {
      await pumpFooter(
        tester,
        subject(hasReportContent: true, onRunNow: () {}),
        width: width,
      );

      expect(
        tester.getTopLeft(find.byType(TaskAgentIdentityRegion)).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(TaskAgentAutomationRow)).dy - 1,
        ),
        reason: 'identity moved out from under the controls at ${width}px',
      );
    }
  });

  testWidgets('a ticking countdown never moves the identity region', (
    tester,
  ) async {
    var now = DateTime(2026, 7, 16, 9);
    await withClock(Clock(() => now), () async {
      await pumpFooter(
        tester,
        subject(
          hasReportContent: true,
          automaticUpdatesEnabled: true,
          showCountdown: true,
          nextWakeAt: now.add(const Duration(hours: 1)),
          onRunNow: () {},
        ),
      );

      final identity = find.byType(TaskAgentIdentityRegion);
      final footerSize = tester.getSize(footer());
      final identityOffset = tester.getTopLeft(identity);

      // Crosses the h:mm:ss → m:ss boundary: the label's text gets materially
      // shorter, and nothing below it may notice.
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.getTopLeft(identity), identityOffset);
      expect(tester.getSize(footer()), footerSize);
    });
  });

  testWidgets('renders without overflow at 320px in German at 1.3x', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 16, 9);
    await withClock(Clock.fixed(now), () async {
      await pumpFooter(
        tester,
        subject(
          hasReportContent: true,
          isStale: true,
          automaticUpdatesEnabled: true,
          showCountdown: true,
          nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
          onRunNow: () {},
        ),
        width: 320,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(1.3),
      );
    });

    expect(tester.takeException(), isNull);
    expect(find.byType(TaskAgentAutomationRow), findsOneWidget);
    expect(find.byType(TaskAgentIdentityRegion), findsOneWidget);
  });
}
