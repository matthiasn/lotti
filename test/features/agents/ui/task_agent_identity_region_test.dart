import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

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

  testWidgets('combined row is tappable, accessible, and at least 40 high', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        TaskAgentIdentityRegion(
          data: const TaskAgentModelIdentityViewData(
            presentation: TaskAgentIdentityPresentation.combined,
            currentRoute: route,
            reportRoute: route,
          ),
          onSetupTap: () => taps++,
        ),
      ),
    );

    expect(
      find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'),
      findsOneWidget,
    );
    final inkWell = find.byType(InkWell).first;
    expect(tester.getSize(inkWell).height, greaterThanOrEqualTo(40));
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
    await tester.pumpWidget(
      makeTestableWidget(
        TaskAgentIdentityRegion(
          data: const TaskAgentModelIdentityViewData(
            presentation: TaskAgentIdentityPresentation.split,
            currentRoute: route,
            reportAttributionUnavailable: true,
          ),
          onSetupTap: () {},
        ),
      ),
    );

    expect(
      find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'),
      findsOneWidget,
    );
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
    await tester.pumpWidget(
      makeTestableWidget(
        TaskAgentIdentityRegion(
          data: const TaskAgentModelIdentityViewData(
            presentation: TaskAgentIdentityPresentation.disabled,
          ),
          onSetupTap: () {},
        ),
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
    await tester.pumpWidget(
      makeTestableWidget(
        TaskAgentIdentityRegion(
          data: const TaskAgentModelIdentityViewData(
            presentation: TaskAgentIdentityPresentation.broken,
            reportRoute: route,
          ),
          onSetupTap: () {},
        ),
      ),
    );

    expect(find.text('Selected AI setup is unavailable'), findsOneWidget);
    expect(find.text('This report'), findsOneWidget);
    expect(
      find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Current setup. Selected AI setup is unavailable',
      ),
      findsOneWidget,
    );
  });
}
