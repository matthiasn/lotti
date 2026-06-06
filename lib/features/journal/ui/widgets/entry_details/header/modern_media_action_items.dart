part of 'modern_action_items.dart';

class ModernSpeechItem extends ConsumerWidget {
  const ModernSpeechItem({
    required this.entryId,
    required this.pageIndexNotifier,
    super.key,
  });

  final String entryId;
  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item is! JournalAudio) {
      return const SizedBox.shrink();
    }

    return ActionMenuListItem(
      icon: Icons.transcribe_rounded,
      title: context.messages.speechModalTitle,
      onTap: () => pageIndexNotifier.value = 1,
    );
  }
}

/// Reveals image and audio files in the platform file manager.
class ModernShowInFileManagerItem extends ConsumerWidget {
  const ModernShowInFileManagerItem({
    required this.entryId,
    this.fileActions = const MediaFileActions(),
    this.platform,
    this.onShowInFileManager,
    super.key,
  });

  final String entryId;
  final MediaFileActions fileActions;
  final MediaFilePlatform? platform;
  final MediaFileRevealCallback? onShowInFileManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;
    final resolvedPlatform = platform ?? MediaFileActions.currentPlatform();

    if (entryState == null ||
        entry == null ||
        entry is! JournalImage && entry is! JournalAudio ||
        resolvedPlatform == MediaFilePlatform.unsupported) {
      return const SizedBox.shrink();
    }

    return ActionMenuListItem(
      icon: Icons.folder_open_rounded,
      title: _showInFileManagerTitle(context, resolvedPlatform),
      onTap: () async {
        Navigator.of(context).pop();

        try {
          final filePath = entry is JournalImage
              ? getFullImagePath(entry)
              : await AudioUtils.getFullAudioPath(entry as JournalAudio);
          final callback = onShowInFileManager;
          if (callback != null) {
            await callback(filePath);
          } else {
            await fileActions.revealInFileManager(
              filePath,
              platform: resolvedPlatform,
            );
          }
        } catch (error, stackTrace) {
          _captureMediaFileActionException(error, stackTrace);
        }
      },
    );
  }

  String _showInFileManagerTitle(
    BuildContext context,
    MediaFilePlatform platform,
  ) {
    final messages = context.messages;
    if (platform == MediaFilePlatform.macos) {
      return messages.mediaShowInFinderAction;
    }
    if (platform == MediaFilePlatform.windows) {
      return messages.mediaShowInFileExplorerAction;
    }
    return messages.mediaShowInFilesAction;
  }
}

void _captureMediaFileActionException(
  Object error,
  StackTrace stackTrace,
) {
  if (getIt.isRegistered<DomainLogger>()) {
    getIt<DomainLogger>().error(
      LogDomain.persistence,
      error,
      stackTrace: stackTrace,
      subDomain: 'show_in_file_manager',
    );
  }
}

/// Modern styled share action item
class ModernShareItem extends ConsumerWidget {
  const ModernShareItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entryState == null ||
        entry is! JournalImage && entry is! JournalAudio) {
      return const SizedBox.shrink();
    }

    return ActionMenuListItem(
      icon: Icons.share_rounded,
      title: context.messages.journalShareHint,
      onTap: () async {
        Navigator.of(context).pop();

        if (isLinux || isWindows) {
          return;
        }

        if (entry is JournalImage) {
          final filePath = getFullImagePath(entry);
          await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
        }
        if (entry is JournalAudio) {
          final filePath = await AudioUtils.getFullAudioPath(entry);
          await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
        }
      },
    );
  }
}

/// Modern styled unlink action item
