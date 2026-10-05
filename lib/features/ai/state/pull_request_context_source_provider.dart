import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/pull_request_context_source.dart';

/// Where a task's pull requests come from as prompt context: the coding
/// prompt and the task agent read it. Null until the composition root wires
/// the GitHub feature's context service; the AI and agent layers do not
/// depend on GitHub, and without it a prompt simply goes out without the
/// pull request section.
final pullRequestContextSourceProvider = Provider<PullRequestContextSource?>(
  (ref) => null,
  name: 'pullRequestContextSourceProvider',
);
