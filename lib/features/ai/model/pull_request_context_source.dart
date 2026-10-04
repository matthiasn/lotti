/// Who reads a rendered pull request section.
enum PullRequestContextAudience {
  /// The coding prompt: it may see a stale pull request's last known state,
  /// labelled as such, because nothing is proposed from it.
  codingPrompt,

  /// The task agent's wake: it sees a pull request's state only when it is
  /// current, because what it reads can become a checklist suggestion
  /// (`SuggestRequiresRefresh` in `specs/tla/PullRequestSnapshot.tla`).
  taskAgent,
}

/// A task's linked pull requests as prompt context.
///
/// The port prompt builders depend on; the github feature implements it, so
/// the AI and agent features render pull requests without depending on
/// GitHub.
abstract interface class PullRequestContextSource {
  /// The task's pull requests, refreshed now, rendered for [audience]; empty
  /// when the task has none or this device holds no GitHub token.
  Future<String> contextFor(
    String taskId, {
    required PullRequestContextAudience audience,
  });
}
