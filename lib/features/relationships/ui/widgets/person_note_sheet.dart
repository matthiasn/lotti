import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_name.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the sheet for a note about [person]: a new one, or [note] to edit.
///
/// A note is the place for what is not a conversation — where you met, what
/// they love, a gift idea, a grandchild's school — which before had nowhere
/// to live but a fake check-in. *Pin to About* keeps it at the top of the
/// person's page instead of in the timeline.
Future<void> showPersonNoteSheet({
  required BuildContext context,
  required RelationshipEntry person,
  JournalEntry? note,
}) {
  final name = person.shortName;
  // The action modal's header, so the title sits on the same rail as the
  // field under it, like the create menu this sheet is opened from.
  return DsActionModal.show<void>(
    context: context,
    title: context.messages.relationshipNoteSheetTitle(name),
    builder: (sheetContext) => PersonNoteForm(person: person, note: note),
  );
}

/// The note sheet's body: the words, the pin, and the sheet's actions.
class PersonNoteForm extends ConsumerStatefulWidget {
  const PersonNoteForm({required this.person, this.note, super.key});

  final RelationshipEntry person;

  /// The note being edited; null for a new one.
  final JournalEntry? note;

  @override
  ConsumerState<PersonNoteForm> createState() => _PersonNoteFormState();
}

class _PersonNoteFormState extends ConsumerState<PersonNoteForm> {
  late final TextEditingController _text = TextEditingController(
    text: widget.note?.entryText?.plainText ?? '',
  );
  late bool _pinned = widget.note?.meta.starred ?? false;
  var _saving = false;

  /// The last save failed. Said under the field, inside the sheet: a toast
  /// raised from here is hosted by the page's messenger and would render
  /// behind the sheet it explains.
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() => _failed = false);

  bool get _canSave => !_saving && _text.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = ref.read(personTimelineRepositoryProvider);
    final note = widget.note;
    final saved = note == null
        ? await repository.createNote(
                person: widget.person,
                text: _text.text,
                pinned: _pinned,
              ) !=
              null
        : await repository.updateNote(note, text: _text.text, pinned: _pinned);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _failed = true;
    });
  }

  Future<void> _delete(JournalEntry note) async {
    setState(() => _saving = true);
    await ref.read(personTimelineRepositoryProvider).deleteNote(note);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final note = widget.note;
    void saveIfReady() {
      if (_canSave) unawaited(_save());
    }

    // ⌘/Ctrl+Enter saves, as in the check-in composer.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            saveIfReady,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            saveIfReady,
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignSystemTextarea(
            key: const ValueKey('person-note-text'),
            controller: _text,
            hintText: messages.relationshipNoteHint,
          errorText: _failed ? messages.relationshipNoteSaveFailed : null,
            minLines: 4,
            growWithContent: true,
            semanticsLabel: messages.relationshipNoteSheetTitle(
              widget.person.shortName,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          DesignSystemToggle(
            key: const ValueKey('person-note-pin'),
            value: _pinned,
            label: messages.relationshipNotePin,
            onChanged: (value) => setState(() => _pinned = value),
          ),
          SizedBox(height: tokens.spacing.step5),
          DesignSystemModalActionBar(
            primary: DesignSystemButton(
              key: const ValueKey('person-note-save'),
              label: messages.saveButtonLabel,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              onPressed: _canSave ? () => unawaited(_save()) : null,
            ),
            secondary: [
              if (note != null)
                DesignSystemButton(
                  key: const ValueKey('person-note-delete'),
                  label: messages.deleteButton,
                  variant: DesignSystemButtonVariant.danger,
                  onPressed: _saving ? null : () => unawaited(_delete(note)),
                ),
              DesignSystemButton(
                key: const ValueKey('person-note-cancel'),
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.quiet,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
