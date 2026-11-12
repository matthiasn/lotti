import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_cards.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/front_agent/ui/front_task_list.dart';
import 'package:material_ui/material_ui.dart';

/// The name of the action a tapped quick reply sends, its words in the
/// action's `context` under `text`.
const frontQuickReplyAction = 'quick_reply';

/// What the chat does for the components of one reply: draws her words
/// (its own Markdown, with the device's dates), opens a card's entity or a
/// closed task, and says which cards are already shown elsewhere under the
/// reply. The catalog stays static; what a tap does comes from here.
class FrontReplyScope extends InheritedWidget {
  const FrontReplyScope({
    required this.surface,
    required this.prose,
    required this.onOpen,
    required this.onOpenTask,
    required super.child,
    this.shownIds = const {},
    this.canReply = true,
    super.key,
  });

  /// The surface the components are drawn on, for the actions they send.
  final SurfaceModel<ComponentImplementation> surface;

  final Widget Function(String markdown) prose;
  final ValueChanged<FrontEntityReference> onOpen;
  final ValueChanged<String> onOpenTask;

  /// Entities a door's preview card already shows under this reply: her
  /// lists leave them out.
  final Set<String> shownIds;

  /// Whether a quick reply can be tapped: not while a turn is in flight, and
  /// only under her latest reply.
  final bool canReply;

  static FrontReplyScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FrontReplyScope>();
    assert(scope != null, 'A reply surface is drawn in a FrontReplyScope');
    return scope!;
  }

  @override
  bool updateShouldNotify(FrontReplyScope oldWidget) =>
      !identical(surface, oldWidget.surface) ||
      prose != oldWidget.prose ||
      onOpen != oldWidget.onOpen ||
      onOpenTask != oldWidget.onOpenTask ||
      canReply != oldWidget.canReply ||
      !setEquals(shownIds, oldWidget.shownIds);
}

/// The key a component is drawn under: `front-reply-<surface>-<id>`.
Key _key(BuildContext context, ComponentNode<ComponentImplementation> node) =>
    ValueKey(
      'front-reply-${FrontReplyScope.of(context).surface.id}-'
      '${node.componentId}',
    );

/// The accessibility label she gave a component: never shown or spoken.
final Schema _captionSchema = S.string(
  description: 'A short label for screen readers',
);

/// [child] under [caption] as its screen-reader label, when she gave one.
Widget _captioned(String? caption, Widget child) =>
    caption == null || caption.trim().isEmpty
    ? child
    : Semantics(container: true, label: caption.trim(), child: child);

/// A property the app binds to the surface's data model.
final Schema _bound = CommonSchemasV1.dataBinding;

final _reply = ComponentImplementation(
  name: FrontReplyComponents.reply,
  schema: S.object(
    properties: {
      'children': Schema.fromMap({
        r'$ref': r'common_types.json#/$defs/ChildList',
      }),
    },
    required: ['children'],
  ),
  builder: (context, node, props, buildChild) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: context.designTokens.spacing.step4,
    children: [
      for (final child in props.children('children'))
        KeyedSubtree(key: NodeKey(child.instanceId), child: buildChild(child)),
    ],
  ),
);

final _text = ComponentImplementation(
  name: FrontReplyComponents.text,
  schema: S.object(
    properties: {'text': S.string(description: 'Her words, as Markdown')},
    required: ['text'],
  ),
  builder: (context, node, props, _) => KeyedSubtree(
    key: _key(context, node),
    child: FrontReplyScope.of(context).prose(props.string('text') ?? ''),
  ),
);

final _taskCards = ComponentImplementation(
  name: FrontReplyComponents.taskCards,
  schema: S.object(
    properties: {
      'items': S.list(
        description: 'The tasks and projects, as references',
        items: S.object(
          properties: {
            'kind': S.string(),
            'id': S.string(),
            'title': S.string(),
            'note': S.string(),
          },
          required: ['kind', 'id', 'title'],
        ),
      ),
      'due': _bound,
      'caption': _captionSchema,
    },
    required: ['items'],
  ),
  builder: (context, node, props, _) {
    final scope = FrontReplyScope.of(context);
    final cards = [
      for (final card in FrontEntityReference.listFromJson(props.list('items')))
        if (!scope.shownIds.contains(card.id)) card,
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    final due = FrontDueSection.fromJson(props.value('due'));
    return _captioned(
      props.string('caption'),
      Column(
        key: _key(context, node),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: context.designTokens.spacing.step2,
        children: [
          if (due != null) FrontDueSectionLabel(section: due),
          FrontEntityPreviewList(references: cards, onOpen: scope.onOpen),
        ],
      ),
    );
  },
);

final _pullRequestCards = ComponentImplementation(
  name: FrontReplyComponents.pullRequestCards,
  schema: S.object(
    properties: {
      'items': S.list(
        description: 'The pull requests, each with the task holding it',
        items: S.object(
          properties: {'key': S.string(), 'taskId': S.string()},
          required: ['key', 'taskId'],
        ),
      ),
      'caption': _captionSchema,
    },
    required: ['items'],
  ),
  builder: (context, node, props, _) {
    final cards = frontPullRequestCardsFromJson(props.list('items'));
    if (cards.isEmpty) return const SizedBox.shrink();
    return _captioned(
      props.string('caption'),
      FrontPullRequestCards(
        key: _key(context, node),
        cards: cards,
        onOpenTask: FrontReplyScope.of(context).onOpenTask,
      ),
    );
  },
);

/// A component drawn from what a lookup made, bound at `data`.
ComponentImplementation _fromLookup(
  String name,
  Widget? Function(BuildContext context, Key key, Object? data) build,
) => ComponentImplementation(
  name: name,
  schema: S.object(
    properties: {'data': _bound, 'caption': _captionSchema},
    required: ['data'],
  ),
  builder: (context, node, props, _) => switch (build(
    context,
    _key(context, node),
    props.value('data'),
  )) {
    null => const SizedBox.shrink(),
    final drawn => _captioned(props.string('caption'), drawn),
  },
);

final ComponentImplementation _closedTasks = _fromLookup(
  FrontReplyComponents.closedTasks,
  (
    context,
    key,
    data,
  ) {
    final tasks = FrontClosedTaskCard.listFromJson(data);
    return tasks.isEmpty
        ? null
        : FrontClosedTaskList(
            key: key,
            tasks: tasks,
            onOpen: FrontReplyScope.of(context).onOpenTask,
          );
  },
);

final ComponentImplementation _loggedTimeChart = _fromLookup(
  FrontReplyComponents.loggedTimeChart,
  (
    context,
    key,
    data,
  ) {
    final chart = FrontLoggedTimeChart.fromJson(data);
    return chart == null
        ? null
        : FrontLoggedTimeChartCard(key: key, chart: chart);
  },
);

final ComponentImplementation _pullRequestChart = _fromLookup(
  FrontReplyComponents.pullRequestChart,
  (
    context,
    key,
    data,
  ) {
    final chart = FrontPullRequestChart.fromJson(data);
    return chart == null
        ? null
        : FrontPullRequestChartCard(key: key, chart: chart);
  },
);

final _quickReplies = ComponentImplementation(
  name: FrontReplyComponents.quickReplies,
  schema: S.object(
    properties: {
      'options': S.list(
        description: 'Short replies the user can tap',
        items: S.string(),
      ),
    },
    required: ['options'],
  ),
  builder: (context, node, props, _) {
    final scope = FrontReplyScope.of(context);
    final tokens = context.designTokens;
    return Wrap(
      key: _key(context, node),
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final option in props.list('options').whereType<String>())
          DesignSystemChip(
            key: ValueKey('front-quick-reply-$option'),
            label: option,
            size: DesignSystemChipSize.compactPillTouch,
            outlined: true,
            onPressed: scope.canReply
                ? () async => scope.surface.dispatchAction({
                    'name': frontQuickReplyAction,
                    'context': {'text': option},
                  }, node.componentId)
                : null,
          ),
      ],
    );
  },
);

/// Her reply's A2UI catalog (v1.0): the components a reply is drawn from,
/// each built on the chat's own widgets. Their data comes from the surface
/// as stored — the lookups' through its data model — never from the model.
final CatalogImplementation frontReplyCatalog = CatalogImplementation(
  id: frontReplyCatalogId,
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [
    _reply,
    _text,
    _taskCards,
    _pullRequestCards,
    _closedTasks,
    _loggedTimeChart,
    _pullRequestChart,
    _quickReplies,
  ],
);
