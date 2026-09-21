import 'package:lotti/classes/entity_definitions.dart';

/// Upper bound on a knowledge brief, enforced by the field that edits it.
///
/// A brief is a framing paragraph or two in front of every prompt for the
/// category, not a document: past this it is pure prefill cost on every wake
/// and every coding prompt.
const categoryKnowledgeBriefMaxLength = 4000;

/// The brief the prompts for [category]'s tasks carry, or null when there is
/// nothing to carry: no category, no brief, or a brief cleared to whitespace.
///
/// Blank must read as absent so an emptied field never leaves an empty
/// `Category Knowledge` heading in every prompt.
String? categoryKnowledgeBriefOf(CategoryDefinition? category) {
  final brief = category?.knowledgeBrief?.trim();
  return brief == null || brief.isEmpty ? null : brief;
}
