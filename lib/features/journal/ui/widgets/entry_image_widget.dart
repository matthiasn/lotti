import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:photo_view/photo_view.dart';

class EntryImageWidget extends ConsumerWidget {
  const EntryImageWidget(this.journalImage, {super.key});

  final JournalImage journalImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: journalImage.meta.id);
    final notifier = ref.read(provider.notifier);
    final file = File(getFullImagePath(journalImage));
    final focusNode = notifier.focusNode;

    return GestureDetector(
      onTap: () {
        focusNode.unfocus();
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<HeroPhotoViewRouteWrapper>(
            builder: (_) => HeroPhotoViewRouteWrapper(
              focusNode: focusNode,
              file: file,
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
  }
}

// from https://github.com/bluefireteam/photo_view/blob/master/example/lib/screens/examples/hero_example.dart
class HeroPhotoViewRouteWrapper extends StatelessWidget {
  const HeroPhotoViewRouteWrapper({
    required this.focusNode,
    required this.file,
    super.key,
    this.backgroundDecoration,
  });

  final File file;
  final BoxDecoration? backgroundDecoration;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final imageProvider = FileImage(file);

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
              heroAttributes: const PhotoViewHeroAttributes(tag: 'entry_img'),
              minScale: PhotoViewComputedScale.contained,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              padding: const EdgeInsets.all(48),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
              icon: Stack(
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 12,
                      sigmaY: 12,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 32,
                    ),
                  ),
                  const Icon(
                    Icons.close_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
