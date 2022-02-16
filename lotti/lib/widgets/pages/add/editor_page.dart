import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    Key? key,
    this.linked,
  }) : super(key: key);

  final JournalEntity? linked;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final QuillController _controller = makeController();
  final FocusNode _focusNode = FocusNode();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  DateTime started = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext _context) {
    void _save() async {
      persistenceLogic.createTextEntry(
        entryTextFromController(_controller),
        linked: widget.linked,
        started: started,
      );
      HapticFeedback.heavyImpact();

      FocusScope.of(context).unfocus();
      Navigator.pop(context);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.headerBgColor,
        foregroundColor: AppColors.appBarFgColor,
      ),
      backgroundColor: AppColors.bodyBgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
              child: EditorWidget(
                controller: _controller,
                focusNode: _focusNode,
                saveFn: _save,
                minHeight: 200,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
