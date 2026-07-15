import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/domain/app_command_text.dart';
import 'package:lotti/features/keyboard/ui/shortcut_label_formatter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Searchable catalog shared by the command palette and persistent help page.
class CommandCatalogView extends StatefulWidget {
  const CommandCatalogView({
    required this.paletteMode,
    this.snapshot,
    this.onCommandSelected,
    this.platform,
    super.key,
  });

  final bool paletteMode;
  final AppCommandContextSnapshot? snapshot;
  final ValueChanged<AppCommandId>? onCommandSelected;
  final TargetPlatform? platform;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _clampIndex() {
    final definitions = _definitions(context);
    if (_selectedIndex >= definitions.length) {
      _selectedIndex = 0;
    }
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
    if (widget.paletteMode &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(definitions, 1);
      return KeyEventResult.handled;
    }
    if (widget.paletteMode && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(definitions, -1);
      return KeyEventResult.handled;
    }
    if (widget.paletteMode && event.logicalKey == LogicalKeyboardKey.home) {
      _selectIndex(definitions, 0);
      return KeyEventResult.handled;
    }
    if (widget.paletteMode && event.logicalKey == LogicalKeyboardKey.end) {
      _selectIndex(definitions, definitions.length - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && widget.paletteMode) {
      _invoke(context, definitions.elementAtOrNull(_selectedIndex));
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

  void _moveSelection(List<AppCommandDefinition> definitions, int delta) {
    if (definitions.isEmpty) return;
    var nextIndex = (_selectedIndex + delta) % definitions.length;
    if (nextIndex < 0) nextIndex += definitions.length;
    _selectIndex(definitions, nextIndex);
  }

  void _selectIndex(List<AppCommandDefinition> definitions, int index) {
    if (definitions.isEmpty) return;
    setState(() => _selectedIndex = index);
    _scheduleEnsureSelectedVisible();
  }

  void _scheduleEnsureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final definitions = _definitions(context);
      final selected = definitions.elementAtOrNull(_selectedIndex);
      final selectedContext = selected == null
          ? null
          : _rowKeys[selected.id]?.currentContext;
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
            hintText: widget.paletteMode
                ? messages.commandPaletteSearchHint
                : messages.keyboardShortcutsSearchHint,
            semanticsLabel: widget.paletteMode
                ? messages.commandPaletteSearchHint
                : messages.keyboardShortcutsSearchHint,
            onChanged: (value) {
              setState(() {
                _query = value;
                _selectedIndex = 0;
              });
              _scheduleEnsureSelectedVisible();
            },
          ),
          SizedBox(height: tokens.spacing.step4),
          Expanded(
            child: definitions.isEmpty
                ? Center(
                    child: Text(
                      widget.paletteMode
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
                      children: _buildGroups(context, definitions),
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
