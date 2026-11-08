import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One thing `@` can name in a chat input: a category, say.
@immutable
class DesignSystemChatInputMention {
  const DesignSystemChatInputMention({required this.label, this.color});

  /// What goes in the text after the `@`.
  final String label;

  /// Its colour, shown as a dot beside it.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is DesignSystemChatInputMention &&
      other.label == label &&
      other.color == color;

  @override
  int get hashCode => Object.hash(label, color);
}

/// Stable keys for the `@` list.
@visibleForTesting
abstract final class DesignSystemChatInputMentionKeys {
  static const Key list = Key('ds-chat-input-mentions');
  static Key option(String label) => Key('ds-chat-input-mention-$label');
}

/// Whether `@` is offering, what, and which is highlighted — kept in step
/// with the text by [update].
@visibleForTesting
class DesignSystemChatInputMentionController extends ChangeNotifier {
  /// The most it offers at once.
  static const int maxShown = 6;

  /// `@` and the word after it, right before the caret, at the start of the
  /// text or after a space.
  static final RegExp _token = RegExp(r'(?:^|\s)@([^\s@]*)$');

  List<DesignSystemChatInputMention> _shown = const [];
  int _highlighted = 0;
  int? _tokenStart;
  String? _query;
  String? _dismissedAt;

  /// What it offers now; empty while closed.
  List<DesignSystemChatInputMention> get shown => _shown;
  int get highlightedIndex => _highlighted;
  bool get isOpen => _shown.isNotEmpty;
  DesignSystemChatInputMention? get highlighted =>
      isOpen ? _shown[_highlighted] : null;

  /// The query `@` is completing in [value], if any: the word typed after it.
  String? query(TextEditingValue value) {
    final caret = value.selection.baseOffset;
    if (!value.selection.isCollapsed || caret < 0) return null;
    final match = _token.firstMatch(value.text.substring(0, caret));
    if (match == null) return null;
    _tokenStart = caret - match.group(1)!.length - 1;
    return _query = match.group(1);
  }

  /// Follows [value]: opens on `@` with what [options] match the word after
  /// it — those starting with it first — and closes otherwise.
  void update(
    TextEditingValue value, {
    required List<DesignSystemChatInputMention> options,
  }) {
    final q = options.isEmpty ? null : query(value);
    final key = q == null ? null : '$_tokenStart:$q';
    var next = const <DesignSystemChatInputMention>[];
    if (q != null && key != _dismissedAt) {
      final lower = q.toLowerCase();
      final starts = <DesignSystemChatInputMention>[];
      final contains = <DesignSystemChatInputMention>[];
      for (final option in options) {
        final label = option.label.toLowerCase();
        if (label.startsWith(lower)) {
          starts.add(option);
        } else if (label.contains(lower)) {
          contains.add(option);
        }
      }
      next = [...starts, ...contains].take(maxShown).toList();
    }
    if (q == null) _dismissedAt = null;
    final changed =
        next.length != _shown.length ||
        Iterable<int>.generate(next.length).any((i) => next[i] != _shown[i]);
    if (!changed) return;
    _shown = next;
    _highlighted = 0;
    notifyListeners();
  }

  /// Moves the highlight by [delta], round.
  void move(int delta) {
    if (!isOpen) return;
    _highlighted = (_highlighted + delta) % _shown.length;
    notifyListeners();
  }

  /// Closes until the word under the caret changes.
  void dismiss() {
    if (!isOpen) return;
    _dismissedAt = _tokenStart == null ? null : '$_tokenStart:$_query';
    _shown = const [];
    notifyListeners();
  }

  /// [value] with the `@word` before the caret replaced by `@Label `, the
  /// caret after it.
  TextEditingValue insert(
    TextEditingValue value,
    DesignSystemChatInputMention option,
  ) {
    final caret = value.selection.baseOffset;
    final start = _tokenStart;
    if (start == null || caret < start) return value;
    final inserted = '@${option.label} ';
    final text = value.text.replaceRange(start, caret, inserted);
    _shown = const [];
    notifyListeners();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
  }
}

/// Floats what `@` offers above [child] — the chat input's card — aligned
/// to its leading edge, without moving anything under it.
@visibleForTesting
class DesignSystemChatInputMentionAnchor extends StatefulWidget {
  const DesignSystemChatInputMentionAnchor({
    required this.controller,
    required this.onPick,
    required this.child,
    super.key,
  });

  final DesignSystemChatInputMentionController controller;
  final ValueChanged<DesignSystemChatInputMention> onPick;
  final Widget child;

  @override
  State<DesignSystemChatInputMentionAnchor> createState() =>
      _MentionAnchorState();
}

class _MentionAnchorState extends State<DesignSystemChatInputMentionAnchor> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant DesignSystemChatInputMentionAnchor old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final open = widget.controller.isOpen;
    if (open && !_portal.isShowing) _portal.show();
    if (!open && _portal.isShowing) _portal.hide();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          followerAnchor: Alignment.bottomLeft,
          offset: Offset(0, -tokens.spacing.step3),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: TextFieldTapRegion(
              child: _MentionList(
                controller: widget.controller,
                onPick: widget.onPick,
              ),
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _MentionList extends StatelessWidget {
  const _MentionList({required this.controller, required this.onPick});

  final DesignSystemChatInputMentionController controller;
  final ValueChanged<DesignSystemChatInputMention> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final shown = controller.shown;
    return Semantics(
      container: true,
      label: context.messages.chatInputMentionsLabel,
      child: ConstrainedBox(
        key: DesignSystemChatInputMentionKeys.list,
        // Five times the largest step: room for a category's name, never
        // the card's whole width.
        constraints: BoxConstraints(maxWidth: tokens.spacing.step10 * 5),
        child: Material(
          color: tokens.colors.background.level02,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            side: BorderSide(color: tokens.colors.decorative.level02),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++)
                  _MentionRow(
                    option: shown[i],
                    highlighted: i == controller.highlightedIndex,
                    onTap: () => onPick(shown[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionRow extends StatelessWidget {
  const _MentionRow({
    required this.option,
    required this.highlighted,
    required this.onTap,
  });

  final DesignSystemChatInputMention option;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = option.color;
    return Semantics(
      button: true,
      selected: highlighted,
      child: InkWell(
        key: DesignSystemChatInputMentionKeys.option(option.label),
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: Ink(
          height: tokens.spacing.step8,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
          decoration: BoxDecoration(
            color: highlighted ? tokens.colors.surface.selected : null,
            borderRadius: BorderRadius.circular(tokens.radii.s),
          ),
          child: Row(
            spacing: tokens.spacing.step3,
            children: [
              if (color != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: tokens.spacing.step3),
                ),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
