import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A setting of the agent, as a row of its editor's *Your agent* section: a
/// label in the fields' tier with the switch on its trailing edge, and a
/// quiet line under it saying what the switch turns on. One row for the
/// person's *Remind me to stay in touch* and the goal's *I'll answer what you
/// tell me*, so both editors set their agent the same way.
///
/// One labelled control, not a label sitting near a switch: a screen reader
/// reads [title] with the switch's state, and the label itself toggles.
class AgentSwitchRow extends StatelessWidget {
  const AgentSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.toggleKey,
    this.body,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Identity for the switch itself.
  final Key toggleKey;

  /// What the switch turns on, under the title; a widget so a host can keep
  /// it following live input (a person's name as it is typed).
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: DsQuietInk(
            onTap: () => onChanged(!value),
            builder: (BuildContext context, bool highlighted) => Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                DesignSystemToggle(
                  key: toggleKey,
                  value: value,
                  semanticsLabel: title,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
        if (body case final body?) ...[
          SizedBox(height: tokens.spacing.step1),
          DefaultTextStyle.merge(
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
            child: body,
          ),
        ],
      ],
    );
  }
}
