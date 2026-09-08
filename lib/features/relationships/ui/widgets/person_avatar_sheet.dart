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

/// Opens the sheet under a person's avatar (design 2026-09-08 turn 2): the
/// privacy line, then *Choose from library*, and — once there is a photo —
/// *Adjust crop* and *Remove photo*.
///
/// [context] is the *page's*: every row closes the sheet before it acts, and
/// the picker and the crop surface then open over the page, which is still
/// there. Resolves once the flow has finished, to what it came to.
Future<PersonPhotoOutcome?> showPersonAvatarSheet({
  required BuildContext context,
  required RelationshipEntry relationship,
}) async {
  final pageContext = context;
  final outcome = await DsActionModal.show<PersonPhotoOutcome>(
    context: context,
    title: context.messages.relationshipPhotoSheetTitle(
      relationship.data.title,
    ),
    builder: (sheetContext) => PersonAvatarSheet(
      relationship: relationship,
      pageContext: pageContext,
    ),
  );
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

/// The rows of the avatar sheet. Each one pops the sheet with the outcome
/// of the flow it started, so the caller of [showPersonAvatarSheet] learns
/// what happened without holding the sheet open over the picker.
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

    /// Closes the sheet, runs [flow] over the page, and reports its outcome
    /// through the sheet's own result.
    Future<void> run(
      Future<PersonPhotoOutcome> Function(RelationshipEntry) flow,
    ) async {
      final navigator = Navigator.of(context);
      final outcome = await flow(relationship);
      if (navigator.mounted) navigator.pop(outcome);
    }

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
          onTap: () => run(actions.chooseAvatar),
        ),
        if (hasPhoto) ...[
          DsActionRow(
            key: const ValueKey('person-photo-adjust'),
            // No crop glyph in the icon tokens yet; a new one is a token
            // decision, so the pencil stands in.
            icon: LottiIcons.edit,
            title: messages.relationshipPhotoAdjustCrop,
            trailing: DsActionRowTrailing.chevron,
            onTap: () => run(actions.adjustAvatar),
          ),
          DsActionRow(
            key: const ValueKey('person-photo-remove'),
            icon: LottiIcons.delete,
            title: messages.relationshipPhotoRemove,
            tone: DsActionRowTone.destructive,
            onTap: () => run(actions.removeAvatar),
          ),
        ],
      ],
    );
  }
}
