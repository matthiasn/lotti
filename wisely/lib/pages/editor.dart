import 'dart:convert';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:uuid/uuid.dart';
import 'package:wisely/location.dart';
import 'package:wisely/theme.dart';
import 'package:wisely/widgets/buttons.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({Key? key}) : super(key: key);

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final QuillController _controller = QuillController.basic();
  DeviceLocation location = DeviceLocation();

  @override
  void initState() {
    super.initState();
  }

  void _save() async {
    setState(() {
      Delta _delta = _controller.document.toDelta();
      String _json = jsonEncode(_delta.toJson());
      String _md = deltaToMarkdown(_json);
    });

    const uuid = Uuid();
    DateTime created = DateTime.now();
    String timezone = await FlutterNativeTimezone.getLocalTimezone();

    var loc = await location.getCurrentLocation();

    DateTime updated = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Button('Save', onPressed: _save),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                //width: 400,
                padding: const EdgeInsets.all(8.0),
                height: 400,
                color: AppColors.editorBgColor,
                child: Column(
                  children: [
                    QuillToolbar.basic(controller: _controller),
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
          ],
        ),
      ),
    );
  }
}
