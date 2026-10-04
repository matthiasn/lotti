import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/create/entry_creation_service.dart';
import 'package:lotti/features/speech/ui/widgets/recording/glass_record_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Sticky action bar pinned to the bottom of the entry details page.
///
/// The logbook counterpart of the task page's `TaskActionBar`: the same
/// edge-to-edge glass strip (top hairline + backdrop blur + soft top→bottom
/// gradient), the same 48 px chips on the same `step4` rhythm, carrying the
/// three things a reader does from an entry. Left to right:
///
/// * **Add a task** — the bar's one filled primary. Creates a task linked to
///   this entry and categorized like it, hands it the category's default
///   agent, and opens it — `EntryCreationService.createTaskAndOpen`, the same
///   journey as the Add sheet's "Link a new task" row, so a thought that
///   turns into work is one tap from becoming a task.
/// * **Record a voice note** — the shared [GlassRecordButton]: the
///   accent-ringed mic that is a peer of the primary rather than a quiet
///   utility, exactly as on the task bar, wearing the alert fill while a
///   recording linked to this entry is in progress.
/// * **Add linked entry** — the plus. Opens the Add sheet for the long tail
///   (note, voice note, task, timer, image…) linked to this entry, which is
///   precisely what the floating button it replaces did.
///
/// It replaces the linked-entry floating button, which floated well above the
/// bottom edge on a phone to clear the mobile launcher's row, and the launcher
/// itself: the shell unmounts the launcher on `/journal/<uuid>` as it does on
/// `/tasks/<uuid>`, so this bar docks flush with the home indicator.
///
/// The host page must use `Scaffold.extendBody: true` so body content paints
/// behind the strip — that is what the backdrop filter samples — and consume
/// the bar's height at the end of its scrollable so the last card can scroll
/// clear of it (see `EntryDetailsPage`). The row is a [Wrap], so large
/// accessibility text folds the chips onto another line instead of clipping
/// their hit targets.
class EntryActionBar extends ConsumerWidget {
  const EntryActionBar({
    required this.entry,
    this.topSlot,
    super.key,
  });

  /// The entry whose page hosts the bar; everything created from the bar is
  /// linked to it and inherits its category.
  final JournalEntity entry;

  /// Optional activity area above the action row — the AI running strip. It
  /// collapses to nothing while idle.
  final Widget? topSlot;

  /// Stable test key for the Add a task pill.
  @visibleForTesting
  static const Key addTaskKey = ValueKey('entry-action-bar-add-task');

  /// Stable test key for the record-audio round button.
  @visibleForTesting
  static const Key audioKey = ValueKey('entry-action-bar-audio');

  /// Stable test key for the plus button that opens the Add sheet.
  @visibleForTesting
  static const Key addKey = ValueKey('entry-action-bar-add');

  /// Stable test key for the optional activity area above the action row.
  @visibleForTesting
  static const Key topSlotKey = ValueKey('entry-action-bar-top-slot');

  Future<void> _onAddTaskPressed(WidgetRef ref) {
    return ref
        .read(entryCreationServiceProvider)
        .createTaskAndOpen(
          linkedId: entry.meta.id,
          categoryId: entry.meta.categoryId,
        );
  }

  void _onAudioPressed(BuildContext context, WidgetRef ref) {
    ref
        .read(entryCreationServiceProvider)
        .showAudioRecordingModal(
          context,
          linkedId: entry.meta.id,
          categoryId: entry.meta.categoryId,
        );
  }

  Future<void> _onAddPressed(BuildContext context, WidgetRef ref) {
    return ref
        .read(entryCreationServiceProvider)
        .showCreateEntryModal(
          context,
          linkedFromId: entry.meta.id,
          categoryId: entry.meta.categoryId,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;

    // The bottom of the inner padding adds the system home-indicator inset
    // (iPhones without a home button): the glass surface still extends
    // edge-to-edge into that inset, while the touchable row sits above it.
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;

    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.step5,
          spacing.step4,
          spacing.step5,
          spacing.step4 + safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (topSlot != null)
              KeyedSubtree(
                key: EntryActionBar.topSlotKey,
                child: topSlot!,
              ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: spacing.step4,
              runSpacing: spacing.step4,
              children: [
                // The one filled shape on the strip. The visible word is the
                // short verb the Tasks tab's own create chip uses; the
                // accessible name repeats it and adds the relationship, so
                // what is read aloud contains what is printed.
                DsGlassPill(
                  key: EntryActionBar.addTaskKey,
                  icon: LottiIcons.addTask,
                  label: messages.addActionCreateTask,
                  semanticLabel: messages.entryActionBarAddLinkedTask,
                  fillColor: tokens.colors.interactive.enabled,
                  foregroundColor: tokens.colors.text.onInteractiveAlert,
                  onTap: () => _onAddTaskPressed(ref),
                ),
                GlassRecordButton(
                  key: EntryActionBar.audioKey,
                  linkedId: entry.meta.id,
                  onPressed: () => _onAudioPressed(context, ref),
                ),
                DsGlassRoundButton(
                  key: EntryActionBar.addKey,
                  icon: LottiIcons.add,
                  semanticLabel: messages.addLinkedEntryLabel,
                  onPressed: () => _onAddPressed(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
