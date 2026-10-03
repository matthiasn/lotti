import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:lotti/features/github/state/github_providers.dart';

/// Pins the stored GitHub token's status at [status], for what is gated on
/// it: the task's "Pull request tracking" action and a category's
/// repository.
Override gitHubTokenStatusOverride(GitHubTokenStatus status) =>
    gitHubTokenStatusProvider.overrideWith(() => _FixedTokenStatus(status));

class _FixedTokenStatus extends GitHubTokenStatusController {
  _FixedTokenStatus(this._status);

  final GitHubTokenStatus _status;

  @override
  Future<GitHubTokenStatus> build() async => _status;
}
