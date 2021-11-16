import 'dart:convert';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/blocs/journal/persistence_state.dart';
import 'package:wisely/classes/entry_text.dart';
import 'package:wisely/theme.dart';
import 'package:wisely/widgets/buttons.dart';

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
              Button('Save', onPressed: _save),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: EditorWidget(controller: _controller),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    Key? key,
    required QuillController controller,
  })  : _controller = controller,
        super(key: key);

  final QuillController _controller;

  void keyFormatter(RawKeyEvent event, String char, Attribute attribute) {
    if (event.data.isMetaPressed && event.character == char) {
      if (_controller
          .getSelectionStyle()
          .attributes
          .keys
          .contains(attribute.key)) {
        _controller.formatSelection(Attribute.clone(attribute, null));
      } else {
        _controller.formatSelection(attribute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        keyFormatter(event, 'b', Attribute.bold);
        keyFormatter(event, 'i', Attribute.italic);
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          height: 300,
          color: AppColors.editorBgColor,
          child: Column(
            children: [
              QuillToolbar.basic(
                controller: _controller,
                showColorButton: false,
                showBackgroundColorButton: false,
                showListCheck: false,
                showIndent: false,
                showQuote: false,
                showSmallButton: false,
                showImageButton: false,
                showLink: false,
                showUnderLineButton: false,
              ),
              Expanded(
                child: QuillEditor.basic(
                  controller: _controller,
                  readOnly: false, // true for view only mode
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
