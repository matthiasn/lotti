import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Modern styled toggle starred action item
class ModernToggleStarredItem extends ConsumerWidget {
  const ModernToggleStarredItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final starred = entry?.meta.starred ?? false;

    return ModernModalActionItem(
      icon: starred ? Icons.star_rounded : Icons.star_outline_rounded,
      title: context.messages.journalToggleStarredTitle,
      iconColor: starred ? starredGold : null,
      onTap: notifier.toggleStarred,
    );
  }
}

/// Modern styled toggle private action item
class ModernTogglePrivateItem extends ConsumerWidget {
  const ModernTogglePrivateItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final private = entry?.meta.private ?? false;

    return ModernModalActionItem(
      icon: private ? Icons.lock_rounded : Icons.lock_open_rounded,
      title: context.messages.journalTogglePrivateTitle,
      iconColor: private ? const Color(0xFFE57373) : null,
      onTap: notifier.togglePrivate,
    );
  }
}

/// Modern styled toggle flagged action item
class ModernToggleFlaggedItem extends ConsumerWidget {
  const ModernToggleFlaggedItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final flagged = entry?.meta.flag != null;

    return ModernModalActionItem(
      icon: flagged ? Icons.flag_rounded : Icons.flag_outlined,
      title: context.messages.journalToggleFlaggedTitle,
      iconColor: flagged ? const Color(0xFFBA68C8) : null,
      onTap: notifier.toggleFlagged,
    );
  }
}

/// Modern styled toggle map action item
class ModernToggleMapItem extends ConsumerWidget {
  const ModernToggleMapItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final showMap = entry?.geolocation != null;

    return ModernModalActionItem(
      icon: showMap ? Icons.map_rounded : Icons.map_outlined,
      title: 'Show map',
      onTap: notifier.toggleMapVisible,
    );
  }
}

/// Modern styled delete action item
class ModernDeleteItem extends ConsumerWidget {
  const ModernDeleteItem({
    required this.entryId,
    required this.beamBack,
    super.key,
  });

  final String entryId;
  final bool beamBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);

    return ModernModalActionItem(
      icon: Icons.delete_outline_rounded,
      title: 'Delete entry',
      isDestructive: true,
      onTap: () => notifier.delete(beamBack: beamBack),
    );
  }
}

/// Modern styled speech recognition action item
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

    return ModernModalActionItem(
      icon: Icons.transcribe_rounded,
      title: context.messages.speechModalTitle,
      onTap: () => pageIndexNotifier.value = 2,
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
    final notifier = ref.read(provider.notifier);

    return ModernModalActionItem(
      icon: Icons.share_rounded,
      title: 'Share',
      onTap: () {
        // TODO: Implement share functionality
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern styled tag add action item
class ModernTagAddItem extends StatelessWidget {
  const ModernTagAddItem({
    required this.entryId,
    required this.pageIndexNotifier,
    super.key,
  });

  final String entryId;
  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context) {
    return ModernModalActionItem(
      icon: Icons.label_outline_rounded,
      title: context.messages.journalTagPlusHint,
      onTap: () => pageIndexNotifier.value = 1,
    );
  }
}

/// Modern styled unlink action item
class ModernUnlinkItem extends ConsumerWidget {
  const ModernUnlinkItem({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkService = getIt<LinkService>();

    return ModernModalActionItem(
      icon: Icons.link_off_rounded,
      title: 'Unlink',
      onTap: () {
        // TODO: Implement unlink functionality
        // linkService.unlinkFrom(linkedFromId, entryId);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern styled toggle hidden action item
class ModernToggleHiddenItem extends ConsumerWidget {
  const ModernToggleHiddenItem({
    required this.entryId,
    required this.link,
    super.key,
  });

  final String entryId;
  final EntryLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkService = getIt<LinkService>();
    final hidden = link.hidden ?? false;

    return ModernModalActionItem(
      icon: hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      title: hidden ? 'Show link' : 'Hide link',
      onTap: () {
        // TODO: Implement toggle hidden functionality
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern styled copy image action item
class ModernCopyImageItem extends ConsumerWidget {
  const ModernCopyImageItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item is! JournalImage) {
      return const SizedBox.shrink();
    }

    return ModernModalActionItem(
      icon: MdiIcons.contentCopy,
      title: 'Copy image',
      onTap: () async {
        // TODO: Implement copy image functionality
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
