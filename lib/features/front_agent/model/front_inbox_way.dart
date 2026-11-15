/// A way an inbox item may go that she offers only where it fits the words:
/// a task with a coding prompt, a goal, a project, an event.
///
/// The other ways are the app's floor and never hers to leave out: making
/// it a task, keeping it as a note, leaving it.
enum FrontInboxWay {
  prompt,
  goal,
  project,
  event;

  static FrontInboxWay? fromName(Object? name) =>
      values.where((value) => value.name == name).firstOrNull;

  /// The ways [json] names, each once, in its order; a name this build does
  /// not know is left out. Null when [json] is no list: she named no ways,
  /// which is not the same as naming none.
  static List<FrontInboxWay>? listFromJson(Object? json) => json is! List
      ? null
      : {
          for (final name in json) ?fromName(name),
        }.toList();
}
