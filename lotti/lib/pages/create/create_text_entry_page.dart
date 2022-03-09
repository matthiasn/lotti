import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';

class CreateTextEntryPage extends StatefulWidget {
  const CreateTextEntryPage({
    Key? key,
    @PathParam() this.linkedId,
  }) : super(key: key);

  final String? linkedId;

  @override
  State<CreateTextEntryPage> createState() => _CreateTextEntryPageState();
}

class _CreateTextEntryPageState extends State<CreateTextEntryPage> {
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
        linkedId: widget.linkedId,
        started: started,
      );
      HapticFeedback.heavyImpact();

      FocusScope.of(context).unfocus();
      context.router.pop();
    }

    return SingleChildScrollView(
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
    );
  }
}
