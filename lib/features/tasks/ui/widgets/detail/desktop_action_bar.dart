import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/logic/image_import.dart';

/// Frosted bottom action bar for the desktop task detail view.
///
/// Provides quick actions: track time, add image, record audio, link entry.
class DesktopActionBar extends ConsumerWidget {
  const DesktopActionBar({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final entry = ref.watch(entryControllerProvider(id: taskId)).value?.entry;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: DesignSystemNavigationFrostedSurface(
          borderRadius: BorderRadius.circular(tokens.radii.xl),
          padding: EdgeInsets.all(tokens.spacing.step3),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimerActionButton(taskId: taskId, entry: entry),
                SizedBox(width: tokens.spacing.step3),
                _RoundAction(
                  icon: Icons.image_outlined,
                  onTap: () async {
                    if (entry != null && context.mounted) {
                      await importImageAssets(
                        context,
                        linkedId: taskId,
                        categoryId: entry.meta.categoryId,
                      );
                    }
                  },
                ),
                SizedBox(width: tokens.spacing.step3),
                _RoundAction(
                  icon: Icons.mic_none_rounded,
                  onTap: () {
                    if (entry != null) {
                      ref
                          .read(entryCreationServiceProvider)
                          .showAudioRecordingModal(
                            context,
                            linkedId: taskId,
                            categoryId: entry.meta.categoryId,
                          );
                    }
                  },
                ),
                SizedBox(width: tokens.spacing.step3),
                _RoundAction(
                  icon: Icons.link_rounded,
                  onTap: () {
                    // Link entry action — to be wired
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerActionButton extends ConsumerWidget {
  const _TimerActionButton({
    required this.taskId,
    required this.entry,
  });

  final String taskId;
  final JournalEntity? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;

    return GestureDetector(
      onTap: () async {
        if (entry != null) {
          await ref
              .read(entryCreationServiceProvider)
              .createTimerEntry(
                linked: entry,
              );
        }
      },
      child: Container(
        height: 60,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: TaskShowcasePalette.highText(context),
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(
              context.messages.addActionAddTimer,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: TaskShowcasePalette.highText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: TaskShowcasePalette.highText(context),
        ),
      ),
    );
  }
}
