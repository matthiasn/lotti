import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
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
    final selectedType = ValueNotifier(currentType);
    final inverse = ValueNotifier(
      currentDirection == TaskLinkDirection.incoming,
    );
    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.editLinkTypeTitle,
        padding: EdgeInsets.zero,
        stickyActionBarBuilder: (_) => _EditLinkTypeApplyFooter(
          linkId: linkId,
          currentDirection: currentDirection,
          selectedType: selectedType,
          inverse: inverse,
        ),
        builder: (_) =>
            _EditLinkTypeBody(selectedType: selectedType, inverse: inverse),
      );
    } finally {
      selectedType.dispose();
      inverse.dispose();
    }
  }
}

class _EditLinkTypeBody extends StatelessWidget {
  const _EditLinkTypeBody({required this.selectedType, required this.inverse});

  final ValueNotifier<EntryLinkType> selectedType;
  final ValueNotifier<bool> inverse;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        0,
        tokens.spacing.step5,
        tokens.spacing.step5,
      ),
      child: ValueListenableBuilder<EntryLinkType>(
        valueListenable: selectedType,
        builder: (context, type, _) => ValueListenableBuilder<bool>(
          valueListenable: inverse,
          builder: (context, isInverse, _) => RelationshipTypeSelector(
            selectedType: type,
            inverse: isInverse,
            onTypeChanged: (newType) {
              selectedType.value = newType;
              inverse.value = false;
            },
            onInverseChanged: (value) => inverse.value = value,
          ),
        ),
      ),
    );
  }
}

class _EditLinkTypeApplyFooter extends ConsumerWidget {
  const _EditLinkTypeApplyFooter({
    required this.linkId,
    required this.currentDirection,
    required this.selectedType,
    required this.inverse,
  });

  final String linkId;
  final TaskLinkDirection currentDirection;
  final ValueNotifier<EntryLinkType> selectedType;
  final ValueNotifier<bool> inverse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return buildPickerApplyFooter(
      context: context,
      label: context.messages.saveButton,
      onTap: () async {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        final messages = context.messages;

        final type = selectedType.value;
        final isInverse = inverse.value;
        final swap = type != EntryLinkType.basic && isInverse;
        final newIsOutgoing = !swap;
        final oldIsOutgoing = currentDirection == TaskLinkDirection.outgoing;
        final swapDirection = newIsOutgoing != oldIsOutgoing;

        final saved = await ref
            .read(journalRepositoryProvider)
            .updateLinkType(
              linkId: linkId,
              newType: type,
              swapDirection: swapDirection,
            );

        if (!context.mounted) return;
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
