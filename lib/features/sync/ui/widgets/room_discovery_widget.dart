import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/state/room_discovery_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';

/// Widget that discovers and displays existing sync rooms for selection.
///
/// Used in the single-user multi-device flow where a user logging in on
/// a new device can discover and join existing sync rooms instead of
/// creating a new one or waiting for an invite.
class RoomDiscoveryWidget extends ConsumerStatefulWidget {
  const RoomDiscoveryWidget({
    required this.onRoomSelected,
    required this.onSkip,
    super.key,
  });

  /// Called when a room is successfully selected and joined.
  final VoidCallback onRoomSelected;

  /// Called when the user chooses to skip discovery and create a new room.
  final VoidCallback onSkip;

  @override
  ConsumerState<RoomDiscoveryWidget> createState() =>
      _RoomDiscoveryWidgetState();
}

class _RoomDiscoveryWidgetState extends ConsumerState<RoomDiscoveryWidget> {
  @override
  void initState() {
    super.initState();
    // Start discovery when widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomDiscoveryControllerProvider.notifier).discoverRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomDiscoveryControllerProvider);

    return switch (state) {
      RoomDiscoveryInitial() => _buildInitial(context),
      RoomDiscoveryLoading() => _buildLoading(context),
      RoomDiscoverySuccess(:final rooms) when rooms.isEmpty =>
        _buildNoRoomsFound(context),
      RoomDiscoverySuccess(:final rooms) => _buildRoomList(context, rooms),
      RoomDiscoveryError(:final error) => _buildError(context, error),
    };
  }

  Widget _buildInitial(BuildContext context) {
    return Center(
      child: LottiPrimaryButton(
        onPressed: () {
          ref.read(roomDiscoveryControllerProvider.notifier).discoverRooms();
        },
        label: context.messages.syncDiscoverRoomsButton,
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.messages.syncDiscoveringRooms,
            style: context.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildNoRoomsFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.syncNoRoomsFound,
            style: context.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LottiPrimaryButton(
            onPressed: widget.onSkip,
            label: context.messages.syncCreateNewRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(BuildContext context, List<SyncRoomCandidate> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.messages.syncSelectRoom,
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.messages.syncSelectRoomDescription,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return _RoomCard(
                room: room,
                onTap: () => _selectRoom(room),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        LottiSecondaryButton(
          onPressed: widget.onSkip,
          label: context.messages.syncCreateNewRoomInstead,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: context.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.syncDiscoveryError,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: context.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LottiSecondaryButton(
                onPressed: () {
                  ref
                      .read(roomDiscoveryControllerProvider.notifier)
                      .discoverRooms();
                },
                label: context.messages.syncRetry,
              ),
              const SizedBox(width: 16),
              LottiPrimaryButton(
                onPressed: widget.onSkip,
                label: context.messages.syncSkip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectRoom(SyncRoomCandidate room) async {
    final success =
        await ref.read(roomDiscoveryControllerProvider.notifier).joinRoom(room);

    if (success) {
      widget.onRoomSelected();
    }
  }
}

/// Card displaying a single sync room candidate.
class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.onTap,
  });

  final SyncRoomCandidate room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat.yMd().add_Hm();
    final createdText = room.createdAt != null
        ? dateFormatter.format(room.createdAt!)
        : context.messages.syncRoomCreatedUnknown;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.meeting_room,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      room.roomName ?? context.messages.syncRoomUnnamed,
                      style: context.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _ConfidenceBadge(confidence: room.confidence),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                room.roomId,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.outline,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${room.memberCount}',
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    createdText,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
              if (room.hasStateMarker || room.hasLottiContent) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (room.hasStateMarker)
                      _IndicatorChip(
                        label: context.messages.syncRoomVerified,
                        icon: Icons.verified,
                        color: context.colorScheme.primary,
                      ),
                    if (room.hasLottiContent)
                      _IndicatorChip(
                        label: context.messages.syncRoomHasContent,
                        icon: Icons.sync,
                        color: context.colorScheme.secondary,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small badge showing confidence level.
class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final int confidence;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 10
        ? context.colorScheme.primary
        : confidence >= 5
            ? context.colorScheme.secondary
            : context.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$confidence',
            style: context.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Small chip showing an indicator (verified, has content, etc).
class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
