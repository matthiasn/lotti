import 'package:a2ui_core/a2ui_core.dart'
    show CreateSurfaceMessage, UpdateComponentsMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_components.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:lotti/features/front_agent/ui/genui/front_reply_catalog.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:material_ui/material_ui.dart';

import 'front_reply_test_harness.dart';

void main() {
  const ice = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 't-ice',
    title: 'Check the ice-pad weather window',
  );
  const range = InsightsRange(startDay: 20396, endDayExclusive: 20403);
  const loggedTime = FrontLoggedTimeChart(range: range, categoryIds: {});
  const pullRequests = FrontPullRequestChart(range: range, categoryIds: {});
  final closed = [
    FrontClosedTaskCard(
      id: 't-sweep',
      title: 'Sweep the ice',
      closedAt: DateTime.utc(2026, 11, 8, 10),
    ),
  ];
  final due = FrontDueSection(
    window: FrontDueWindow.today,
    today: DateTime(2026, 11, 10),
    through: DateTime(2026, 11, 10),
  );

  /// A reply of every component type the catalog has.
  List<Map<String, Object?>> everything() => frontReplyComponents(
    parts: const [
      FrontReplyText('One is due:'),
      FrontReplyCards([ice]),
      FrontReplyShow(FrontReplyAttachment.closedTasks),
      FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
      FrontReplyShow(FrontReplyAttachment.pullRequestChart),
    ],
    closedTasks: closed,
    loggedTime: loggedTime,
    pullRequests: pullRequests,
    due: due,
  );

  group("GenUI's own schema validation", () {
    Future<List<ChatMessage>> reported(
      List<Map<String, Object?>> components,
    ) async {
      final controller = SurfaceController(catalogs: [frontReplyCatalog]);
      final errors = <ChatMessage>[];
      final subscription = controller.onSubmit.listen(errors.add);
      controller
        ..handleMessage(
          CreateSurfaceMessage(
            surfaceId: 'a1',
            catalogId: frontReplyCatalogId,
          ),
        )
        ..handleMessage(
          UpdateComponentsMessage(surfaceId: 'a1', components: components),
        );
      await pumpEventQueue();
      await subscription.cancel();
      controller.dispose();
      return errors;
    }

    test('accepts every component the reply mapping draws', () async {
      expect(await reported(everything()), isEmpty);
    });

    test('reports a component that breaks its schema, so the check above '
        'is not vacuous', () async {
      final errors = await reported([
        {
          'id': 'root',
          'component': FrontReplyComponentTypes.reply,
          'parts': ['text-0'],
        },
        {'id': 'text-0', 'component': FrontReplyComponentTypes.text},
      ]);

      expect(errors, isNotEmpty);
    });
  });

  testWidgets("every component draws the chat's own widget, in the reply's "
      'order, with the data the reply carries', (tester) async {
    final taps = FrontReplyTaps();
    await pumpReplySurface(tester, everything(), taps: taps);

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final words = find.text('words: One is due:');
    final cards = find.byKey(const ValueKey('front-reply-a1-cards-1'));
    final closedList = find.byKey(
      const ValueKey('front-reply-a1-closed_tasks'),
    );
    final timeChart = find.byKey(
      const ValueKey('front-reply-a1-logged_time_chart'),
    );
    final prChart = find.byKey(
      const ValueKey('front-reply-a1-pull_request_chart'),
    );

    expect(
      tester
          .widget<FrontEntityPreviewList>(
            find.descendant(
              of: cards,
              matching: find.byType(FrontEntityPreviewList),
            ),
          )
          .references,
      [ice],
    );
    expect(
      tester
          .widget<FrontDueSectionLabel>(
            find.descendant(
              of: cards,
              matching: find.byType(FrontDueSectionLabel),
            ),
          )
          .section,
      due,
    );
    expect(tester.widget<FrontClosedTaskList>(closedList).tasks, closed);
    expect(
      tester.widget<FrontLoggedTimeChartCard>(timeChart).chart,
      loggedTime,
    );
    expect(
      tester.widget<FrontPullRequestChartCard>(prChart).chart,
      pullRequests,
    );
    expect(top(words), lessThan(top(cards)));
    expect(top(cards), lessThan(top(closedList)));
    expect(top(closedList), lessThan(top(timeChart)));
    expect(top(timeChart), lessThan(top(prChart)));
  });

  testWidgets('a tap on a card or a closed task goes to the scope', (
    tester,
  ) async {
    final taps = FrontReplyTaps();
    await pumpReplySurface(tester, everything(), taps: taps);

    await tester.tap(find.byKey(FrontEntityPreviewKeys.card('t-ice')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(FrontTaskListKeys.closedRow('t-sweep')),
    );
    await tester.tap(find.byKey(FrontTaskListKeys.closedRow('t-sweep')));
    await tester.pump();

    expect(taps.opened, [ice]);
    expect(taps.openedTasks, ['t-sweep']);
  });

  testWidgets('a chart whose data cannot be read draws nothing', (
    tester,
  ) async {
    await pumpReplySurface(tester, [
      {
        'id': 'root',
        'component': FrontReplyComponentTypes.reply,
        'parts': ['logged_time_chart', 'pull_request_chart'],
      },
      {
        'id': 'logged_time_chart',
        'component': FrontReplyComponentTypes.loggedTimeChart,
        'chart': {'range': 'soon'},
      },
      {
        'id': 'pull_request_chart',
        'component': FrontReplyComponentTypes.pullRequestChart,
        'chart': {'range': 'soon'},
      },
    ], taps: FrontReplyTaps());

    expect(find.byType(FrontLoggedTimeChartCard), findsNothing);
    expect(find.byType(FrontPullRequestChartCard), findsNothing);
  });

  testWidgets('the scope tells its dependents only when what it does changes', (
    tester,
  ) async {
    Widget prose(String markdown) => Text(markdown);
    void open(FrontEntityReference _) {}
    void openTask(String _) {}
    final scope = FrontReplyScope(
      prose: prose,
      onOpen: open,
      onOpenTask: openTask,
      child: const SizedBox.shrink(),
    );

    expect(
      scope.updateShouldNotify(
        FrontReplyScope(
          prose: prose,
          onOpen: open,
          onOpenTask: openTask,
          child: const SizedBox.shrink(),
        ),
      ),
      isFalse,
    );
    expect(
      scope.updateShouldNotify(
        FrontReplyScope(
          prose: Text.new,
          onOpen: open,
          onOpenTask: openTask,
          child: const SizedBox.shrink(),
        ),
      ),
      isTrue,
    );
  });
}
