import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/domain/app_command_text.dart';
import 'package:lotti/features/keyboard/domain/palette_jump.dart';
import 'package:lotti/features/keyboard/ui/shortcut_label_formatter.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Searchable catalog shared by the command palette and persistent help page.
///
/// In the palette, a [jumpSearch] also lists the tasks, entries, projects,
/// events and people whose title matches what was typed, below the
/// commands; arrow keys and Enter move through both as one list, and
/// choosing one calls [onJumpSelected].
class CommandCatalogView extends StatefulWidget {
  const CommandCatalogView({
    required this.paletteMode,
    this.snapshot,
    this.onCommandSelected,
    this.jumpSearch,
    this.onJumpSelected,
    this.platform,
    super.key,
  });

  final bool paletteMode;
  final AppCommandContextSnapshot? snapshot;
  final ValueChanged<AppCommandId>? onCommandSelected;
  final PaletteJumpSearch? jumpSearch;
  final ValueChanged<PaletteJumpTarget>? onJumpSelected;
  final TargetPlatform? platform;

  /// How long typing must pause before the palette searches titles.
  static const jumpSearchDebounce = Duration(milliseconds: 120);

  /// Characters typed before titles are searched: a single letter matches
  /// too much to help.
  static const minJumpQueryLength = 2;

  @override
  State<CommandCatalogView> createState() => _CommandCatalogViewState();
}

class _CommandCatalogViewState extends State<CommandCatalogView> {
  static final _searchSeparators = RegExp(r'[\s+]');

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'command-search');
  final ScrollController _scrollController = ScrollController();
  final Map<AppCommandId, GlobalKey> _rowKeys = {
    for (final id in AppCommandId.values)
      id: GlobalKey(debugLabel: 'command-row-${id.name}'),
  };
  var _query = '';
  var _selectedIndex = 0;
  List<PaletteJumpTarget> _jumps = const [];
  List<GlobalKey> _jumpKeys = const [];
  Timer? _jumpDebounce;
  var _jumpGeneration = 0;

  bool get _searchesJumps => widget.paletteMode && widget.jumpSearch != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _clampIndex() {
    final definitions = _definitions(context);
    if (_selectedIndex >= definitions.length + _jumps.length) {
      _selectedIndex = 0;
    }
  }

  /// Searches titles once typing pauses. Results arriving for an older query
  /// are dropped, and the last results stay listed until the new ones come.
  void _scheduleJumpSearch(String value) {
    _jumpDebounce?.cancel();
    final search = widget.jumpSearch;
    if (!_searchesJumps || search == null) return;
    final query = value.trim();
    if (query.length < CommandCatalogView.minJumpQueryLength) {
      _jumpGeneration++;
      _showJumps(const []);
      return;
    }
    _jumpDebounce = Timer(CommandCatalogView.jumpSearchDebounce, () async {
      final generation = ++_jumpGeneration;
      List<PaletteJumpTarget> found;
      try {
        found = await search(query);
      } on Exception {
        found = const [];
      }
      if (!mounted || generation != _jumpGeneration) return;
      _showJumps(found);
    });
  }

  void _showJumps(List<PaletteJumpTarget> jumps) {
    setState(() {
      _jumps = jumps;
      _jumpKeys = [
        for (final jump in jumps)
          GlobalKey(debugLabel: 'jump-row-${jump.entityId}'),
      ];
      _clampIndex();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clampIndex();
  }

  @override
  void didUpdateWidget(covariant CommandCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clampIndex();
  }

  @override
  void dispose() {
    _jumpDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<AppCommandDefinition> _definitions(BuildContext context) {
    final messages = context.messages;
    final platform = widget.platform ?? defaultTargetPlatform;
    final normalizedQuery = _normalizeSearchValue(_query);

    bool matches(AppCommandDefinition definition) {
      if (widget.paletteMode) {
        if (definition.paletteVisibility ==
            AppCommandPaletteVisibility.hidden) {
          return false;
        }
        if (!(widget.snapshot?.isAvailable(definition.id) ?? false)) {
          return false;
        }
      }
      if (normalizedQuery.isEmpty) return true;
      final label = AppCommandText.label(messages, definition.id);
      final category = AppCommandText.category(
        messages,
        definition.category,
      );
      final shortcut = ShortcutLabelFormatter.bindings(
        messages,
        definition.bindings,
        platform: platform,
      );
      return _normalizeSearchValue(label).contains(normalizedQuery) ||
          _normalizeSearchValue(category).contains(normalizedQuery) ||
          _normalizeSearchValue(shortcut).contains(normalizedQuery);
    }

    return [
      for (final category in AppCommandCategory.values)
        ...AppCommandCatalog.definitions.where(
          (definition) =>
              definition.category == category && matches(definition),
        ),
    ];
  }

  String _normalizeSearchValue(String value) =>
      value.trim().toLowerCase().replaceAll(_searchSeparators, '');

  KeyEventResult _handleKeyEvent(
    BuildContext context,
    KeyEvent event,
    List<AppCommandDefinition> definitions,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!widget.paletteMode) {
      final result = _handleHelpNavigation(event.logicalKey);
      if (result == KeyEventResult.handled) return result;
    }
    final count = definitions.length + _jumps.length;
    if (widget.paletteMode &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(count, 1);
      return KeyEventResult.handled;
    }
    if (widget.paletteMode && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(count, -1);
      return KeyEventResult.handled;
    }
    if (widget.paletteMode && event.logicalKey == LogicalKeyboardKey.home) {
      _selectIndex(count, 0);
      return KeyEventResult.handled;
    }
    if (widget.paletteMode && event.logicalKey == LogicalKeyboardKey.end) {
      _selectIndex(count, count - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && widget.paletteMode) {
      if (_selectedIndex < definitions.length) {
        _invoke(context, definitions.elementAtOrNull(_selectedIndex));
      } else {
        _openJump(_jumps.elementAtOrNull(_selectedIndex - definitions.length));
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleHelpNavigation(LogicalKeyboardKey key) {
    if (!_scrollController.hasClients) return KeyEventResult.ignored;
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final target = switch (key) {
      LogicalKeyboardKey.arrowDown => position.pixels + viewport * 0.1,
      LogicalKeyboardKey.arrowUp => position.pixels - viewport * 0.1,
      LogicalKeyboardKey.pageDown => position.pixels + viewport,
      LogicalKeyboardKey.pageUp => position.pixels - viewport,
      LogicalKeyboardKey.home => position.minScrollExtent,
      LogicalKeyboardKey.end => position.maxScrollExtent,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _scrollController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    return KeyEventResult.handled;
  }

  void _moveSelection(int count, int delta) {
    if (count == 0) return;
    var nextIndex = (_selectedIndex + delta) % count;
    if (nextIndex < 0) nextIndex += count;
    _selectIndex(count, nextIndex);
  }

  void _selectIndex(int count, int index) {
    if (count == 0) return;
    setState(() => _selectedIndex = index);
    _scheduleEnsureSelectedVisible();
  }

  void _scheduleEnsureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final definitions = _definitions(context);
      final selected = definitions.elementAtOrNull(_selectedIndex);
      final selectedContext = selected != null
          ? _rowKeys[selected.id]?.currentContext
          : _jumpKeys
                .elementAtOrNull(_selectedIndex - definitions.length)
                ?.currentContext;
      if (selectedContext == null) return;
      Scrollable.ensureVisible(
        selectedContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _invoke(BuildContext context, AppCommandDefinition? definition) {
    final snapshot = widget.snapshot;
    if (!widget.paletteMode || definition == null || snapshot == null) return;
    final onCommandSelected = widget.onCommandSelected;
    if (onCommandSelected != null) {
      onCommandSelected(definition.id);
    } else {
      unawaited(snapshot.invoke(definition.id));
    }
  }

  void _openJump(PaletteJumpTarget? target) {
    if (target != null) widget.onJumpSelected?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final definitions = _definitions(context);
    final messages = context.messages;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _handleKeyEvent(context, event, definitions),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignSystemSearch(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: _searchHint(messages),
            semanticsLabel: _searchHint(messages),
            onChanged: (value) {
              setState(() {
                _query = value;
                _selectedIndex = 0;
              });
              _scheduleJumpSearch(value);
              _scheduleEnsureSelectedVisible();
            },
          ),
          SizedBox(height: tokens.spacing.step4),
          Expanded(
            child: definitions.isEmpty && _jumps.isEmpty
                ? Center(
                    child: Text(
                      _searchesJumps
                          ? messages.commandPaletteNothingFound
                          : widget.paletteMode
                          ? messages.commandPaletteNoResults
                          : messages.keyboardShortcutsNoResults,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._buildGroups(context, definitions),
                        ..._buildJumps(context, definitions.length),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    List<AppCommandDefinition> definitions,
  ) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final platform = widget.platform ?? defaultTargetPlatform;
    final widgets = <Widget>[];

    for (final category in AppCommandCategory.values) {
      final group = definitions
          .where((definition) => definition.category == category)
          .toList(growable: false);
      if (group.isEmpty) continue;
      if (widgets.isNotEmpty) {
        widgets.add(SizedBox(height: tokens.spacing.sectionGap));
      }
      widgets
        ..add(
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step3),
            child: Text(
              AppCommandText.category(messages, category),
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        )
        ..add(
          DesignSystemGroupedList(
            padding: EdgeInsets.zero,
            children: [
              for (final (index, definition) in group.indexed)
                _commandRow(
                  context,
                  definition,
                  platform: platform,
                  selected:
                      widget.paletteMode &&
                      definitions.indexOf(definition) == _selectedIndex,
                  showDivider: index < group.length - 1,
                ),
            ],
          ),
        );
    }
    return widgets;
  }

  String _searchHint(AppLocalizations messages) => _searchesJumps
      ? messages.commandPaletteSearchEverythingHint
      : widget.paletteMode
      ? messages.commandPaletteSearchHint
      : messages.keyboardShortcutsSearchHint;

  /// The titles matching the query, after the commands: under "Go to", or
  /// "Similar titles" when none held every word and the nearest are shown.
  List<Widget> _buildJumps(BuildContext context, int commandCount) {
    if (_jumps.isEmpty) return const [];
    final tokens = context.designTokens;
    final messages = context.messages;
    return [
      if (commandCount > 0) SizedBox(height: tokens.spacing.sectionGap),
      Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.step3),
        child: Text(
          _jumps.first.fuzzy
              ? messages.commandPaletteSimilarTitles
              : messages.commandPaletteGoTo,
          style: tokens.typography.styles.others.overline.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
      DesignSystemGroupedList(
        padding: EdgeInsets.zero,
        children: [
          for (final (index, jump) in _jumps.indexed)
            KeyedSubtree(
              key: _jumpKeys[index],
              child: DesignSystemListItem(
                key: ValueKey('jump-${jump.kind.name}-${jump.entityId}'),
                title: jump.title,
                subtitle: _jumpKindLabel(messages, jump.kind),
                leading: Icon(
                  _jumpKindIcon(jump.kind),
                  color: tokens.colors.text.mediumEmphasis,
                ),
                selected: commandCount + index == _selectedIndex,
                activated: commandCount + index == _selectedIndex,
                showDivider: index < _jumps.length - 1,
                semanticsLabel:
                    '${jump.title}, ${_jumpKindLabel(messages, jump.kind)}',
                onTap: () => _openJump(jump),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _commandRow(
    BuildContext context,
    AppCommandDefinition definition, {
    required TargetPlatform platform,
    required bool selected,
    required bool showDivider,
  }) {
    final messages = context.messages;
    final label = AppCommandText.label(messages, definition.id);
    final shortcut = ShortcutLabelFormatter.bindings(
      messages,
      definition.bindings,
      platform: platform,
    );
    return KeyedSubtree(
      key: _rowKeys[definition.id],
      child: DesignSystemListItem(
        key: ValueKey(definition.id),
        title: label,
        selected: selected,
        activated: selected,
        showDivider: showDivider,
        semanticsLabel: shortcut.isEmpty ? label : '$label, $shortcut',
        onTap: widget.paletteMode ? () => _invoke(context, definition) : null,
        forcedState: widget.paletteMode
            ? null
            : DesignSystemListItemVisualState.idle,
        trailing: shortcut.isEmpty ? null : _ShortcutBadge(label: shortcut),
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surface.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step2,
        ),
        child: Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}

String _jumpKindLabel(AppLocalizations messages, PaletteJumpKind kind) =>
    switch (kind) {
      PaletteJumpKind.task => messages.navTabTitleTasks,
      PaletteJumpKind.entry => messages.navTabTitleJournal,
      PaletteJumpKind.project => messages.navTabTitleProjects,
      PaletteJumpKind.event => messages.navTabTitleEvents,
      PaletteJumpKind.person => messages.navTabTitlePeople,
    };

IconData _jumpKindIcon(PaletteJumpKind kind) => switch (kind) {
  PaletteJumpKind.task => LottiIcons.list,
  PaletteJumpKind.entry => LottiIcons.book,
  PaletteJumpKind.project => LottiIcons.folder,
  PaletteJumpKind.event => LottiIcons.calendar,
  PaletteJumpKind.person => LottiIcons.people,
};
