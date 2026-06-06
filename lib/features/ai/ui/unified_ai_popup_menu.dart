import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/ui/unified_ai_skills_modal.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';

/// Unified AI popup menu that shows available skills for the current entity
class UnifiedAiPopUpMenu extends ConsumerWidget {
  const UnifiedAiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    this.iconColor,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  /// Optional icon color. Defaults to the theme's outline color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPromptsAsync = ref.watch(
      hasAvailableSkillsProvider((
        entityId: journalEntity.id,
        linkedFromId: linkedFromId,
      )),
    );

    // Use hasValue to preserve the icon during refresh states.
    // Since the provider is now keyed by entityId (stable), updates to
    // the same entry will reuse the provider and maintain previous value.
    if (hasPromptsAsync.hasValue && hasPromptsAsync.value!) {
      final icon = Icon(
        Icons.assistant_rounded,
        color: iconColor ?? context.colorScheme.outline,
      );

      void onTap() => UnifiedAiModal.show<void>(
        context: context,
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
        ref: ref,
      );

      // Use GlassActionButton for proper clipped splash effect when iconColor
      // is specified (used over images), otherwise use standard IconButton
      if (iconColor != null) {
        return GlassActionButton(
          onTap: onTap,
          child: icon,
        );
      }

      return IconButton(
        icon: icon,
        onPressed: onTap,
      );
    }

    return const SizedBox.shrink();
  }
}
