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
        builder: (_) => _EditLinkTypeBody(relation: relation),
      );
    } finally {
      relation.dispose();
    }
  }
}

class _EditLinkTypeBody extends StatelessWidget {
  const _EditLinkTypeBody({required this.relation});

  final ValueNotifier<DirectedRelation> relation;

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
      child: ValueListenableBuilder<DirectedRelation>(
        valueListenable: relation,
        builder: (context, value, _) => RelationshipTypeSelector(
          selected: value,
          onChanged: (next) => relation.value = next,
        ),
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
