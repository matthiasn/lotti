import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The localized name of [cadence].
String agentWakeCadenceLabel(BuildContext context, AgentWakeCadence cadence) =>
    switch (cadence) {
      AgentWakeCadence.live => context.messages.agentWakeCadenceLive,
      AgentWakeCadence.hourly => context.messages.agentWakeCadenceHourly,
      AgentWakeCadence.recordingsOnly =>
        context.messages.agentWakeCadenceRecordingsOnly,
    };

/// Which level a cadence picker without its own choice inherits from.
enum AgentWakeCadenceInheritance {
  /// A task following its category.
  category,

  /// A category following the app default.
  appDefault,
}

/// A dropdown choosing an agent wake cadence, with an optional description.
///
/// The app default has no level above it, so it offers only the cadences.
/// A category or task also offers "inherit", shown with the cadence it
/// resolves to so the effective choice is never hidden; choosing it reports
/// `null`.
class AgentWakeCadenceField extends StatelessWidget {
  const AgentWakeCadenceField({
    required this.value,
    required this.onChanged,
    this.inheritance,
    this.inheritedCadence,
    this.description,
    super.key,
  }) : assert(
         (inheritance == null) == (inheritedCadence == null),
         'an inheriting picker needs the cadence it inherits',
       );

  /// The chosen cadence; `null` inherits [inheritedCadence].
  final AgentWakeCadence? value;

  /// Receives the chosen cadence, or `null` for "inherit".
  final ValueChanged<AgentWakeCadence?> onChanged;

  /// Where an unset choice comes from; `null` for the app default itself.
  final AgentWakeCadenceInheritance? inheritance;

  /// The cadence an unset choice resolves to.
  final AgentWakeCadence? inheritedCadence;

  /// Helper text under the dropdown.
  final String? description;

  static const _inheritId = 'inherit';

  String _inheritLabel(BuildContext context) {
    final inherited = agentWakeCadenceLabel(context, inheritedCadence!);
    return switch (inheritance!) {
      AgentWakeCadenceInheritance.category =>
        context.messages.agentWakeCadenceFollowCategory(inherited),
      AgentWakeCadenceInheritance.appDefault =>
        context.messages.agentWakeCadenceFollowDefault(inherited),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final chosen = value;
    final description = this.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemDropdown(
          label: context.messages.agentWakeCadenceLabel,
          inputLabel: chosen == null
              ? _inheritLabel(context)
              : agentWakeCadenceLabel(context, chosen),
          items: [
            if (inheritance != null)
              DesignSystemDropdownItem(
                id: _inheritId,
                label: _inheritLabel(context),
                selected: chosen == null,
              ),
            for (final cadence in AgentWakeCadence.values)
              DesignSystemDropdownItem(
                id: cadence.name,
                label: agentWakeCadenceLabel(context, cadence),
                selected: cadence == chosen,
              ),
          ],
          onItemPressed: (item) => onChanged(
            item.id == _inheritId ? null : AgentWakeCadence.fromName(item.id),
          ),
        ),
        if (description != null) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            description,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ],
    );
  }
}
