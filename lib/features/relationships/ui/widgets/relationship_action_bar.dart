import 'package:lotti/features/design_system/components/speak_add_action_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The person page's sticky bottom bar (design panel 2026-10-15): one verb
/// to capture, by voice first, and one door to everything else.
///
/// * **Speak** — the filled pill, and the app's mic: talk about this person
///   right after you talked *to* them.
/// * **+ Add** — the create menu: a note, a task, photos, a typed check-in.
///   Labelled, and its own glyph, never a second `⋯`: the hero's `⋯` already
///   means "manage this person". A third, unlabelled disc for the typed
///   check-in made the reader guess which of three ways in was the right
///   one (design panel 2026-10-15, round 1); it is one row of this menu.
///
/// Calling moved out of the bar into the labelled contact row under the
/// name, behind a confirmation: in the bar, an unlabelled handset beside the
/// capture verbs could place a call by a mis-tap.
///
/// The shared [DesignSystemSpeakAddBar] — the glass strip the task page
/// docks, and the bar the goal page ends with too — under this page's own
/// words.
class RelationshipActionBar extends StatelessWidget {
  const RelationshipActionBar({
    required this.onSpeak,
    required this.onAdd,
    required this.personName,
    super.key,
  });

  final VoidCallback onSpeak;
  final VoidCallback onAdd;

  /// The person's short name, for the + control's accessible name.
  final String personName;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return DesignSystemSpeakAddBar(
      speakKey: const ValueKey('person-action-speak'),
      addKey: const ValueKey('person-action-add'),
      speakLabel: messages.relationshipSpeak,
      addLabel: messages.relationshipAddAction,
      addSemanticLabel: messages.relationshipAddToTimeline(personName),
      onSpeak: onSpeak,
      onAdd: onAdd,
    );
  }
}
