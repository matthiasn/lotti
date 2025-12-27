import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/state/room_discovery_provider.dart';
import 'package:lotti/features/sync/ui/widgets/room_discovery_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Modal page for discovering and selecting existing sync rooms.
///
/// This page is shown after login when no room is configured. It allows
/// users logging in on a new device to discover and join existing sync
/// rooms instead of creating a new one.
SliverWoltModalSheetPage roomDiscoveryPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    title: context.messages.syncRoomDiscoveryTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: _RoomDiscoveryPageContent(pageIndexNotifier: pageIndexNotifier),
  );
}

class _RoomDiscoveryPageContent extends ConsumerWidget {
  const _RoomDiscoveryPageContent({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use responsive height based on screen size, with sensible bounds
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = (screenHeight * 0.5).clamp(300.0, 500.0);

    return SizedBox(
      height: modalHeight,
      child: RoomDiscoveryWidget(
        onRoomSelected: () {
          // Room was selected and joined, refresh the room provider
          // and navigate to the next page (devices verification)
          ref.invalidate(matrixRoomControllerProvider);
          pageIndexNotifier.value = pageIndexNotifier.value + 1;
        },
        onSkip: () {
          // User chose to create a new room instead
          // Reset discovery state and go to room config page
          ref.read(roomDiscoveryControllerProvider.notifier).reset();
          pageIndexNotifier.value = pageIndexNotifier.value + 1;
        },
      ),
    );
  }
}
