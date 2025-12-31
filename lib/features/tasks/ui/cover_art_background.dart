import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';

/// Background widget for displaying task cover art in SliverAppBar.
///
/// Displays a full-bleed 2:1 aspect ratio image with a gradient overlay
/// at the top for toolbar readability.
class CoverArtBackground extends ConsumerStatefulWidget {
  const CoverArtBackground({
    required this.imageId,
    super.key,
  });

  final String imageId;

  @override
  ConsumerState<CoverArtBackground> createState() => _CoverArtBackgroundState();
}

class _CoverArtBackgroundState extends ConsumerState<CoverArtBackground> {
  int retries = 0;

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return const SizedBox.shrink();
    }

    final file = File(getFullImagePath(entry));

    if (!isTestEnv && retries < 10 && !file.existsSync()) {
      Future<void>.delayed(const Duration(milliseconds: 200)).then((_) {
        if (mounted) {
          setState(() {
            retries++;
          });
        }
      });
    }

    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          file,
          key: Key('${file.path}-$retries'),
          fit: BoxFit.cover,
          // Cache at reasonable size for performance
          cacheHeight: 600,
        ),
        // Gradient overlay for toolbar readability
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color(0x99000000), // 60% black at top
                Colors.transparent,
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ],
    );
  }
}
