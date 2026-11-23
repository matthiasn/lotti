import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the editor's controls by.
abstract final class TaskDocumentEditorKeys {
  static const titleField = Key('task-document-editor-title');
  static const textField = Key('task-document-editor-text');
  static const save = Key('task-document-editor-save');
}

/// Opens the editor for [document] of task [taskId], or for a new document
/// on it when [document] is null.
Future<void> showTaskDocumentEditor(
  BuildContext context, {
  required String taskId,
  TaskDocumentEntry? document,
}) => ModalUtils.showSinglePageModal<void>(
  context: context,
  title: document == null
      ? context.messages.taskDocumentsNew
      : context.messages.taskDocumentsEdit,
  // The Save button is part of the form, not a sticky bar: the sheet's
  // default bottom inset would add a second gap below it.
  padding: EdgeInsets.all(context.designTokens.spacing.step5),
  builder: (_) => TaskDocumentEditor(taskId: taskId, document: document),
);

/// A document's title and its markdown text, saved as the user's own
/// version (ADR 0167).
///
/// The text opens on the document's current version, and saving writes a
/// new version over exactly that one: when the document moved on meanwhile
/// — another device, or an agent version confirmed — the save is refused
/// and the form stays open with the user's text, so nothing they typed is
/// lost and nothing newer is overwritten. Only what changed is written: a
/// new title renames, new text writes a version. A new document is created
/// on the first save; one with no text yet has no version.
class TaskDocumentEditor extends ConsumerStatefulWidget {
  const TaskDocumentEditor({required this.taskId, this.document, super.key});

  final String taskId;

  /// The document to edit; null for a new one.
  final TaskDocumentEntry? document;

  @override
  ConsumerState<TaskDocumentEditor> createState() => _TaskDocumentEditorState();
}

class _TaskDocumentEditorState extends ConsumerState<TaskDocumentEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.document?.data.title ?? '',
  );
  final TextEditingController _text = TextEditingController();

  /// The document saved to: [TaskDocumentEditor.document], or the one the
  /// first save created — so a retry after a failed text write edits it
  /// instead of creating a second document.
  late TaskDocumentEntry? _document = widget.document;

  /// The version the text was loaded from, which a save is written over.
  String? _baseVersionId;
  String _loadedText = '';
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onTitleChanged);
    _load();
  }

  void _onTitleChanged() => setState(() {});

  Future<void> _load() async {
    final document = widget.document;
    if (document != null) {
      final repository = ref.read(taskDocumentRepositoryProvider);
      // Read again rather than trusting the row the list handed over: the
      // version the form opens on is the one a save must be written over.
      final stored = await repository.document(document.id) ?? document;
      final version = await repository.currentVersion(stored);
      _baseVersionId = version?.id;
      _loadedText = version?.data.markdown ?? '';
      _text.text = _loadedText;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title
      ..removeListener(_onTitleChanged)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messages = context.messages;
    final title = _title.text.trim();
    final text = _text.text;
    final repository = ref.read(taskDocumentRepositoryProvider);
    setState(() {
      _saving = true;
      _error = null;
    });

    String? error;
    var document = _document;
    if (document == null) {
      document = await repository.create(taskId: widget.taskId, title: title);
      if (document == null) {
        error = messages.saveFailedRetry;
      } else {
        _document = document;
        // The band mounts once the new link is read back; the page waits
        // for it and scrolls there after the editor closes.
        ref
            .read(taskFocusControllerProvider(widget.taskId).notifier)
            .publishDocumentsFocus();
      }
    } else if (title != document.data.title &&
        !await repository.rename(document.id, title)) {
      error = messages.saveFailedRetry;
    }

    if (error == null && document != null && text != _loadedText) {
      final result = await repository.writeVersion(
        documentId: document.id,
        markdown: text,
        author: TaskDocumentAuthor.user,
        baseVersionId: _baseVersionId,
      );
      switch (result.status) {
        case TaskDocumentWriteStatus.written:
          _baseVersionId = result.version?.id;
          _loadedText = text;
        case TaskDocumentWriteStatus.stale:
          error = messages.taskDocumentsStale;
        case TaskDocumentWriteStatus.missing:
        case TaskDocumentWriteStatus.failed:
          error = messages.saveFailedRetry;
      }
    }

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final canSave = _loaded && !_saving && _title.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemTextInput(
          key: TaskDocumentEditorKeys.titleField,
          controller: _title,
          label: messages.taskDocumentsTitleLabel,
          enabled: _loaded,
          autofocus: widget.document == null,
          textCapitalization: TextCapitalization.sentences,
        ),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemTextarea(
          fieldKey: TaskDocumentEditorKeys.textField,
          controller: _text,
          label: messages.taskDocumentsTextLabel,
          hintText: messages.taskDocumentsTextHint,
          errorText: _error,
          enabled: _loaded,
          minLines: 10,
        ),
        SizedBox(height: tokens.spacing.step5),
        Align(
          alignment: Alignment.centerRight,
          child: DesignSystemButton(
            key: TaskDocumentEditorKeys.save,
            label: messages.saveButton,
            isLoading: _saving,
            onPressed: canSave ? _save : null,
          ),
        ),
      ],
    );
  }
}
