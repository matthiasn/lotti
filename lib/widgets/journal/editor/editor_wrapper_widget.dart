import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

class EditorWrapperWidget extends StatefulWidget {
  const EditorWrapperWidget({
    super.key,
    @PathParam() required this.itemId,
    required this.popOnDelete,
    this.showTaskDetails = false,
  });

  final String itemId;
  final bool popOnDelete;
  final bool showTaskDetails;

  @override
  State<EditorWrapperWidget> createState() => _EditorWrapperWidgetState();
}

class _EditorWrapperWidgetState extends State<EditorWrapperWidget> {
  final JournalDb _db = getIt<JournalDb>();
  final FocusNode _focusNode = FocusNode();
  final EditorStateService _editorStateService = getIt<EditorStateService>();

  late final Stream<JournalEntity?> _stream =
      _db.watchEntityById(widget.itemId);

  bool showDetails = false;
  Directory? docDir;
  double editorHeight = (Platform.isIOS || Platform.isAndroid) ? 160 : 240;
  double imageTextEditorHeight =
      (Platform.isIOS || Platform.isAndroid) ? 160 : 240;

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        docDir = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
      stream: _stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final item = snapshot.data;
        if (item == null || item.meta.deletedAt != null) {
          return const SizedBox.shrink();
        }

        final controller = makeController(
          serializedQuill: _editorStateService.getDelta(widget.itemId) ??
              item.entryText?.quill,
          selection: _editorStateService.getSelection(widget.itemId),
        );

        controller.changes.listen((Tuple3<Delta, Delta, ChangeSource> event) {
          _editorStateService.saveTempState(
            id: widget.itemId,
            controller: controller,
            lastSaved: item.meta.updatedAt,
          );
        });

        controller.onSelectionChanged = (TextSelection selection) {
          _editorStateService.saveSelection(widget.itemId, selection);
        };

        void saveText() {
          _editorStateService.saveState(
            id: widget.itemId,
            controller: controller,
            lastSaved: item.meta.updatedAt,
          );

          if (isMobile) {
            _focusNode.unfocus();
          }
        }

        return item.maybeMap(
          journalImage: (JournalImage image) {
            return EditorWidget(
              controller: controller,
              focusNode: _focusNode,
              journalEntity: item,
              saveFn: saveText,
            );
          },
          orElse: () {
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
