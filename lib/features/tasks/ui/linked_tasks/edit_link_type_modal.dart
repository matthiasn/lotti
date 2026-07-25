import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';

/// Modal for retyping and/or flipping the direction of an existing typed
/// relationship link in place (same link id), rather than deleting and
/// recreating it. Reuses [RelationshipTypeSelector], pre-selected to the
/// link's current type and direction.
abstract final class EditLinkTypeModal {
  /// Shows the modal. Callers rely on the live
  /// [taskLinkGroupsControllerProvider] stream to reflect a successful edit
  /// — there is nothing meaningful to return.
  static Future<void> show({
    required BuildContext context,
    required String linkId,
    required EntryLinkType currentType,
    required TaskLinkDirection currentDirection,
    required String linkedTaskTitle,
  }) async {
    final relation = ValueNotifier(
      DirectedRelation(
        currentType,
        inverse: currentDirection == TaskLinkDirection.incoming,
      ),
    );
    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.editLinkTypeTitle,
        padding: EdgeInsets.zero,
        stickyActionBarBuilder: (_) => _EditLinkTypeApplyFooter(
          linkId: linkId,
          currentDirection: currentDirection,
          relation: relation,
        ),
        builder: (_) => _EditLinkTypeBody(
          relation: relation,
          linkedTaskTitle: linkedTaskTitle,
        ),
      );
    } finally {
      relation.dispose();
    }
  }
}

class _EditLinkTypeBody extends StatelessWidget {
  const _EditLinkTypeBody({
    required this.relation,
    required this.linkedTaskTitle,
  });

  final ValueNotifier<DirectedRelation> relation;

  /// The task on the other end. Without it the modal reads "This task… / Is
  /// blocked by" with no object — a sentence with its subject missing.
  final String linkedTaskTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The Save footer is a sticky overlay, not a sibling — without reserving
    // its height the relation dropdown renders underneath it and the modal
    // shows a title and a Save bar with nothing to edit.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        DesignSystemGlassActionFooter.reservedHeightFor(context) +
            tokens.spacing.step5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<DirectedRelation>(
            valueListenable: relation,
            builder: (context, value, _) => RelationshipTypeSelector(
              selected: value,
              onChanged: (next) => relation.value = next,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Padding(
            // On the dropdown's own value rail, so the task completing the
            // sentence lines up under the phrase rather than hanging left of it.
            padding: EdgeInsets.only(left: tokens.spacing.step5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.messages.editLinkTypeCounterpartLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  linkedTaskTitle,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditLinkTypeApplyFooter extends ConsumerStatefulWidget {
  const _EditLinkTypeApplyFooter({
    required this.linkId,
    required this.currentDirection,
    required this.relation,
  });

  final String linkId;
  final TaskLinkDirection currentDirection;
  final ValueNotifier<DirectedRelation> relation;

  @override
  ConsumerState<_EditLinkTypeApplyFooter> createState() =>
      _EditLinkTypeApplyFooterState();
}

class _EditLinkTypeApplyFooterState
    extends ConsumerState<_EditLinkTypeApplyFooter> {
  /// `swapDirection` is computed against the link's *pre-edit* direction, so a
  /// second Save while the first is still in flight would compute the same
  /// flip again from the same stale baseline and reverse the link back.
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return buildPickerApplyFooter(
      context: context,
      label: context.messages.saveButton,
      onTap: () async {
        if (_saving) return;
        setState(() => _saving = true);
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        final messages = context.messages;

        final selected = widget.relation.value;
        final newIsOutgoing = !selected.inverse;
        final oldIsOutgoing =
            widget.currentDirection == TaskLinkDirection.outgoing;
        final swapDirection = newIsOutgoing != oldIsOutgoing;

        final saved = await ref
            .read(journalRepositoryProvider)
            .updateLinkType(
              linkId: widget.linkId,
              newType: selected.type,
              swapDirection: swapDirection,
            );

        if (!mounted) return;
        setState(() => _saving = false);
        if (!saved) {
          messenger.showSnackBar(
            SnackBar(content: Text(messages.editLinkTypeFailedMessage)),
          );
          return;
        }

        await HapticFeedback.mediumImpact();
        navigator.pop();
      },
    );
  }
}
