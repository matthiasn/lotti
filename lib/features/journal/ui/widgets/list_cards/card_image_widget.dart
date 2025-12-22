import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';

class CardImageWidget extends StatefulWidget {
  const CardImageWidget({
    required this.journalImage,
    required this.height,
    super.key,
    this.fit = BoxFit.scaleDown,
  });

  final JournalImage journalImage;
  final int height;
  final BoxFit fit;

  @override
  State<CardImageWidget> createState() => _CardImageWidgetState();
}

class _CardImageWidgetState extends State<CardImageWidget> {
  int retries = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final file = File(getFullImagePath(widget.journalImage));

    if (!isTestEnv && retries < 10 && !file.existsSync()) {
      Future<void>.delayed(const Duration(milliseconds: 200)).then((_) {
        setState(() {
          retries++;
        });
      });
    }

    if (!file.existsSync()) {
      return Container();
    }

    return SizedBox(
      key: Key('${file.path}-$retries'),
      height: widget.height.toDouble(),
      child: Image.file(
        file,
        cacheHeight: widget.height * 3,
        height: widget.height.toDouble(),
        fit: widget.fit,
      ),
    );
  }
}
