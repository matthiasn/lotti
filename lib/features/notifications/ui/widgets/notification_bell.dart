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

  /// Width of the popover panel. Wide enough for two-line task titles on
  /// desktop, narrow enough not to overflow a typical mobile portrait view.
  static const double popoverWidth = 340;

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

    return MenuAnchor(
      controller: _menu,
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.m),
          ),
        ),
        backgroundColor: WidgetStatePropertyAll(
          tokens.colors.background.level01,
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        SizedBox(
          width: NotificationBell.popoverWidth,
          child: _InboxPanel(
            onDismiss: _menu.close,
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
  const _InboxPanel({required this.onDismiss});

  final VoidCallback onDismiss;

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
    super.key,
  });

  final NotificationEntity entity;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final linkedId = entity.linkedEntityId;

    return InkWell(
      onTap: linkedId == null ? null : () => _handleTap(context, linkedId),
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

  Future<void> _handleTap(BuildContext context, String linkedId) async {
    // Dismiss the popover before awaiting the database write so navigation
    // feels instantaneous — the markActedOn round-trip can take tens of ms
    // on cold reads. The inbox stream will catch up when the write lands.
    onDismiss();
    final navigatorContext = context;
    try {
      await getIt<NotificationRepository>().markActedOn(entity.id);
    } catch (error, stackTrace) {
      // Surface the failure to the zone error handler so it lands in the
      // logging pipeline, but keep navigating — the user already committed
      // to opening the task.
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
    if (!navigatorContext.mounted) return;
    openLinkedTaskDetail(context: navigatorContext, taskId: linkedId);
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
