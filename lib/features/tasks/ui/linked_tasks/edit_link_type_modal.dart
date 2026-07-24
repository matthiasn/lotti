import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Modal for retyping and/or flipping the direction of an existing typed
/// relationship link in place (same link id), rather than deleting and
/// recreating it. Reuses [RelationshipTypeSelector], pre-selected to the
/// link's current type and direction relative to [anchorTaskId].
class EditLinkTypeModal extends ConsumerStatefulWidget {
  const EditLinkTypeModal({
    required this.linkId,
    required this.anchorTaskId,
    required this.otherTaskId,
    required this.currentType,
    required this.currentDirection,
    super.key,
  });

  final String linkId;
  final String anchorTaskId;
  final String otherTaskId;
  final EntryLinkType currentType;
  final TaskLinkDirection currentDirection;

  /// Shows the modal. Callers rely on the live
  /// [taskLinkGroupsControllerProvider] stream to reflect a successful edit
  /// — there is nothing meaningful to return.
  static Future<void> show({
    required BuildContext context,
    required String linkId,
    required String anchorTaskId,
    required String otherTaskId,
    required EntryLinkType currentType,
    required TaskLinkDirection currentDirection,
  }) {
    return ModalUtils.showBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => EditLinkTypeModal(
        linkId: linkId,
        anchorTaskId: anchorTaskId,
        otherTaskId: otherTaskId,
        currentType: currentType,
        currentDirection: currentDirection,
      ),
    );
  }

  @override
  ConsumerState<EditLinkTypeModal> createState() => _EditLinkTypeModalState();
}

class _EditLinkTypeModalState extends ConsumerState<EditLinkTypeModal> {
  late EntryLinkType _selectedType;
  late bool _inverse;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentType;
    _inverse = widget.currentDirection == TaskLinkDirection.incoming;
  }

  Future<void> _save() async {
    final swap = _selectedType != EntryLinkType.basic && _inverse;
    final newIsOutgoing = !swap;
    final oldIsOutgoing = widget.currentDirection == TaskLinkDirection.outgoing;
    final swapDirection = newIsOutgoing != oldIsOutgoing;

    final saved = await ref
        .read(journalRepositoryProvider)
        .updateLinkType(
          linkId: widget.linkId,
          newType: _selectedType,
          swapDirection: swapDirection,
        );

    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.editLinkTypeFailedMessage)),
        );
      }
      return;
    }

    await HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                key: const Key('edit_link_type_modal_handle'),
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              context.messages.editLinkTypeTitle,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            RelationshipTypeSelector(
              selectedType: _selectedType,
              inverse: _inverse,
              onTypeChanged: (type) => setState(() {
                _selectedType = type;
                _inverse = false;
              }),
              onInverseChanged: (value) => setState(() => _inverse = value),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.messages.cancelButton),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(context.messages.saveButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
