import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Activity-filter pill row above the linked entries list.
///
/// Implements the Figma "Activity Filter" treatment as a single
/// horizontally-centered pill row that's always visible on every
/// breakpoint.
///
/// Pill colors come from the design system where available
/// (`alert.warning` for Timer). Audio and Images are not in the token
/// set yet — their hex values come straight from the Figma activity-
/// filter spec.
class LinkedEntriesActivityFilterBar extends ConsumerWidget {
  const LinkedEntriesActivityFilterBar({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final activeKinds = ref.watch(
      linkedEntriesActivityFilterControllerProvider(id: entryId),
    );
    final notifier = ref.read(
      linkedEntriesActivityFilterControllerProvider(id: entryId).notifier,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step3,
        //        top: tokens.spacing.step3,
        bottom: tokens.spacing.step4,
      ),
      child: Wrap(
        spacing: tokens.spacing.step3,
        runSpacing: tokens.spacing.step2,
        children: LinkedEntryActivityFilter.values
            .map(
              (kind) => _ActivityPill(
                kind: kind,
                active: activeKinds.contains(kind),
                onTap: () => notifier.toggle(kind),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ActivityPill extends StatelessWidget {
  const _ActivityPill({
    required this.kind,
    required this.active,
    required this.onTap,
  });

  final LinkedEntryActivityFilter kind;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ActivityPillSpec.of(context, kind);
    final radius = BorderRadius.circular(20);
    final accent = spec.accent;
    final activeBg = accent.withValues(alpha: 0.15);
    final activeBorder = accent.withValues(alpha: spec.borderAlpha);

    final inactiveLabelColor = tokens.colors.text.lowEmphasis;
    final inactiveBorderColor = tokens.colors.decorative.level01;

    final bgColor = active ? activeBg : Colors.transparent;
    final borderColor = active ? activeBorder : inactiveBorderColor;
    final labelColor = active ? accent : inactiveLabelColor;

    return Semantics(
      button: true,
      toggled: active,
      label: spec.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: radius,
              border: Border.all(color: borderColor),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(spec.icon, size: 16, color: labelColor),
                SizedBox(width: tokens.spacing.step2),
                Text(
                  spec.label,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityPillSpec {
  const _ActivityPillSpec({
    required this.label,
    required this.icon,
    required this.accent,
    required this.borderAlpha,
  });

  factory _ActivityPillSpec.of(
    BuildContext context,
    LinkedEntryActivityFilter kind,
  ) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return switch (kind) {
      LinkedEntryActivityFilter.timer => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterTimer,
        icon: Icons.timer_outlined,
        accent: tokens.colors.alert.warning.defaultColor,
        borderAlpha: 1,
      ),
      // Audio / Images use Figma-spec hex values that aren't in the token
      // set yet. Border alpha is 0.7 per the Figma activity-filter pills.
      LinkedEntryActivityFilter.audio => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterAudio,
        icon: Icons.mic_none_outlined,
        accent: const Color(0xFF9966E5),
        borderAlpha: 0.7,
      ),
      LinkedEntryActivityFilter.images => _ActivityPillSpec(
        label: messages.journalLinkedEntriesActivityFilterImages,
        icon: Icons.photo_outlined,
        accent: const Color(0xFF619EFF),
        borderAlpha: 0.7,
      ),
    };
  }

  final String label;
  final IconData icon;
  final Color accent;
  final double borderAlpha;
}
