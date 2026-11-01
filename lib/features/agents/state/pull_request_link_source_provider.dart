import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/pull_request_link_source.dart';

/// Where the task agent lists the pull requests it may suggest linking, and
/// where a confirmed link is made. Null until the composition root wires the
/// GitHub feature's implementation; agents do not depend on GitHub, and
/// without it the agent is never offered the pull request tools.
final pullRequestLinkSourceProvider = Provider<PullRequestLinkSource?>(
  (ref) => null,
  name: 'pullRequestLinkSourceProvider',
);
