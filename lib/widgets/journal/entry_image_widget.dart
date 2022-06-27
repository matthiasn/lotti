import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';

class EntryImageWidget extends StatefulWidget {
  const EntryImageWidget({
    super.key,
    required this.journalImage,
    required this.focusNode,
  });

  final JournalImage journalImage;
  final FocusNode focusNode;

  @override
  State<EntryImageWidget> createState() => _EntryImageWidgetState();
}

class _EntryImageWidgetState extends State<EntryImageWidget> {
  Directory? docDir;

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

      return GestureDetector(
        onTap: () {
          widget.focusNode.unfocus();
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<HeroPhotoViewRouteWrapper>(
              builder: (_) => HeroPhotoViewRouteWrapper(
                focusNode: widget.focusNode,
                imageProvider: FileImage(file),
              ),
            ),
          );
        },
        child: ColoredBox(
          color: Colors.black,
          child: Hero(
            tag: 'entry_img',
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: isMobile ? 400 : MediaQuery.of(context).size.width,
              ),
              child: Image.file(
                file,
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    } else {
      return Container();
    }
  }
}

// from https://github.com/bluefireteam/photo_view/blob/master/example/lib/screens/examples/hero_example.dart
class HeroPhotoViewRouteWrapper extends StatelessWidget {
  const HeroPhotoViewRouteWrapper({
    super.key,
    required this.focusNode,
    required this.imageProvider,
    this.backgroundDecoration,
    this.minScale,
    this.maxScale,
  });

  final ImageProvider imageProvider;
  final BoxDecoration? backgroundDecoration;
  final FocusNode focusNode;
  final dynamic minScale;
  final dynamic maxScale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            constraints: BoxConstraints.expand(
              height: MediaQuery.of(context).size.height,
            ),
            child: PhotoView(
              imageProvider: imageProvider,
              backgroundDecoration: backgroundDecoration,
              minScale: minScale,
              maxScale: maxScale,
              heroAttributes: const PhotoViewHeroAttributes(tag: 'entry_img'),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              padding: const EdgeInsets.all(48),
              onPressed: () {
                getIt<AppRouter>().pop();
                focusNode.requestFocus();
              },
              icon: const Icon(
                MdiIcons.close,
                size: 48,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
