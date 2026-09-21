import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The person's reminder interval, in every enrolled state, as the header's
/// one door to changing it.
///
/// The interval used to show only while the person was on track ("On track ·
/// Weekly") and vanished the moment they were due, and changing it meant the
/// pencil, then scrolling past the photo and the names to the Reminders
/// card. The pill says it in every state and opens [PersonRemindersSheet].
/// Shown only for an enrolled person: someone without reminders is offered
/// them by the briefing card, which asks how often before it turns them on.
class PersonRemindersPill extends StatelessWidget {
  const PersonRemindersPill({required this.relationship, super.key});

  final RelationshipEntry relationship;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final quiet = tokens.colors.text.mediumEmphasis;
    final cadence = relationshipCadenceLabel(
      context,
      relationshipShownCadenceDays(relationship.data.checkInCadenceDays),
    );
    // One node that says what the pill is and that it acts: the bell and the
    // chevron are decoration to a screen reader.
    return Semantics(
      button: true,
      label: context.messages.relationshipRemindersPillSemantics(cadence),
      excludeSemantics: true,
      child: DsPill(
        key: const ValueKey('person-pill-reminders'),
        variant: DsPillVariant.filled,
        shape: DsPillShape.tag,
        leading: Icon(LottiIcons.notification, size: IconSizes.s, color: quiet),
        trailing: Icon(LottiIcons.chevronDown, size: IconSizes.s, color: quiet),
        labelColor: quiet,
        label: cadence,
        onTap: () => showPersonRemindersSheet(
          context: context,
          relationship: relationship,
        ),
      ),
    );
  }
}

/// Opens [PersonRemindersSheet] for [relationship].
Future<void> showPersonRemindersSheet({
  required BuildContext context,
  required RelationshipEntry relationship,
}) {
  final tokens = context.designTokens;
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.relationshipRemindersSheetTitle,
    padding: EdgeInsets.fromLTRB(
      tokens.spacing.step5,
      tokens.spacing.step2,
      tokens.spacing.step5,
      tokens.spacing.step6,
    ),
    builder: (_) => PersonRemindersSheet(relationship: relationship),
  );
}

/// How often, and off: the two decisions about a person's reminders, one
/// tap each. A pick saves at once and closes the sheet — there is nothing
/// else here to fill in first, so a separate Save would only be a second
/// tap. An interval change re-runs the person's deterministic evaluation
/// through the same lazy-create call every enrolment door uses, so the new
/// rhythm takes effect now rather than at the next daily tick.
class PersonRemindersSheet extends ConsumerStatefulWidget {
  const PersonRemindersSheet({required this.relationship, super.key});

  final RelationshipEntry relationship;

  @override
  ConsumerState<PersonRemindersSheet> createState() =>
      _PersonRemindersSheetState();
}

class _PersonRemindersSheetState extends ConsumerState<PersonRemindersSheet> {
  bool _saving = false;

  int get _shown => relationshipShownCadenceDays(
    widget.relationship.data.checkInCadenceDays,
  );

  /// Writes [updated] and closes the sheet; a refused or failed write says
  /// so and keeps the sheet open, so the choice can be made again.
  Future<void> _save(RelationshipEntry updated) async {
    if (_saving) return;
    final messages = context.messages;
    final repository = ref.read(relationshipRepositoryProvider);
    final agentService = ref.read(relationshipAgentServiceProvider);
    setState(() => _saving = true);
    var saved = false;
    try {
      saved = await repository.updateRelationship(updated);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to update reminders',
        name: 'PersonRemindersSheet',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (saved) {
      ensureRelationshipAgentInBackground(
        agentService,
        updated,
        source: 'PersonRemindersSheet',
      );
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.relationshipErrorUpdateFailed,
      );
    }
  }

  void _pick(int days) {
    if (days == _shown) {
      Navigator.of(context).pop();
      return;
    }
    final relationship = widget.relationship;
    _save(
      relationship.copyWith(
        data: relationship.data.copyWith(checkInCadenceDays: days),
      ),
    );
  }

  /// Turning reminders off keeps the stored interval (the form's rule), so
  /// turning them back on later brings the same rhythm back.
  void _turnOff() {
    final relationship = widget.relationship;
    _save(
      relationship.copyWith(
        data: relationship.data.copyWith(important: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final shown = _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          messages.relationshipCadencePromptLabel,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        DsChoicePills<int>(
          key: const ValueKey('person-reminders-cadence'),
          value: shown,
          values: relationshipCadenceChoices(shown),
          labelFor: (days) => relationshipCadenceLabel(context, days),
          onSelected: _saving ? (_) {} : _pick,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemButton(
          key: const ValueKey('person-reminders-off'),
          label: messages.relationshipTurnRemindersOff,
          variant: DesignSystemButtonVariant.tertiary,
          alignsLabelToLeadingEdge: true,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: _saving ? null : _turnOff,
        ),
      ],
    );
  }
}
