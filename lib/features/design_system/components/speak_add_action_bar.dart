import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The sticky bottom bar of a page about one subject the user talks about —
/// a person, a goal: one verb to capture, by voice first, and one door to
/// everything else.
///
/// * **Speak** — the filled pill, and the app's mic: one tap and the page's
///   recorder is listening.
/// * **+ Add** — the create menu, labelled and under its own glyph, never a
///   second `⋯`: the page's `⋯` already means "manage this".
///
/// The glass strip the task page docks, hugging and centred on the page's
/// reading column, so every detail page ends the same way. The person page
/// and the goal page share it, so the two can never drift in where the mic
/// is or what it is called.
class DesignSystemSpeakAddBar extends StatelessWidget {
  const DesignSystemSpeakAddBar({
    required this.speakLabel,
    required this.addLabel,
    required this.addSemanticLabel,
    required this.onSpeak,
    required this.onAdd,
    this.speakKey,
    this.addKey,
    super.key,
  });

  final String speakLabel;
  final String addLabel;

  /// The + control's accessible name: what it adds to, in words.
  final String addSemanticLabel;
  final VoidCallback onSpeak;
  final VoidCallback onAdd;
  final Key? speakKey;
  final Key? addKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
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
                  key: speakKey,
                  label: speakLabel,
                  icon: LottiIcons.mic,
                  fillColor: tokens.colors.interactive.enabled,
                  foregroundColor: tokens.colors.text.onInteractiveAlert,
                  onTap: onSpeak,
                ),
                DsGlassPill(
                  key: addKey,
                  label: addLabel,
                  icon: LottiIcons.add,
                  semanticLabel: addSemanticLabel,
                  onTap: onAdd,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
