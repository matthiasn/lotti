import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_actions.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the list's controls.
@visibleForTesting
abstract final class FrontConversationListKeys {
  static const Key newChat = Key('front-conversations-new');
  static const Key archived = Key('front-conversations-archived');
  static Key row(String id) => Key('front-conversation-$id');
  static Key menu(String id) => Key('front-conversation-menu-$id');
  static const Key search = Key('front-conversations-search');
  static const Key inbox = Key('front-conversations-inbox');
}

/// The user's conversations with her, as a ChatGPT or Claude sidebar lists
/// them: a new one first, the search, then the live ones newest first under
/// recency sections, each with rename, archive and delete; the archived ones
/// folded away at the end, below a divider. A search looks through every
/// conversation, archived ones included. Picking one opens it and closes the
/// list.
///
/// Rows sit inset in the page gutter, so the open one is a quiet rounded
/// pill — the search field's width — and their text, the section labels and
/// the new-conversation action share one left edge.
class FrontConversationList extends ConsumerStatefulWidget {
  const FrontConversationList({this.beside = false, super.key});

  /// Beside the open conversation (a desktop window), whose header carries
  /// that conversation's menu: its row keeps its time then, and shows its
  /// menu on hover or focus like any other.
  final bool beside;

  @override
  ConsumerState<FrontConversationList> createState() =>
      _FrontConversationListState();
}

class _FrontConversationListState extends ConsumerState<FrontConversationList> {
  String _query = '';
  bool _showArchived = false;

  /// The search opens in place from a quiet row, so the page's one action —
  /// a new conversation — leads it, not a boxed field.
  bool _searchOpen = false;

  /// An open search that is left empty closes when focus leaves it.
  late final FocusNode _searchFocus = FocusNode()..addListener(_searchBlurred);

  void _searchBlurred() {
    if (!_searchFocus.hasFocus && _query.trim().isEmpty && _searchOpen) {
      setState(() => _searchOpen = false);
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _closeList() =>
      ref.read(frontConversationListOpenProvider.notifier).close();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final controller = ref.read(frontChatControllerProvider.notifier);
    final actions = FrontConversationActions(context, ref);
    // Read through `.value`: a reload keeps the list on screen.
    final index = ref.watch(frontConversationsProvider).value;
    final activeId = ref.watch(frontActiveConversationProvider).value;
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    // Read through `.value`: a re-projection keeps the last count.
    final inboxCount =
        ref.watch(
          frontAllChatsThreadProvider.select((t) => t.value?.inboxCount),
        ) ??
        0;
    final needle = _query.trim().toLowerCase();
    final searching = needle.isNotEmpty;
    final matching = [
      for (final c in index?.conversations ?? const <FrontConversation>[])
        if (!searching || c.title.toLowerCase().contains(needle)) c,
    ];
    // A search looks through the archived ones too, in place.
    final live = [
      for (final c in matching)
        if (searching || !c.archived) c,
    ];
    final archived = searching
        ? const <FrontConversation>[]
        : [
            for (final c in matching)
              if (c.archived) c,
          ];
    final hasAny = index?.conversations.isNotEmpty ?? false;
    // The open conversation is always on the page: when it is archived, its
    // group opens.
    final showArchived = _showArchived || archived.any((c) => c.id == activeId);
    final now = clock.now();
    final rowSize = _rowSize(context);
    // Labels sit on the row text's own edge.
    final textInset = DesignSystemListItem.contentInset(tokens, rowSize);
    // One time column for the whole list, as wide as its widest time: every
    // preview then ends on the same line, whatever its own time says.
    final timeWidth = _timeWidth(context, [
      for (final c in [...live, if (showArchived) ...archived])
        _when(context, c.lastActivity, now),
    ]);

    final rounded = BorderRadius.circular(tokens.radii.m);

    Widget row(FrontConversation c) => _ConversationRow(
      key: FrontConversationListKeys.row(c.id),
      conversation: c,
      now: now,
      timeWidth: timeWidth,
      borderRadius: rounded,
      selected: !inboxOnly && c.id == activeId,
      pinMenu: !widget.beside,
      menu: actions.menuItems(c),
      onOpen: () {
        controller.openConversation(c.id);
        _closeList();
      },
    );

    // A group: its name over its conversations, flat. The name in the
    // accent splits the days — the rows stay neutral, so the open row's
    // fill is still the one strong surface in the list.
    Widget group(String? label, List<FrontConversation> rows) => Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              // Snug over its rows, on their text's edge.
              padding: EdgeInsets.only(
                left: textInset,
                right: textInset,
                bottom: tokens.spacing.step1,
              ),
              child: Text(
                label,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.interactive.enabled,
                ),
              ),
            ),
          for (final c in rows) row(c),
        ],
      ),
    );

    // Live conversations under recency sections, as ChatGPT and Claude
    // group them — the date is said once per section, not on every row.
    final sections = <_Recency, List<FrontConversation>>{};
    for (final c in live) {
      sections.putIfAbsent(_Recency.of(c.lastActivity, now), () => []).add(c);
    }
    // The thread's own gutter: the pills, the search and the divider line
    // up with the bubbles' edges.
    return ListView(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step3,
        tokens.spacing.step5,
        tokens.spacing.step5,
      ),
      children: [
        // The one action on the page: first, and the accent.
        DesignSystemListItem(
          key: FrontConversationListKeys.newChat,
          // The accent and the glyph mark it; the weight is left to the
          // page title.
          titleContent: Text(
            messages.queryNewChat,
            style: _labelStyle(context).copyWith(
              color: tokens.colors.interactive.enabled,
            ),
          ),
          size: rowSize,
          borderRadius: rounded,
          hoverBackgroundColor: tokens.colors.surface.enabled,
          leading: Icon(
            LottiIcons.editNote,
            size: IconSizes.s,
            color: tokens.colors.interactive.enabled,
          ),
          onTap: () {
            controller.startConversation();
            _closeList();
          },
        ),
        // What waits on the user, from every conversation: a destination
        // of its own, opening the thread filtered to it — next after a new
        // chat, since it is what asks for attention.
        if (!searching && (inboxCount > 0 || inboxOnly))
          DesignSystemListItem(
            key: FrontConversationListKeys.inbox,
            // At full strength while something waits; the badge counts it.
            titleContent: Text(
              messages.frontChatInboxTitle,
              style: _labelStyle(context).copyWith(
                color: inboxCount > 0
                    ? tokens.colors.text.highEmphasis
                    : tokens.colors.text.mediumEmphasis,
              ),
            ),
            size: rowSize,
            borderRadius: rounded,
            activated: inboxOnly,
            activatedBackgroundColor: tokens.colors.surface.focusPressed,
            hoverBackgroundColor: tokens.colors.surface.enabled,
            leading: Icon(
              LottiIcons.inbox,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
            // The header's dot, counted: the same warm mark on the row that
            // resolves it.
            trailing: _TrailingSlot(
              child: DesignSystemBadge.number(
                value: '$inboxCount',
                tone: DesignSystemBadgeTone.warning,
                semanticLabel: messages.frontChatInboxChip(inboxCount),
              ),
            ),
            onTap: () {
              if (!inboxOnly) {
                ref.read(frontInboxFilterProvider.notifier).toggle();
              }
              _closeList();
            },
          ),
        if (hasAny && !_searchOpen)
          DesignSystemListItem(
            key: FrontConversationListKeys.search,
            titleContent: Text(
              messages.frontChatSearchChats,
              style: _labelStyle(context).copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            size: rowSize,
            borderRadius: rounded,
            hoverBackgroundColor: tokens.colors.surface.enabled,
            leading: Icon(
              LottiIcons.search,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
            onTap: () => setState(() => _searchOpen = true),
          ),
        if (hasAny && _searchOpen) ...[
          SizedBox(height: tokens.spacing.step2),
          DesignSystemSearch(
            hintText: messages.frontChatSearchChats,
            size: DesignSystemSearchSize.small,
            focusNode: _searchFocus,
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            // Clearing closes it again: the list is back as it was.
            onClear: () => setState(() {
              _query = '';
              _searchOpen = false;
            }),
          ),
        ],
        // A search is one group of what matched; otherwise the recency groups.
        if (searching && live.isNotEmpty) group(null, live),
        if (!searching)
          for (final MapEntry(key: recency, value: rows) in sections.entries)
            group(recency.label(messages), rows),
        if (index != null && live.isEmpty && archived.isEmpty)
          Padding(
            padding: EdgeInsets.all(textInset),
            child: Text(
              hasAny
                  ? messages.frontChatNoMatchingChats
                  : messages.frontChatNoChats,
              textAlign: TextAlign.center,
              style: _labelStyle(context).copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        if (archived.isNotEmpty) ...[
          // Room on both sides: the divider separates the groups rather than
          // bordering the row below it.
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
            child: const DesignSystemDivider(),
          ),
          MergeSemantics(
            child: Semantics(
              expanded: showArchived,
              child: DesignSystemListItem(
                key: FrontConversationListKeys.archived,
                // A row that opens, in a row's voice — not another section
                // label.
                titleContent: Text(
                  messages.frontChatArchivedRow(archived.length),
                  style: _labelStyle(context).copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                size: rowSize,
                borderRadius: rounded,
                hoverBackgroundColor: tokens.colors.surface.enabled,
                leading: Icon(
                  LottiIcons.archive,
                  size: IconSizes.s,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                // On the rows' trailing rail, where their menus sit.
                trailing: _TrailingSlot(
                  child: Icon(
                    showArchived ? LottiIcons.collapse : LottiIcons.expand,
                    size: IconSizes.s,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                onTap: () => setState(() => _showArchived = !showArchived),
              ),
            ),
          ),
          if (showArchived) group(null, archived),
        ],
      ],
    );
  }
}

/// How recent a conversation is: the section it is listed under.
enum _Recency {
  today,
  yesterday,
  week,
  older;

  static _Recency of(DateTime at, DateTime now) {
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    return days <= 0
        ? today
        : days == 1
        ? yesterday
        : days < 7
        ? week
        : older;
  }

  String label(AppLocalizations messages) => switch (this) {
    today => messages.calendarTodayLabel,
    yesterday => messages.frontChatYesterday,
    week => messages.frontChatPrevious7Days,
    older => messages.frontChatOlder,
  };
}

/// A destination row's label style (New chat, Inbox, Search): the size of a
/// conversation's title, never larger, so the list's own items lead.
TextStyle _labelStyle(BuildContext context) =>
    context.designTokens.typography.styles.body.bodySmall;

/// Rows are touch-sized on a phone and compact on a wide window.
/// A conversation's row on every layout: its two lines make it a full
/// target already, so it takes the denser padding.
const DesignSystemListItemSize _conversationRowSize =
    DesignSystemListItemSize.small;

DesignSystemListItemSize _rowSize(BuildContext context) =>
    isDesktopLayout(context)
    ? DesignSystemListItemSize.small
    : DesignSystemListItemSize.medium;

/// The trailing column every row shares, sized so its centre falls under
/// the header's close glyph: the list's gutter plus the row's inset plus
/// half this slot equals the header's gutter plus half a tap target. It is
/// as tall as a line of text, so it never sets a row's height; a row's menu
/// is laid over the row at this column's centre rather than inside it, so
/// the button keeps its whole target within the row it belongs to.
class _TrailingSlot extends StatelessWidget {
  const _TrailingSlot({this.child});

  final Widget? child;

  static double widthOf(BuildContext context) {
    final tokens = context.designTokens;
    return (TapTargets.minimum -
            2 * DesignSystemListItem.contentInset(tokens, _rowSize(context)))
        .clamp(0.0, DesignSystemContextMenuButton.extent(tokens));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      width: widthOf(context),
      height: tokens.spacing.step5,
      child: child == null
          ? null
          : OverflowBox(
              maxWidth: DesignSystemContextMenuButton.extent(tokens),
              child: Center(child: child),
            ),
    );
  }
}

/// The height one line of [style] takes as text lays out here — with the
/// text scaler — so a control can sit on that line.
double _lineHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Hg', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// The style a row's time is set in.
/// In tabular figures, so the column lines up digit for digit.
TextStyle _timeStyle(BuildContext context) => context
    .designTokens
    .typography
    .styles
    .others
    .caption
    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// The width the widest of [times] takes as it lays out here — with the
/// text scaler — so every row's time column is that wide.
double _timeWidth(BuildContext context, Iterable<String> times) {
  var widest = 0.0;
  for (final time in times) {
    final painter = TextPainter(
      text: TextSpan(text: time, style: _timeStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  // Rounded up: a fraction short would wrap the widest one.
  return widest.ceilToDouble();
}

/// When a conversation last moved, as a chat list says it: the time today
/// and yesterday (its section names the day), the weekday within a week,
/// else the date.
String _when(BuildContext context, DateTime at, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 1) return deviceClockLabel(context, at);
  if (days < 7) return DateFormat.E(locale).format(at);
  return DateFormat.MMMd(locale).format(at);
}

/// One conversation: its title on one line, and its menu. The open one is
/// the brightest neutral rounded fill — not the accent, which is the user's
/// own bubbles' colour. On a wide window the menu shows on
/// hover or focus and on the open row; the rest of the list stays words.
class _ConversationRow extends StatefulWidget {
  const _ConversationRow({
    required this.conversation,
    required this.now,
    required this.timeWidth,
    required this.borderRadius,
    required this.selected,
    required this.menu,
    required this.onOpen,
    this.pinMenu = true,
    super.key,
  });

  final FrontConversation conversation;
  final DateTime now;

  /// The list's time column: the widest time any row shows.
  final double timeWidth;

  /// The row's own corners, for its fill.
  final BorderRadius borderRadius;
  final bool selected;

  /// Whether the open row shows its menu at rest — not beside the open
  /// conversation, whose header already carries it.
  final bool pinMenu;
  final List<DesignSystemContextMenuItem> menu;
  final VoidCallback onOpen;

  @override
  State<_ConversationRow> createState() => _ConversationRowState();
}

class _ConversationRowState extends State<_ConversationRow> {
  bool _hovered = false;
  bool _focused = false;

  /// The row's menu as a sheet: the same ways out its ⋯ offers.
  Future<void> _showMenuSheet(BuildContext context) =>
      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: widget.conversation.title,
        builder: (sheet) {
          final tokens = sheet.designTokens;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in widget.menu)
                DesignSystemListItem(
                  key: item.key,
                  titleContent: Text(
                    item.label,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: item.isDestructive
                          ? tokens.colors.alert.error.ink
                          : tokens.colors.text.highEmphasis,
                    ),
                  ),
                  leading: Icon(
                    item.icon,
                    size: IconSizes.s,
                    color: item.isDestructive
                        ? tokens.colors.alert.error.ink
                        : tokens.colors.text.mediumEmphasis,
                  ),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    item.onTap?.call();
                  },
                ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The menu is on the open row, and on any row hovered or focused; the
    // rest of the list stays words.
    final showMenu =
        (widget.selected && widget.pinMenu) || _hovered || _focused;
    final extent = DesignSystemContextMenuButton.extent(tokens);
    final conversation = widget.conversation;
    final preview = conversation.preview?.trim();
    final when = _when(context, conversation.lastActivity, widget.now);
    // On the open row's fill, the second line is as bright as the title:
    // dim text never sits on the brightest neutral.
    final quiet = tokens.typography.styles.body.bodySmall.copyWith(
      color: widget.selected
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.mediumEmphasis,
    );
    final row = DesignSystemListItem(
      // The title on the whole width — two lines before it is cut, so no
      // title is left mid-word — and under it where the conversation got
      // to, her last answer, with when it moved at the line's end. While the
      // menu shows, it takes the time's place; the time keeps its room, so
      // nothing reflows.
      titleContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            conversation.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            // An archived one is quieter in tone as well as marked — unless
            // it is the open one, whose fill never carries dim text.
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: conversation.archived && !widget.selected
                  ? tokens.colors.text.mediumEmphasis
                  : tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          Row(
            children: [
              Expanded(
                child: Text(
                  (preview?.isNotEmpty ?? false) ? preview! : '',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: quiet,
                ),
              ),
              // Room for the fade to finish before the time begins.
              SizedBox(width: tokens.spacing.step4),
              Visibility(
                visible: !showMenu,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: SizedBox(
                  width: widget.timeWidth,
                  child: Text(
                    when,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    softWrap: false,
                    style: _timeStyle(context).copyWith(
                      color: widget.selected
                          ? tokens.colors.text.highEmphasis
                          : tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      size: _conversationRowSize,
      borderRadius: widget.borderRadius,
      // The open one is the brightest neutral in the list; a hovered one
      // takes a quieter fill, so the two never look alike.
      activated: widget.selected,
      activatedBackgroundColor: tokens.colors.surface.focusPressed,
      hoverBackgroundColor: tokens.colors.surface.enabled,
      // An archived one says so wherever it shows — a search included.
      leading: widget.conversation.archived
          ? Icon(
              LottiIcons.archive,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            )
          : null,
      onTap: widget.onOpen,
      onHoverChanged: (value) => setState(() => _hovered = value),
      onFocusChanged: (value) => setState(() => _focused = value),
    );
    return Semantics(
      selected: widget.selected,
      // A long press offers any row's menu, so a phone — no hover — reaches
      // the rows whose menu is not shown.
      onLongPressHint: context.messages.frontChatRowMenuHint,
      child: Stack(
        children: [
          GestureDetector(
            onLongPress: () => _showMenuSheet(context),
            child: row,
          ),
          // Over the row, inside its bounds, so the whole target answers:
          // a near miss opens the menu, never the conversation.
          // On the preview line, at its end: in the very place of the time it
          // stands in for.
          Positioned(
            // Centred on the preview line: the row's bottom inset plus half
            // that line's own height, as its text lays out.
            bottom:
                DesignSystemListItem.verticalInset(
                  tokens,
                  _conversationRowSize,
                ) +
                _lineHeight(context, quiet) / 2 +
                tokens.spacing.step2 -
                extent / 2,
            right:
                DesignSystemListItem.contentInset(
                  tokens,
                  _conversationRowSize,
                ) -
                extent / 4,
            width: extent,
            height: extent,
            child: Center(
              child: Visibility(
                visible: showMenu,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: DesignSystemContextMenuButton(
                  key: FrontConversationListKeys.menu(widget.conversation.id),
                  // Quiet on every row but the open one, so the rail of
                  // menus a touch screen shows does not read as a column.
                  iconColor: widget.selected
                      ? tokens.colors.text.mediumEmphasis
                      : tokens.colors.text.lowEmphasis,
                  items: widget.menu,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
