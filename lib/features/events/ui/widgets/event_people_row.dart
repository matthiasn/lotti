import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Who the event was with: one chip per person — their face and name, which
/// opens their page — then a chip that changes who was there.
///
/// With nobody linked yet it is only the *Add people* chip, so a fresh event
/// is invited to say who it was with without growing an empty section. With
/// [onEditPeople] null the row is read-only: the people chips stay, the
/// change chip goes, and with nobody linked nothing renders at all.
class EventPeopleRow extends StatelessWidget {
  const EventPeopleRow({
    required this.people,
    this.onOpenPerson,
    this.onEditPeople,
    super.key,
  });

  final List<EventPerson> people;

  /// Opens a person's page (receives their relationship id).
  final ValueChanged<String>? onOpenPerson;

  /// Opens the picker for who was there.
  final VoidCallback? onEditPeople;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final edit = onEditPeople;
    if (people.isEmpty && edit == null) return const SizedBox.shrink();
    final open = onOpenPerson;

    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final person in people)
          DesignSystemChip(
            key: ValueKey('event-person-${person.id}'),
            label: person.name,
            avatar: FittedBox(
              child: PersonaAvatar(
                initial: personaInitial(person.name),
                id: person.id,
                imageId: person.avatarImageId,
                crop: person.avatarCrop,
              ),
            ),
            onPressed: open == null ? null : () => open(person.id),
          ),
        if (edit != null)
          DesignSystemChip(
            key: const ValueKey('event-people-edit'),
            label: people.isEmpty
                ? messages.eventsPeopleAdd
                : messages.eventsPeopleEdit,
            // Same chip as the people, told apart by its glyph: the
            // outlined filter treatment pads taller and would not sit level
            // with them on a shared line.
            leadingIcon: people.isEmpty
                ? LottiIcons.personAdd
                : LottiIcons.edit,
            onPressed: edit,
          ),
      ],
    );
  }
}
