import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/notifications/state/notification_inbox_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// Trailing icon in `TabSectionHeader` that opens the synced-notifications
/// inbox popover.
///
/// The icon flips between [LottiIcons.notification] and
/// [LottiIcons.notificationActive] based on the live unseen count from
/// [unseenNotificationCountProvider], and renders a small badge with the
/// number when at least one alert is unseen. Tapping the icon toggles a
/// [MenuAnchor]-hosted popover whose contents are driven by
/// [inboxNotificationsProvider].
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  /// Preferred popover width on desktop. Two-line task titles read
  /// comfortably here without cramping the row content.
  static const double popoverPreferredWidth = 440;

  /// Floor so the layout doesn't collapse on a freakishly narrow window.
  static const double popoverMinWidth = 320;

  /// Horizontal margin between the popover and the screen edges. Keeps the
  /// menu off the bezel on mobile portrait.
  static const double popoverScreenMargin = 16;

  /// Resolves the popover width against the surrounding screen so mobile
  /// portrait shrinks to fit while desktop gets the preferred width.
  static double resolvePopoverWidth(double screenWidth) {
    final available = screenWidth - popoverScreenMargin * 2;
    if (available <= popoverMinWidth) return popoverMinWidth;
    if (available >= popoverPreferredWidth) return popoverPreferredWidth;
    return available;
  }

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final MenuController _menu = MenuController();

  /// Closes the popover and takes the user to whatever [entity] is about.
  ///
  /// Every destination is a Beamer route through [beamToNamed] — the same
  /// path the task list, the logbook cards and the Daily OS lanes take to
  /// open a task. The task rows used to go through `openLinkedTaskDetail`,
  /// which exists for layering a linked task *inside* an open task detail:
  /// on desktop it pushes the right pane's own stack, on a phone it pushes a
  /// pageless `MaterialPageRoute` onto the tab's Beamer navigator. A pageless
  /// route is invisible to the router — `NavService.beamBack` found no history
  /// to pop, and resetting the tab to its root left the page where it was —
  /// so a task opened from the bell had no way out on mobile. Beaming to
  /// `/tasks/<id>` hands the task to `TasksLocation` — a real page on a
  /// phone, the selected task of the split on desktop — so the back chevron
  /// works, from whichever tab the bell was tapped on.
  ///
  /// Exhaustive over the union rather than routing `linkedEntityId` into the
  /// task detail: every variant answers that getter, so the task route
  /// silently swallowed ids that were never tasks.
  void _openEntry(NotificationEntity entity) {
    _menu.close();
    switch (entity) {
      case TaskSuggestionNotification(:final linkedTaskId):
        // Opening from a suggestion row is the one case that should land on
        // the suggestions themselves. Published before the beam, so a detail
        // page that is already mounted scrolls now and one this beam mounts
        // consumes the intent after load.
        ref
            .read(taskFocusControllerProvider(linkedTaskId).notifier)
            .publishSuggestionFocus();
        beamToNamed('/tasks/$linkedTaskId');
      case TaskOverdueNotification(:final linkedTaskId):
        // No focus intent: an overdue alert is about the task itself.
        beamToNamed('/tasks/$linkedTaskId');
      case RelationshipCheckInNotification(:final linkedRelationshipId):
        beamToNamed('/people/$linkedRelationshipId');
      case HabitAutoCompletedNotification():
        beamToNamed('/habits');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final highText = tokens.colors.text.highEmphasis;
    final messages = context.messages;

    final unseen = ref.watch(unseenNotificationCountProvider).value ?? 0;
    final hasUnseen = unseen > 0;
    final iconData = hasUnseen
        ? LottiIcons.notificationActive
        : LottiIcons.notification;

    return MenuAnchor(
      controller: _menu,
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            side: BorderSide(
              color: tokens.colors.decorative.level02,
            ),
          ),
        ),
        // level02 sits one notch above the page chrome (level01) so the
        // popover reads as a raised surface in both light and dark mode.
        // Without this, the popover was indistinguishable from the
        // scaffold background.
        backgroundColor: WidgetStatePropertyAll(
          tokens.colors.background.level02,
        ),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        ConstrainedBox(
          constraints: BoxConstraints.tightFor(
            width: NotificationBell.resolvePopoverWidth(
              MediaQuery.sizeOf(context).width,
            ),
          ),
          child: _InboxPanel(onSelectEntry: _openEntry),
        ),
      ],
      builder: (context, controller, _) {
        return Semantics(
          button: true,
          label: hasUnseen
              ? messages.notificationBellUnseenSemantics(unseen)
              : messages.notificationBellEmptySemantics,
          child: Tooltip(
            message: messages.notificationBellTooltip,
            child: SizedBox.square(
              dimension: 36,
              child: InkResponse(
                radius: 20,
                onTap: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(iconData, size: IconSizes.l, color: highText),
                    if (hasUnseen)
                      Positioned(
                        top: 6,
                        right: 6,
                        // Badge must not absorb taps — it's purely decorative
                        // and the InkResponse wraps the whole 36x36 hit box.
                        child: IgnorePointer(
                          child: _UnseenBadge(count: unseen),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small numeric badge overlaid on the bell icon, capped at `9+`.
///
/// Rendered only when [NotificationBell] has at least one unseen alert. It is
/// wrapped in an `IgnorePointer` by the caller so the whole 36x36 icon stays a
/// single tap target.
class _UnseenBadge extends StatelessWidget {
  const _UnseenBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = count > 9 ? '9+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      decoration: BoxDecoration(
        color: tokens.colors.alert.error.defaultColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: tokens.colors.background.level01,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.others.caption.copyWith(
            // Material's onError pairs with the alert.error.defaultColor
            // surface this badge sits on. No explicit "on-color" token exists
            // in the generated design-system palette yet (see PR 2893's
            // learnings on incomplete token coverage), so the theme value is
            // the most appropriate substitute for a hardcoded Colors.white.
            color: Theme.of(context).colorScheme.onError,
            height: 1,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
      ),
    );
  }
}

/// Body of the bell popover: a title, then the live inbox list.
///
/// Watches [inboxNotificationsProvider] and renders one [_InboxRow] per entry,
/// falling back to [_InboxEmptyState] when the list is empty or errored and to
/// a spinner while the first fetch is in flight. Each row is keyed by entry id
/// so incremental stream updates preserve widget state across reorders.
class _InboxPanel extends ConsumerWidget {
  const _InboxPanel({
    required this.onSelectEntry,
  });

  /// Called when the user taps a row. The callback owns both popover
  /// dismissal and the navigation — closing the menu tears the row down, so
  /// the row itself cannot safely do anything after it — and receives the
  /// whole entity because where a row leads depends on its variant.
  final void Function(NotificationEntity entity) onSelectEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final asyncInbox = ref.watch(inboxNotificationsProvider);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
            child: Text(
              messages.notificationInboxTitle,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          asyncInbox.when(
            data: (entries) {
              if (entries.isEmpty) {
                return _InboxEmptyState(text: messages.notificationInboxEmpty);
              }
              // MenuAnchor measures its panel via intrinsic-height layout,
              // which rejects shrink-wrapping viewports — so a plain
              // SingleChildScrollView + Column is the right primitive here.
              // The inbox is bounded in practice (a handful of alerts), so
              // ListView.builder's lazy advantage does not apply, but each
              // row still gets a ValueKey so reordering preserves widget
              // state when the stream pushes incremental updates.
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in entries)
                        _InboxRow(
                          key: ValueKey(entry.id),
                          entity: entry,
                          onSelectEntry: onSelectEntry,
                        ),
                    ],
                  ),
                ),
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
              child: const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => _InboxEmptyState(
              text: messages.notificationInboxError,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered placeholder shown inside the popover when the inbox has no rows or
/// the stream errored. [text] carries the appropriate localized message.
class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step5,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
    );
  }
}

/// A single inbox entry: title, optional body, and a dismiss button.
///
/// Tapping a row opens whatever the row is about (via [onSelectEntry]) and
/// marks the row seen. A tap on the close icon or a long-press retracts the
/// row — for a `TaskSuggestionNotification` that retracts every open
/// suggestion for the task, otherwise just this row. The inbox stream then
/// removes the row, so the popover stays open for dismissing several in a row.
class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.entity,
    required this.onSelectEntry,
    super.key,
  });

  final NotificationEntity entity;
  final void Function(NotificationEntity entity) onSelectEntry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return InkWell(
      onTap: _handleTap,
      onLongPress: _handleRetract,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LottiIcons.notificationActive,
              size: 18,
              color: tokens.colors.interactive.enabled,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                  ),
                  if (entity.body.isNotEmpty) ...[
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      entity.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              // Compact density keeps the row tight; the default 48x48 hit
              // box dwarfs the two-line text content otherwise.
              visualDensity: VisualDensity.compact,
              tooltip: messages.notificationInboxDismiss,
              icon: Icon(
                LottiIcons.close,
                size: 18,
                color: tokens.colors.text.lowEmphasis,
              ),
              onPressed: _handleRetract,
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap() {
    // The bell owns dismissal and navigation: closing the menu unmounts this
    // row, so nothing here may touch the row's own context afterwards.
    onSelectEntry(entity);
    // Fire markSeen after navigation so the badge clears as the target opens.
    // Opening the target is not the same as acting on an agent suggestion;
    // the confirmation/rejection flow owns retraction.
    unawaited(_markSeen());
  }

  Future<void> _markSeen() async {
    try {
      await getIt<NotificationRepository>().markSeen(entity.id);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
  }

  Future<void> _handleRetract() async {
    try {
      final repository = getIt<NotificationRepository>();
      if (entity is TaskSuggestionNotification) {
        await repository.retractTaskSuggestionsForTask(entity.linkedEntityId!);
      } else {
        await repository.retract(entity.id);
      }
    } catch (error, stackTrace) {
      // Swallow the failure: the popover stays open and the user can retry.
      // Reporting keeps the error visible in crash logs without bubbling.
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
    // Keep the popover open so the user can dismiss multiple in a row;
    // the inbox stream removes the row automatically.
  }
}
