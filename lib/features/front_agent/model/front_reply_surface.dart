import 'package:lotti/features/front_agent/model/front_cited_answer.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:meta/meta.dart';

/// The id of the A2UI catalog her replies are drawn from.
const frontReplyCatalogId = 'https://lotti.app/catalogs/companion_reply.json';

/// The A2UI protocol version her reply surfaces are written in.
const frontReplyProtocolVersion = '1.0';

/// The components of her reply catalog, by the name an A2UI component
/// carries as its `component` — and the name she composes a reply with.
abstract final class FrontReplyComponents {
  /// The reply itself: its components, in order (`children`). Never hers to
  /// write: the app adds it as the surface's root.
  static const reply = 'Reply';

  /// Her words (`text`, Markdown).
  static const text = 'Text';

  /// Tasks and projects as preview cards (`items`).
  static const taskCards = 'TaskCards';

  /// Pull requests as cards, each with its task (`items`).
  static const pullRequestCards = 'PullRequestCards';

  /// The cards of every task a closed-task lookup found.
  static const closedTasks = 'ClosedTasks';

  /// The chart of the logged time a lookup summed.
  static const loggedTimeChart = 'LoggedTimeChart';

  /// The charts of the pull requests a lookup counted.
  static const pullRequestChart = 'PullRequestChart';

  /// Short replies the user can tap to answer (`options`).
  static const quickReplies = 'QuickReplies';

  /// A journal answer's points, each with the entries it rests on (`data`,
  /// bound at `/answer`). Never hers to write: the app composes a journal
  /// answer's surface from what the journal search verified
  /// ([FrontReplySurface.citedAnswer]).
  static const citedPoints = 'CitedPoints';

  /// What she may compose a reply from, in the order the tool lists them.
  static const List<String> composable = [
    text,
    taskCards,
    pullRequestCards,
    closedTasks,
    loggedTimeChart,
    pullRequestChart,
    quickReplies,
  ];

  /// The components drawn from what a lookup of the turn made: the app
  /// binds each to the surface's data model, at the path of the same name.
  static const List<String> fromLookups = [
    closedTasks,
    loggedTimeChart,
    pullRequestChart,
  ];
}

/// The paths of a reply surface's data model: what the turn's lookups made,
/// written by the app and never by the model.
abstract final class FrontReplyData {
  static const due = 'due';
  static const closedTasks = 'closedTasks';
  static const loggedTime = 'loggedTime';
  static const pullRequests = 'pullRequests';

  /// A journal answer's points ([FrontReplyComponents.citedPoints]).
  static const answer = 'answer';

  /// The data-model key a lookup's component is bound to.
  static const Map<String, String> byComponent = {
    FrontReplyComponents.closedTasks: closedTasks,
    FrontReplyComponents.loggedTimeChart: loggedTime,
    FrontReplyComponents.pullRequestChart: pullRequests,
  };
}

/// One reply of hers as stored: the A2UI v1.0 `createSurface` message that
/// draws it — its components, and the data model the lookups' components are
/// bound to.
@immutable
class FrontReplySurface {
  const FrontReplySurface(this.message);

  /// Builds the surface of reply [surfaceId] from [components] — each a
  /// `{component, …properties}` map as the reply reader checked it, without
  /// an id — in order.
  ///
  /// The app adds what is not the model's: ids, the root, and the data. A
  /// lookup's component is bound to its data and left out when the turn has
  /// none ([closedTasks], [loggedTime], [pullRequests]); the window of a due
  /// answer ([due]) labels the reply's task cards only when it has exactly
  /// one list, since separate lists are named by her own words.
  factory FrontReplySurface.compose({
    required String surfaceId,
    required List<Map<String, Object?>> components,
    FrontDueSection? due,
    List<FrontClosedTaskCard>? closedTasks,
    FrontLoggedTimeChart? loggedTime,
    FrontPullRequestChart? pullRequests,
  }) {
    final data = <String, Object?>{
      FrontReplyData.due: ?due?.toJson(),
      if (closedTasks != null && closedTasks.isNotEmpty)
        FrontReplyData.closedTasks: [
          for (final task in closedTasks) task.toJson(),
        ],
      FrontReplyData.loggedTime: ?loggedTime?.toJson(),
      FrontReplyData.pullRequests: ?pullRequests?.toJson(),
    };
    final lists = components
        .where((c) => c['component'] == FrontReplyComponents.taskCards)
        .length;
    final drawn = <Map<String, Object?>>[];
    for (final component in components) {
      final type = component['component'];
      final key = FrontReplyData.byComponent[type];
      if (key != null && !data.containsKey(key)) continue;
      drawn.add({
        ...component,
        'id': 'c${drawn.length}',
        if (key != null) 'data': {'@path': '/$key'},
        if (type == FrontReplyComponents.taskCards && lists == 1 && due != null)
          'due': {'@path': '/${FrontReplyData.due}'},
      });
    }
    return FrontReplySurface({
      'version': frontReplyProtocolVersion,
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': frontReplyCatalogId,
        'dataModel': data,
        'components': [
          {
            'id': 'root',
            'component': FrontReplyComponents.reply,
            'children': [for (final component in drawn) component['id']],
          },
          ...drawn,
        ],
      },
    });
  }

  /// The surface journal answer [points] are drawn on, composed by the app
  /// alone: a `CitedPoints` bound to the points at `/answer`, so each claim
  /// is drawn with the entries it rests on rather than as Markdown with
  /// footnote numbers.
  factory FrontReplySurface.citedAnswer({
    required String surfaceId,
    required List<FrontCitedPoint> points,
  }) => FrontReplySurface({
    'version': frontReplyProtocolVersion,
    'createSurface': {
      'surfaceId': surfaceId,
      'catalogId': frontReplyCatalogId,
      'dataModel': {
        FrontReplyData.answer: [for (final point in points) point.toJson()],
      },
      'components': const [
        {
          'id': 'root',
          'component': FrontReplyComponents.reply,
          'children': ['c0'],
        },
        {
          'id': 'c0',
          'component': FrontReplyComponents.citedPoints,
          'data': {'@path': '/${FrontReplyData.answer}'},
        },
      ],
    },
  });

  /// The stored A2UI message, as a message processor takes it.
  final Map<String, Object?> message;

  /// Reads a surface a reply stored; null for a shape this build does not
  /// know.
  static FrontReplySurface? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final create = json['createSurface'];
    if (json['version'] is! String ||
        create is! Map ||
        create['surfaceId'] is! String ||
        create['components'] is! List) {
      return null;
    }
    return FrontReplySurface(json);
  }

  Map<Object?, Object?> get _create => message['createSurface']! as Map;

  /// The reply this surface draws.
  String get surfaceId => _create['surfaceId']! as String;

  /// Its components but the root, in stored order.
  Iterable<Map<Object?, Object?>> get _components =>
      (_create['components']! as List).whereType<Map<Object?, Object?>>().where(
        (c) => c['component'] != FrontReplyComponents.reply,
      );

  /// Whether it draws nothing but her words: such a reply needs no surface.
  bool get wordsOnly =>
      _components.every((c) => c['component'] == FrontReplyComponents.text);

  /// Whether it draws something to point at while she speaks: cards or a
  /// chart, not her words or the replies to tap.
  bool get hasVisual => _components.any(
    (c) =>
        c['component'] != FrontReplyComponents.text &&
        c['component'] != FrontReplyComponents.quickReplies,
  );

  /// The tasks it shows, in order: those her cards list, then those a
  /// closed-task lookup found — what "that one" may mean next turn.
  List<String> get taskIds => [
    for (final component in _components)
      if (component['component'] == FrontReplyComponents.taskCards)
        for (final card in FrontEntityReference.listFromJson(
          component['items'],
        ))
          if (card.kind == FrontEntityKind.task) card.id,
    if (_create['dataModel'] case {FrontReplyData.closedTasks: final closed})
      for (final card in FrontClosedTaskCard.listFromJson(closed)) card.id,
  ];

  /// The pull requests its cards show, in order: what "that PR" may mean
  /// next turn.
  List<FrontPullRequestCard> get pullRequestCards => [
    for (final component in _components)
      if (component['component'] == FrontReplyComponents.pullRequestCards)
        ...frontPullRequestCardsFromJson(component['items']),
  ];

  @override
  String toString() => 'FrontReplySurface($surfaceId)';
}
