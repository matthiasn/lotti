import 'package:lotti/classes/journal_entities.dart';

/// How the app addresses a person in a sentence or a tight slot.
extension PersonShortName on RelationshipEntry {
  /// The nickname when there is one, else the full name: *Pip*, not
  /// *Commander Pip Frostbeak*, in "Call Pip?", "About Pip", "Add a task for
  /// Pip" and the folded hero's title — every place where the full name
  /// would wrap a question onto two lines or end under an ellipsis.
  String get shortName {
    final nickname = data.nickname?.trim();
    return nickname == null || nickname.isEmpty ? data.title : nickname;
  }
}
