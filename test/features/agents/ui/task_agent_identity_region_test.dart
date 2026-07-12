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

  testWidgets('combined row is tappable, accessible, and at least 48 high', (
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
          automaticUpdatesEnabled: true,
          onSetupTap: () => taps++,
        ),
      ),
    );

    expect(
      find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'),
      findsOneWidget,
    );
    final inkWell = find.byType(InkWell).first;
    expect(tester.getSize(inkWell).height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(
        RegExp('This report and current setup use Qwen 3.5 Plus'),
      ),
      findsOneWidget,
    );
    await tester.tap(inkWell);
    expect(taps, 1);
  });

  testWidgets('split state labels current setup and historical report', (
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
          automaticUpdatesEnabled: true,
          onSetupTap: () {},
        ),
      ),
    );

    expect(find.text('Current setup'), findsOneWidget);
    expect(find.text('This report'), findsOneWidget);
    expect(find.text('Attribution unavailable'), findsOneWidget);
  });

  testWidgets('no setup is a visible error and automation-off is explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        TaskAgentIdentityRegion(
          data: const TaskAgentModelIdentityViewData(
            presentation: TaskAgentIdentityPresentation.disabled,
          ),
          automaticUpdatesEnabled: false,
          onSetupTap: () {},
        ),
      ),
    );

    expect(find.text('No AI setup'), findsOneWidget);
    expect(
      find.text(
        'Choose a saved setup or thinking model before this agent can run.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Automatic updates off · Use Run now to update'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });
}
