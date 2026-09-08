import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_surfaces.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One of the avatar sheet's flows — [PersonPhotoActions.chooseAvatar],
/// [PersonPhotoActions.adjustAvatar] or [PersonPhotoActions.removeAvatar] —
/// as the value a row pops the sheet with.
typedef PersonPhotoFlow =
    Future<PersonPhotoOutcome> Function(RelationshipEntry person);

/// Opens the sheet under a person's avatar (design 2026-09-08 turn 2): the
/// privacy line, then *Choose from library*, and — once there is a photo —
/// *Adjust crop* and *Remove photo*.
///
/// A row closes the sheet *first* and hands back the flow it chose; the flow
/// then runs here, over [context] — the page's, which outlives the sheet —
/// so the picker and the crop surface open over the page alone, and the
/// sheet never reappears under them for the frame it takes to close.
/// Resolves once the flow has finished, to what it came to; null when the
/// sheet was dismissed without choosing.
///
/// [actions] is the flows behind the rows. Null builds the real ones over
/// [context]; a test hands in fakes so no picker opens.
Future<PersonPhotoOutcome?> showPersonAvatarSheet({
  required BuildContext context,
  required RelationshipEntry relationship,
  PersonPhotoActions? actions,
}) async {
  final pageContext = context;
  final flow = await DsActionModal.show<PersonPhotoFlow>(
    context: context,
    title: context.messages.relationshipPhotoSheetTitle(
      relationship.data.title,
    ),
    builder: (sheetContext) => PersonAvatarSheet(
      relationship: relationship,
      pageContext: pageContext,
      actions: actions,
    ),
  );
  if (flow == null) return null;
  PersonPhotoOutcome outcome;
  try {
    outcome = await flow(relationship);
  } catch (e, s) {
    // A picker, a file copy or the crop surface that throws is, to the user,
    // a photo that could not be saved — the same failure the Photo card
    // reports — not an error escaping a tap handler.
    developer.log(
      'Failed to change a photo',
      name: 'PersonAvatarSheet',
      error: e,
      stackTrace: s,
    );
    outcome = PersonPhotoOutcome.failed;
  }
  // The one outcome the user has to hear about: they chose and cropped, and
  // the write was refused. Backing out says nothing, and success shows
  // itself — the avatar changes.
  if (outcome == PersonPhotoOutcome.failed && pageContext.mounted) {
    pageContext.showToast(
      tone: DesignSystemToastTone.error,
      title: pageContext.messages.relationshipPhotoSaveFailed,
    );
  }
  return outcome;
}

/// The rows of the avatar sheet. Each one pops the sheet with the flow it
/// stands for, and runs nothing itself: [showPersonAvatarSheet] runs the
/// flow once the sheet is gone.
class PersonAvatarSheet extends ConsumerWidget {
  const PersonAvatarSheet({
    required this.relationship,
    required this.pageContext,
    this.actions,
    super.key,
  });

  final RelationshipEntry relationship;

  /// The context the picker and the crop surface open from — the page under
  /// the sheet, which outlives it.
  final BuildContext pageContext;

  /// The flows behind the rows. Null builds the real ones over
  /// [pageContext]; a test hands in fakes so no picker opens.
  final PersonPhotoActions? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final hasPhoto = relationship.data.avatarImageId != null;
    final actions =
        this.actions ??
        productionPersonPhotoActions(
          ref,
          context: pageContext,
          relationship: relationship,
        );

    /// Closes the sheet with [flow] as its result.
    void choose(PersonPhotoFlow flow) => Navigator.of(context).pop(flow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.step3),
          child: Text(
            messages.relationshipPhotoPrivacy,
            key: const ValueKey('person-photo-privacy'),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
        DsActionRow(
          key: const ValueKey('person-photo-choose'),
          icon: LottiIcons.photoLibrary,
          title: messages.relationshipPhotoChoose,
          tone: DsActionRowTone.accent,
          trailing: DsActionRowTrailing.chevron,
          onTap: () => choose(actions.chooseAvatar),
        ),
        if (hasPhoto) ...[
          DsActionRow(
            key: const ValueKey('person-photo-adjust'),
            // No crop glyph in the icon tokens yet; a new one is a token
            // decision, so the pencil stands in.
            icon: LottiIcons.edit,
            title: messages.relationshipPhotoAdjustCrop,
            trailing: DsActionRowTrailing.chevron,
            onTap: () => choose(actions.adjustAvatar),
          ),
          DsActionRow(
            key: const ValueKey('person-photo-remove'),
            icon: LottiIcons.delete,
            title: messages.relationshipPhotoRemove,
            tone: DsActionRowTone.destructive,
            onTap: () => choose(actions.removeAvatar),
          ),
        ],
      ],
    );
  }
}
