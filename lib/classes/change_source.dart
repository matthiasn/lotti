/// Who last changed a field — the user (via UI) or an AI agent (tool call).
///
/// Used to track provenance for fields where user-set values must not be
/// overridden by agents (e.g. checklist item checked state, task language).
enum ChangeSource {
  /// Set by the user via the UI.
  user,

  /// Set by an AI agent tool call.
  agent,
}
