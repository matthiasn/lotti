import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_toast.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Stable keys for the "Save current filter as…" name modal.
@visibleForTesting
abstract final class SaveCurrentTaskFilterKeys {
  static const Key nameField = Key('save-current-filter-name-field');
  static const Key saveButton = Key('save-current-filter-save-button');
}

/// The single create verb shared by the rail "+ Save" chip and the sheet's
/// "Save current filter as…" row: snapshot the live tasks filter, prompt for a
/// name, then persist a new [SavedTaskFilter] and promote it in the MRU order.
///
/// Returns the created filter, or null when the user dismissed the name modal
/// (or entered only whitespace). The live filter is captured *before* the modal
/// opens so the persisted shape is exactly what the user is looking at.
Future<SavedTaskFilter?> promptSaveCurrentTaskFilter(
  BuildContext context,
  WidgetRef ref,
) async {
  final pageState = ref.read(journalPageControllerProvider(true));
  final filter = liveTasksFilterFor(pageState);

  final name = await promptTaskFilterName(context);
  if (name == null) return null;
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  // The name modal is an async gap: bail if the caller unmounted so the
  // Riverpod reads below never touch a disposed WidgetRef.
  if (!context.mounted) return null;

  try {
    final created = await ref
        .read(savedTaskFiltersControllerProvider.notifier)
        .create(name: trimmed, filter: filter);
    // `create` is another async gap — the filter is persisted regardless, so
    // return it, but skip the MRU touch/toast when the ref/context are gone.
    if (!context.mounted) return created;
    ref.read(savedTaskFilterMruProvider.notifier).touch(created.id);
    showSavedTaskFilterSavedToast(context, name: created.name);
    return created;
  } catch (error, stackTrace) {
    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomain.tasks,
        error,
        stackTrace: stackTrace,
        subDomain: 'saveCurrentFilter',
      );
    }
    return null;
  }
}

/// Shows the shared name-entry modal and returns the committed text (or null
/// on cancel/dismiss). Reuses the existing "Name this filter" copy so the rail,
/// sheet "Save current filter as…", and the in-sheet Rename all speak with one
/// voice. [initialValue] pre-fills the field (used by Rename).
Future<String?> promptTaskFilterName(
  BuildContext context, {
  String initialValue = '',
}) {
  return ModalUtils.showSinglePageModal<String>(
    context: context,
    title: context.messages.tasksSavedFiltersSavePopupTitle,
    builder: (modalContext) => _SaveFilterNameForm(initialValue: initialValue),
  );
}

class _SaveFilterNameForm extends StatefulWidget {
  const _SaveFilterNameForm({required this.initialValue});

  final String initialValue;

  @override
  State<_SaveFilterNameForm> createState() => _SaveFilterNameFormState();
}

class _SaveFilterNameFormState extends State<_SaveFilterNameForm> {
  // The form owns its controller (and focus node) so they outlive the modal's
  // close animation — disposing them externally via the modal future would
  // tear them down while the closing TextField still references them.
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late bool _canSave = widget.initialValue.trim().isNotEmpty;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Post-frame focus instead of `autofocus: true`: the latter schedules a
    // caret-on-screen pass during the modal's open animation, which trips an
    // EditableText assertion under the test harness.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: SaveCurrentTaskFilterKeys.nameField,
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.done,
          onChanged: (value) {
            final next = value.trim().isNotEmpty;
            if (next != _canSave) setState(() => _canSave = next);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: messages.tasksSavedFiltersSavePopupHint,
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        FilledButton(
          key: SaveCurrentTaskFilterKeys.saveButton,
          onPressed: _canSave ? _submit : null,
          child: Text(messages.tasksSavedFiltersSavePopupSave),
        ),
      ],
    );
  }
}
