import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/ui/unified_ai_skills_modal.dart';
import 'package:lotti/features/demo/ai/demo_ai_gate.dart';
import 'package:lotti/features/demo/ui/demo_ai_setup_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';

/// Unified AI popup menu that shows available skills for the current entity
class UnifiedAiPopUpMenu extends ConsumerWidget {
  const UnifiedAiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    this.iconColor,
    this.iconSize,
    this.useGlassButton = false,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  /// Optional icon color. Defaults to the theme's outline color.
  final Color? iconColor;

  /// Optional glyph size. Defaults to the [IconButton] default when null.
  final double? iconSize;

  /// Whether to render the glass/blur action button (only appropriate when the
  /// control sits *over an image*). On a normal card surface this leaves the
  /// glyph reading as a dim badge, so the default is a plain [IconButton].
  final bool useGlassButton;

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
      // Outlined (not filled) glyph at the same optical weight as the other
      // header controls — a filled high-contrast badge made the AI action the
      // heaviest element on the card, out-ranking the timestamp and payload.
      final icon = Icon(
        Icons.assistant_outlined,
        size: iconSize,
        color: iconColor ?? context.colorScheme.outline,
      );

      Future<void> openModal() => UnifiedAiModal.show<void>(
        context: context,
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
        ref: ref,
      );

      // In the demo world every seeded AI provider is a fictional fixture
      // that can never answer. Intercept the tap BEFORE any skill fires and
      // offer the guided real-AI setup instead of a doomed request; once a
      // real provider exists (or outside the demo) the tap passes straight
      // through. The seam lives here — at the single user-facing trigger
      // for on-demand inference — not in the inference engine.
      Future<void> onTapAsync() async {
        final container = ProviderScope.containerOf(context, listen: false);
        if (await shouldNudgeForRealAi(container)) {
          if (!context.mounted) return;
          await DemoAiSetupSheet.show(
            context,
            // Retry the intercepted action: with a real provider now
            // configured the gate passes and the skills modal opens.
            onConfigured: () {
              if (context.mounted) unawaited(openModal());
            },
          );
          return;
        }
        if (!context.mounted) return;
        await openModal();
      }

      void onTap() => unawaited(onTapAsync());

      // GlassActionButton only over images (its blur reads as a dim badge on a
      // flat card); everywhere else a plain IconButton with the given color.
      if (iconColor != null && useGlassButton) {
        return GlassActionButton(
          onTap: onTap,
          child: icon,
        );
      }

      return IconButton(
        icon: icon,
        // Label the otherwise-cryptic sparkle glyph so a new user knows what
        // the action does before tapping it.
        tooltip: context.messages.aiAssistantTitle,
        onPressed: onTap,
      );
    }

    return const SizedBox.shrink();
  }
}
