import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_cited_answer.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/citation_badge.dart';
import 'package:material_ui/material_ui.dart';

/// One entry a journal answer rests on: what it is and when, and the words
/// of it the answer quotes, opening the entry on a tap. Led by the
/// [number] its citations wear when the answer's words cite it by number.
class FrontCitedSourceRow extends StatelessWidget {
  const FrontCitedSourceRow({
    required this.source,
    required this.onOpen,
    this.number,
    super.key,
  });

  final FrontCitedSource source;
  final VoidCallback? onOpen;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final caption = tokens.typography.styles.others.caption;
    final quote = source.quote;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(source.date.toLocal());
    // A recording's label is its file name, and a note's is its first line,
    // which the quote already says: what it is, or just when, reads better.
    final label = source.kind == QuerySourceKind.recording && source.transcript
        ? context.messages.queryRecordingTranscript
        : quote.startsWith(source.label)
        ? null
        : source.label;
    final dateStyle = caption.copyWith(color: tokens.colors.text.lowEmphasis);
    // The card is drawn on a plain box; the ink needs a surface of its own.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (number case final number?) ...[
                CitationBadge('$number'),
                SizedBox(width: tokens.spacing.step3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      label == null
                          ? TextSpan(text: date, style: dateStyle)
                          : TextSpan(
                              text: label,
                              children: [
                                TextSpan(text: ' · $date', style: dateStyle),
                              ],
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    if (quote.isNotEmpty)
                      // The passage as quoted, set off by a rule like a
                      // blockquote.
                      Container(
                        margin: EdgeInsets.only(top: tokens.spacing.step1),
                        padding: EdgeInsetsDirectional.only(
                          start: tokens.spacing.step3,
                        ),
                        decoration: BoxDecoration(
                          border: BorderDirectional(
                            start: BorderSide(
                              color: tokens.colors.decorative.level02,
                            ),
                          ),
                        ),
                        child: Text(
                          quote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: caption.copyWith(
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
