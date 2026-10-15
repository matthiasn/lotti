import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The person page's sticky bottom bar (design panel 2026-10-15): one verb
/// to capture, by voice first, and one door to everything else.
///
/// * **Speak** — the filled pill, and the app's mic: talk about this person
///   right after you talked *to* them.
/// * **Log check-in** — a round glass control for the typed check-in, for
///   when talking is not an option.
/// * **+** — the create menu: a note, a task, photos, a check-in. Its own
///   glyph, never a second `⋯`: the hero's `⋯` already means "manage this
///   person", and two kebabs with different scopes on one screen made the
///   reader guess which was which.
///
/// Calling moved out of the bar into the labelled contact row under the
/// name, behind a confirmation: in the bar, an unlabelled handset beside the
/// capture verbs could place a call by a mis-tap.
///
/// The same glass strip the task page docks, hugging and centred on the
/// page's reading column, so the two pages end the same way.
class RelationshipActionBar extends StatelessWidget {
  const RelationshipActionBar({
    required this.onSpeak,
    required this.onLogCheckIn,
    required this.onAdd,
    required this.personName,
    super.key,
  });

  final VoidCallback onSpeak;
  final VoidCallback onLogCheckIn;
  final VoidCallback onAdd;

  /// The person's short name, for the + control's accessible name.
  final String personName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;
    // The glass extends edge to edge and into the home-indicator inset; the
    // controls sit above it (the task bar's rule) and on the page's reading
    // column, so a desktop window does not stretch the pill across it.
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;

    return DesignSystemGlassStrip(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = detailContentInsets(
            context,
            availableWidth: constraints.maxWidth,
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              column.left,
              spacing.step4,
              column.right,
              spacing.step4 + safeBottomInset,
            ),
            // A `Wrap`, so at large text on a narrow phone the controls take
            // a second line instead of overflowing.
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: spacing.step4,
              runSpacing: spacing.step4,
              children: [
                DsGlassPill(
                  key: const ValueKey('person-action-speak'),
                  label: messages.relationshipSpeak,
                  icon: LottiIcons.mic,
                  fillColor: tokens.colors.interactive.enabled,
                  foregroundColor: tokens.colors.text.onInteractiveAlert,
                  onTap: onSpeak,
                ),
                DsGlassRoundButton(
                  key: const ValueKey('person-action-log-check-in'),
                  icon: LottiIcons.forum,
                  semanticLabel: messages.relationshipLogCheckIn,
                  onPressed: onLogCheckIn,
                ),
                DsGlassRoundButton(
                  key: const ValueKey('person-action-add'),
                  icon: LottiIcons.add,
                  semanticLabel: messages.relationshipAddToTimeline(
                    personName,
                  ),
                  onPressed: onAdd,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
