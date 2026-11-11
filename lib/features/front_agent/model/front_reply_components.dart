import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';

/// The component types of her reply's GenUI catalog, by the name an A2UI
/// component carries as its `component`.
abstract final class FrontReplyComponentTypes {
  /// The reply itself: its parts' components, in order (`parts`: ids).
  static const reply = 'FrontReply';

  /// Her words (`markdown`).
  static const text = 'FrontText';

  /// Tasks and projects as preview cards (`cards`), with the window a due
  /// answer's one list was read from (`due`).
  static const cards = 'FrontCards';

  /// The cards of a closed-task answer (`tasks`).
  static const closedTasks = 'FrontClosedTasks';

  /// The logged-time chart (`chart`).
  static const loggedTimeChart = 'FrontLoggedTimeChart';

  /// The pull-request charts (`chart`).
  static const pullRequestChart = 'FrontPullRequestChart';
}

/// The A2UI components that draw a reply of [parts]: a root `FrontReply`
/// listing, in order, one component per part it can draw.
///
/// Every component's data comes from the reply as stored — her words, the
/// cards she listed, and the closed tasks and charts the turn's lookups
/// made ([closedTasks], [loggedTime], [pullRequests]) — never from the
/// model: a part whose data the reply does not carry draws nothing. A card
/// already shown in [shown] (a closed-task card or a door's preview) is not
/// listed again, and a list left empty is left out. A due answer's window
/// ([due]) labels its list only when the reply has exactly one: separate
/// lists are named by her own words above each. An attachment placed twice
/// is drawn once, where it first stands.
List<Map<String, Object?>> frontReplyComponents({
  required List<FrontReplyPart> parts,
  List<FrontClosedTaskCard>? closedTasks,
  FrontLoggedTimeChart? loggedTime,
  FrontPullRequestChart? pullRequests,
  FrontDueSection? due,
  Set<String> shown = const {},
}) {
  final lists = parts.whereType<FrontReplyCards>().length;
  // An attachment is drawn once, at its first place: two components may not
  // share its id.
  final placed = <FrontReplyAttachment>{};
  final components = <Map<String, Object?>>[
    for (final (index, part) in parts.indexed)
      ?switch (part) {
        FrontReplyText(:final markdown) => {
          'id': 'text-$index',
          'component': FrontReplyComponentTypes.text,
          'markdown': markdown,
        },
        FrontReplyCards(:final cards) => switch ([
          for (final card in cards)
            if (!shown.contains(card.id)) card.toJson(),
        ]) {
          [] => null,
          final listed => {
            'id': 'cards-$index',
            'component': FrontReplyComponentTypes.cards,
            'cards': listed,
            if (lists == 1 && due != null) 'due': due.toJson(),
          },
        },
        FrontReplyShow(:final attachment) when !placed.add(attachment) => null,
        FrontReplyShow(:final attachment) => switch (attachment) {
          FrontReplyAttachment.closedTasks when closedTasks != null => {
            'id': attachment.wireName,
            'component': FrontReplyComponentTypes.closedTasks,
            'tasks': [for (final task in closedTasks) task.toJson()],
          },
          FrontReplyAttachment.loggedTimeChart when loggedTime != null => {
            'id': attachment.wireName,
            'component': FrontReplyComponentTypes.loggedTimeChart,
            'chart': loggedTime.toJson(),
          },
          FrontReplyAttachment.pullRequestChart when pullRequests != null => {
            'id': attachment.wireName,
            'component': FrontReplyComponentTypes.pullRequestChart,
            'chart': pullRequests.toJson(),
          },
          _ => null,
        },
      },
  ];
  return [
    {
      'id': 'root',
      'component': FrontReplyComponentTypes.reply,
      'parts': [for (final component in components) component['id']],
    },
    ...components,
  ];
}
