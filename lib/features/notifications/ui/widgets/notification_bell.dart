import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/notifications/state/notification_inbox_controller.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Trailing icon in `TabSectionHeader` that opens the synced-notifications
/// inbox popover.
///
/// The icon flips between [Icons.notifications_none_rounded] and
/// [Icons.notifications_active_rounded] based on the live unseen count from
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final highText = tokens.colors.text.highEmphasis;
    final messages = context.messages;

    final unseen = ref.watch(unseenNotificationCountProvider).value ?? 0;
    final hasUnseen = unseen > 0;
    final iconData = hasUnseen
        ? Icons.notifications_active_rounded
        : Icons.notifications_none_rounded;

    // Capture the bell's own context so a row tap can navigate even after
    // the popover overlay (and therefore the row's own context) is torn down
    // by `_menu.close`. Without this, the row's `_handleTap` would close the
    // menu, await markActedOn, then find `context.mounted == false` and
    // silently skip the navigation.
    final bellContext = context;
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
          child: _InboxPanel(
            onDismiss: _menu.close,
            onSelectTask: (linkedTaskId) {
              _menu.close();
              if (!bellContext.mounted) return;
              openLinkedTaskDetail(
                context: bellContext,
                taskId: linkedTaskId,
              );
            },
          ),
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
                    Icon(iconData, size: 24, color: highText),
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

class _InboxPanel extends ConsumerWidget {
  const _InboxPanel({
    required this.onDismiss,
    required this.onSelectTask,
  });

  final VoidCallback onDismiss;

  /// Called when the user taps a row whose `linkedEntityId` is non-null.
  /// The callback owns both popover dismissal and the navigation so it can
  /// run from the bell's stable context — see comment in [NotificationBell].
  final void Function(String linkedTaskId) onSelectTask;

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
                          onDismiss: onDismiss,
                          onSelectTask: onSelectTask,
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

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.entity,
    required this.onDismiss,
    required this.onSelectTask,
    super.key,
  });

  final NotificationEntity entity;
  final VoidCallback onDismiss;
  final void Function(String linkedTaskId) onSelectTask;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final linkedId = entity.linkedEntityId;

    return InkWell(
      onTap: linkedId == null ? null : () => _handleTap(linkedId),
      onLongPress: () => _handleRetract(context),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_active_rounded,
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
                Icons.close_rounded,
                size: 18,
                color: tokens.colors.text.lowEmphasis,
              ),
              onPressed: () => _handleRetract(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(String linkedId) {
    // Navigation runs against the bell's stable context (captured by
    // `onSelectTask` in [NotificationBell.build]) — using the row's own
    // context here would fail mid-flight because closing the menu
    // unmounts the popover overlay first.
    onSelectTask(linkedId);
    // Fire markActedOn after navigation so the badge clears as the task
    // opens. Errors land in the zone error handler without blocking.
    unawaited(
      getIt<NotificationRepository>().markActedOn(entity.id).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stackTrace),
        );
        return null;
      }),
    );
  }

  Future<void> _handleRetract(BuildContext context) async {
    try {
      await getIt<NotificationRepository>().retract(entity.id);
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
