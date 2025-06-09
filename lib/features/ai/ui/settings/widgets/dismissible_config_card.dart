import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/dismiss_background.dart';

/// A wrapper widget that makes an AiConfigCard dismissible
///
/// This widget wraps an [AiConfigCard] with [Dismissible] functionality,
/// allowing users to swipe to delete configurations.
///
/// Features:
/// - Swipe right-to-left to delete
/// - Stylish delete background
/// - Confirmation dialog before deletion
/// - Proper integration with delete service
///
/// Example:
/// ```dart
/// DismissibleConfigCard<AiConfigModel>(
///   config: myModel,
///   showCapabilities: true,
///   onTap: () => navigateToEdit(myModel),
/// )
/// ```
class DismissibleConfigCard<T extends AiConfig> extends ConsumerWidget {
  const DismissibleConfigCard({
    required this.config,
    required this.onTap,
    this.showCapabilities = false,
    this.isCompact = false,
    super.key,
  });

  /// The AI configuration to display
  final T config;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  /// Whether to show capability indicators (for models)
  final bool showCapabilities;

  /// Whether to use compact card layout
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(config.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        const deleteService = AiConfigDeleteService();
        return deleteService.deleteConfig(
          context: context,
          ref: ref,
          config: config,
        );
      },
      background: const DismissBackground(),
      child: AiConfigCard(
        config: config,
        showCapabilities: showCapabilities,
        isCompact: isCompact,
        onTap: onTap,
      ),
    );
  }
}
