import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The user's own words in a history list, folded — the one fold every
/// check-in surface uses, for typed and spoken words alike, so a note and a
/// recording on the same rail read in one voice.
///
/// Shows the [summary] when one was written (a recording's one-liner), else
/// the first [foldedLines] lines of [words] — and, when there is more,
/// *Show more* to read all of [words] in place, *Show less* to fold them
/// again. A minute of speech set out in full made every spoken row the
/// longest on the page.
///
/// The summary is data, not a lookup: a row that fetched its own line was
/// laid out three lines tall and shrank when the line arrived, on every
/// reload and every time it scrolled back into view.
///
/// Opened, the words keep themselves alive in a lazy list: the list drops
/// rows that scroll out of its cache extent and builds them again on the way
/// back, and a row built again is folded — the reader's *Show more* undone,
/// and a row above the viewport suddenly shorter, which moves the history
/// under them. Folded rows are dropped as usual; there is nothing to keep.
class FoldedWords extends StatefulWidget {
  const FoldedWords({
    required this.id,
    required this.words,
    this.summary,
    this.style,
    super.key,
  });

  /// How many lines show while folded.
  static const int foldedLines = 3;

  /// The entry the words belong to, naming the keys.
  final String id;
  final String words;

  /// The line to lead with, or null to lead with [words].
  final String? summary;

  /// Defaults to [wordsStyle] — the tier the user's words wear everywhere.
  final TextStyle? style;

  /// The user's words, typed or spoken: the small body tier at full ink.
  /// Status and explanation sit below it in the caption tier, so the two can
  /// never be mistaken for each other.
  static TextStyle wordsStyle(BuildContext context) {
    final tokens = context.designTokens;
    return tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
  }

  @override
  State<FoldedWords> createState() => _FoldedWordsState();
}

/// Whether [words] run past the fold at [maxWidth]. The painter holds
/// native paragraph memory, so it is released at once rather than left for
/// the finalizer — a long history measures a row on every layout.
bool _overflows(
  BuildContext context,
  String words,
  TextStyle style,
  double maxWidth,
) {
  final painter = TextPainter(
    text: TextSpan(text: words, style: style),
    maxLines: FoldedWords.foldedLines,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  try {
    return painter.didExceedMaxLines;
  } finally {
    painter.dispose();
  }
}

class _FoldedWordsState extends State<FoldedWords>
    with AutomaticKeepAliveClientMixin {
  var _expanded = false;

  @override
  bool get wantKeepAlive => _expanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tokens = context.designTokens;
    final messages = context.messages;
    final style = widget.style ?? FoldedWords.wordsStyle(context);
    final words = widget.words;
    final summary = widget.summary;
    return LayoutBuilder(
      builder: (context, constraints) {
        // More to read when there is a summary in front of the words, or
        // when the words run past the fold — measured, so words that already
        // fit never carry a *Show more* that reveals nothing.
        final overflows =
            summary != null ||
            _overflows(context, words, style, constraints.maxWidth);
        final shown = _expanded ? words : (summary ?? words);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shown,
              key: ValueKey('folded-words-${widget.id}'),
              maxLines: _expanded ? null : FoldedWords.foldedLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              DsQuietInk(
                key: ValueKey('folded-words-more-${widget.id}'),
                onTap: _toggle,
                builder: (context, highlighted) => Semantics(
                  button: true,
                  expanded: _expanded,
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step1),
                    child: Text(
                      _expanded
                          ? messages.timelineShowLess
                          : messages.timelineShowMore,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: highlighted
                            ? tokens.colors.interactive.hover
                            : tokens.colors.interactive.enabled,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
