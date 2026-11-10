import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_components.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:material_ui/material_ui.dart';

/// The catalog id her reply's surfaces are created with.
const frontReplyCatalogId = 'com.lotti.front_reply_catalog';

/// What the host does for the components of her reply: draws her words
/// (the chat's own Markdown, with the device's dates), opens a card's
/// entity, and opens a closed task. The catalog stays static; what a tap
/// does comes from the surface's place in the chat.
class FrontReplyScope extends InheritedWidget {
  const FrontReplyScope({
    required this.prose,
    required this.onOpen,
    required this.onOpenTask,
    required super.child,
    super.key,
  });

  final Widget Function(String markdown) prose;
  final ValueChanged<FrontEntityReference> onOpen;
  final ValueChanged<String> onOpenTask;

  static FrontReplyScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FrontReplyScope>();
    assert(scope != null, 'A FrontReply surface is drawn in a FrontReplyScope');
    return scope!;
  }

  @override
  bool updateShouldNotify(FrontReplyScope oldWidget) =>
      prose != oldWidget.prose ||
      onOpen != oldWidget.onOpen ||
      onOpenTask != oldWidget.onOpenTask;
}

/// The key a component of [itemContext] is drawn under:
/// `front-reply-<surface>-<component id>`.
Key frontReplyComponentKey(CatalogItemContext itemContext) =>
    ValueKey('front-reply-${itemContext.surfaceId}-${itemContext.id}');

Map<String, Object?> _data(CatalogItemContext itemContext) =>
    itemContext.data is Map<String, Object?>
    ? itemContext.data as Map<String, Object?>
    : const {};

final _reply = CatalogItem(
  name: FrontReplyComponentTypes.reply,
  dataSchema: S.object(
    properties: {
      'parts': S.list(
        description: 'The ids of the reply parts, in order',
        items: S.string(),
      ),
    },
    required: ['parts'],
  ),
  widgetBuilder: (itemContext) {
    final parts = _data(itemContext)['parts'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: itemContext.buildContext.designTokens.spacing.step4,
      children: [
        if (parts is List)
          for (final id in parts.whereType<String>())
            itemContext.buildChild(id),
      ],
    );
  },
);

final _text = CatalogItem(
  name: FrontReplyComponentTypes.text,
  dataSchema: S.object(
    properties: {'markdown': S.string(description: 'Her words, as Markdown')},
    required: ['markdown'],
  ),
  widgetBuilder: (itemContext) {
    final markdown = _data(itemContext)['markdown'];
    return KeyedSubtree(
      key: frontReplyComponentKey(itemContext),
      child: FrontReplyScope.of(
        itemContext.buildContext,
      ).prose(markdown is String ? markdown : ''),
    );
  },
);

final _cards = CatalogItem(
  name: FrontReplyComponentTypes.cards,
  dataSchema: S.object(
    properties: {
      'cards': S.list(
        description: 'The tasks and projects, as references',
        items: S.object(
          properties: {
            'kind': S.string(),
            'id': S.string(),
            'title': S.string(),
          },
          required: ['kind', 'id', 'title'],
        ),
      ),
      'due': S.object(description: 'The window a due list was read from'),
    },
    required: ['cards'],
  ),
  widgetBuilder: (itemContext) {
    final data = _data(itemContext);
    final due = FrontDueSection.fromJson(data['due']);
    return Column(
      key: frontReplyComponentKey(itemContext),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: itemContext.buildContext.designTokens.spacing.step2,
      children: [
        if (due != null) FrontDueSectionLabel(section: due),
        FrontEntityPreviewList(
          references: FrontEntityReference.listFromJson(data['cards']),
          onOpen: FrontReplyScope.of(itemContext.buildContext).onOpen,
        ),
      ],
    );
  },
);

final _closedTasks = CatalogItem(
  name: FrontReplyComponentTypes.closedTasks,
  dataSchema: S.object(
    properties: {
      'tasks': S.list(
        description: 'Every task a closed-task lookup found',
        items: S.object(),
      ),
    },
    required: ['tasks'],
  ),
  widgetBuilder: (itemContext) => FrontClosedTaskList(
    key: frontReplyComponentKey(itemContext),
    tasks: FrontClosedTaskCard.listFromJson(_data(itemContext)['tasks']),
    onOpen: FrontReplyScope.of(itemContext.buildContext).onOpenTask,
  ),
);

final _loggedTimeChart = CatalogItem(
  name: FrontReplyComponentTypes.loggedTimeChart,
  dataSchema: S.object(
    properties: {'chart': S.object(description: 'What the chart sums')},
    required: ['chart'],
  ),
  widgetBuilder: (itemContext) {
    final chart = FrontLoggedTimeChart.fromJson(_data(itemContext)['chart']);
    return chart == null
        ? const SizedBox.shrink()
        : FrontLoggedTimeChartCard(
            key: frontReplyComponentKey(itemContext),
            chart: chart,
          );
  },
);

final _pullRequestChart = CatalogItem(
  name: FrontReplyComponentTypes.pullRequestChart,
  dataSchema: S.object(
    properties: {'chart': S.object(description: 'What the charts count')},
    required: ['chart'],
  ),
  widgetBuilder: (itemContext) {
    final chart = FrontPullRequestChart.fromJson(_data(itemContext)['chart']);
    return chart == null
        ? const SizedBox.shrink()
        : FrontPullRequestChartCard(
            key: frontReplyComponentKey(itemContext),
            chart: chart,
          );
  },
);

/// Her reply's GenUI catalog: the components a reply is drawn from, each
/// built on the chat's own widgets. Their data is the reply as stored
/// ([frontReplyComponents]); the model only chose the parts.
final Catalog frontReplyCatalog = Catalog(
  [_reply, _text, _cards, _closedTasks, _loggedTimeChart, _pullRequestChart],
  catalogId: frontReplyCatalogId,
);
