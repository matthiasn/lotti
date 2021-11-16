import 'dart:convert';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/blocs/journal/persistence_state.dart';
import 'package:wisely/classes/entry_text.dart';
import 'package:wisely/widgets/editor_widget.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({Key? key}) : super(key: key);

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  QuillController _controller = QuillController.basic();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext _context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (context, PersistenceState state) {
      void _save() async {
        Delta delta = _controller.document.toDelta();
        String json = jsonEncode(delta.toJson());
        String markdown = deltaToMarkdown(json);

        context.read<PersistenceCubit>().createTextEntry(
              EntryText(
                plainText: _controller.document.toPlainText(),
                markdown: markdown,
                quill: json,
              ),
            );

        _controller = QuillController.basic();

        FocusScope.of(context).unfocus();
      }

      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                    child: EditorWidget(
                      controller: _controller,
                      saveFn: _save,
                    )),
              ),
            ],
          ),
        ),
      );
    });
  }
}
