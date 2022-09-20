import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path_provider/path_provider.dart';

class CardImageWidget extends StatefulWidget {
  const CardImageWidget({
    super.key,
    required this.journalImage,
    required this.height,
    this.fit = BoxFit.scaleDown,
  });

  final JournalImage journalImage;
  final int height;
  final BoxFit fit;

  @override
  State<CardImageWidget> createState() => _CardImageWidgetState();
}

class _CardImageWidgetState extends State<CardImageWidget> {
  Directory? docDir;
  int retries = 0;

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
    if (docDir != null) {
      final file =
          File(getFullImagePathWithDocDir(widget.journalImage, docDir!));

      if (retries < 10 && !file.existsSync()) {
        Future<void>.delayed(const Duration(milliseconds: 200)).then((_) {
          setState(() {
            retries++;
          });
        });
      }

      if (!file.existsSync()) {
        return Container();
      }

      return Container(
        key: Key('${file.path}-$retries'),
        color: colorConfig().coal,
        height: widget.height.toDouble(),
        child: Image.file(
          file,
          cacheHeight: widget.height * 3,
          height: widget.height.toDouble(),
          fit: widget.fit,
        ),
      );
    } else {
      return Container();
    }
  }
}
