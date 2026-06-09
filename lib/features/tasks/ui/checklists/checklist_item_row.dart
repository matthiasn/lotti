import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

part 'checklist_item_row_state.dart';

/// Duration for the archive SnackBar countdown.
const kChecklistArchiveDuration = Duration(seconds: 2);

/// Duration for the delete SnackBar countdown.
const kChecklistDeleteDuration = Duration(seconds: 5);

/// A single checklist item row, provider-aware and using the new visual design.
///
/// Replaces the old `ChecklistItemWrapper` + `ChecklistItemWidget` +
/// `ChecklistItemWithSuggestionWidget` stack.
///
/// Features:
/// - Watches its own [checklistItemControllerProvider] for live updates.
/// - Swipe right → archive/unarchive; swipe left → delete with undo.
/// - Long-press anywhere on the row to drag via `super_drag_and_drop` —
///   handles BOTH within-list reorder (routed through the controller's
///   same-list branch) and cross-checklist moves. The drag-handle icon is
///   a visual affordance only; wiring a [ReorderableDragStartListener] there
///   would win the gesture race and trap drags inside the source list.
/// - AI completion suggestion pulsing indicator.
/// - Animated hide when filter is "open only" and item is completed/archived.
class ChecklistItemRow extends ConsumerStatefulWidget {
  const ChecklistItemRow({
    required this.itemId,
    required this.checklistId,
    required this.taskId,
    required this.index,
    this.hideIfChecked = false,
    this.hideIfUnchecked = false,
    this.showDivider = false,
    super.key,
  });

  final String itemId;
  final String checklistId;
  final String taskId;
  final int index;

  /// When true, completed/archived items animate out after a short hold.
  final bool hideIfChecked;

  /// When true, uncompleted items are hidden (for the "Done" filter tab).
  final bool hideIfUnchecked;

  /// Whether to show a divider below this row.
  final bool showDivider;

  @override
  ConsumerState<ChecklistItemRow> createState() => _ChecklistItemRowState();
}
