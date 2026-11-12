import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

/// The task row a found pull request is held by.
FrontIndexRow pullRequestTask(String id, {String? title}) => FrontIndexRow(
  kind: FrontDestinationKind.task,
  id: id,
  title: title ?? 'Task $id',
);

/// Pull request `penguin/colony#<number>` as `find_pull_requests` hands it
/// over, held by task [taskId].
FrontFoundPullRequest foundPullRequest(
  int number, {
  String taskId = 'ledger',
  String? title,
  String? taskTitle,
  String? oneLiner,
  DateTime? createdAt,
  DateTime? mergedAt,
}) => FrontFoundPullRequest(
  key: 'penguin/colony#$number',
  title: title ?? 'Pull request $number',
  task: pullRequestTask(taskId, title: taskTitle),
  oneLiner: oneLiner,
  createdAt: createdAt,
  mergedAt: mergedAt,
);
