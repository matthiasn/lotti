import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/features/agents/ui/agent_wake_cadence_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<List<AgentWakeCadence?>> pump(
    WidgetTester tester, {
    required AgentWakeCadence? value,
    AgentWakeCadenceInheritance? inheritance,
    AgentWakeCadence? inheritedCadence,
    String? description,
  }) async {
    setTestSurfaceSize(tester, const Size(500, 900));
    final chosen = <AgentWakeCadence?>[];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        AgentWakeCadenceField(
          value: value,
          inheritance: inheritance,
          inheritedCadence: inheritedCadence,
          description: description,
          onChanged: chosen.add,
        ),
      ),
    );
    await tester.pump();
    return chosen;
  }

  BuildContext contextOf(WidgetTester tester) =>
      tester.element(find.byType(AgentWakeCadenceField));

  testWidgets('names every cadence in the current language', (tester) async {
    await pump(tester, value: AgentWakeCadence.live);
    final context = contextOf(tester);

    expect(
      [
        for (final cadence in AgentWakeCadence.values)
          agentWakeCadenceLabel(context, cadence),
      ],
      [
        context.messages.agentWakeCadenceLive,
        context.messages.agentWakeCadenceHourly,
        context.messages.agentWakeCadenceRecordingsOnly,
      ],
    );
    expect(find.text(context.messages.agentWakeCadenceLive), findsOneWidget);
  });

  testWidgets(
    'an unset task shows the category cadence it follows, and choosing it '
    'again reports null',
    (tester) async {
      final chosen = await pump(
        tester,
        value: null,
        inheritance: AgentWakeCadenceInheritance.category,
        inheritedCadence: AgentWakeCadence.hourly,
      );
      final messages = contextOf(tester).messages;
      final followLabel = messages.agentWakeCadenceFollowCategory(
        messages.agentWakeCadenceHourly,
      );

      await tester.tap(find.widgetWithText(InkWell, followLabel));
      await tester.pump();
      // The inherit entry and the three cadences.
      await tester.tap(find.text(messages.agentWakeCadenceRecordingsOnly).last);
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, followLabel));
      await tester.pump();
      await tester.tap(find.text(followLabel).last);
      await tester.pump();

      expect(chosen, [AgentWakeCadence.recordingsOnly, null]);
    },
  );

  testWidgets('a category names the app default it follows', (tester) async {
    await pump(
      tester,
      value: null,
      inheritance: AgentWakeCadenceInheritance.appDefault,
      inheritedCadence: AgentWakeCadence.live,
      description: 'Applies to every task',
    );
    final messages = contextOf(tester).messages;

    expect(
      find.text(
        messages.agentWakeCadenceFollowDefault(messages.agentWakeCadenceLive),
      ),
      findsOneWidget,
    );
    expect(find.text('Applies to every task'), findsOneWidget);
  });

  testWidgets('a choice of its own is shown instead of the inherited one', (
    tester,
  ) async {
    await pump(
      tester,
      value: AgentWakeCadence.recordingsOnly,
      inheritance: AgentWakeCadenceInheritance.category,
      inheritedCadence: AgentWakeCadence.hourly,
    );
    final messages = contextOf(tester).messages;

    expect(
      find.text(messages.agentWakeCadenceRecordingsOnly),
      findsOneWidget,
    );
    expect(
      find.textContaining(messages.agentWakeCadenceHourly),
      findsNothing,
    );
  });
}
