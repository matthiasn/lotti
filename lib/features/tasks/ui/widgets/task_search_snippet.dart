import 'package:lotti/classes/task_search_hit.dart';
import 'package:lotti/database/search_hit.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_type_icon.dart';
import 'package:material_ui/material_ui.dart';

/// Where a search found a task: the glyph of the entity that matched — the
/// task itself, or one of its entries, recordings or checklist items — and
/// a few words around the match, the matched ones emphasised.
class TaskSearchSnippet extends StatelessWidget {
  const TaskSearchSnippet({required this.hit, super.key});

  final TaskSearchHit hit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: tokens.spacing.step1),
          child: Icon(
            entryTypeIcon(hit.matchedType),
            size: tokens.typography.size.caption,
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                for (final span in snippetSpans(hit.snippet))
                  TextSpan(
                    text: span.text,
                    style: span.matched
                        ? style.copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          )
                        : null,
                  ),
              ],
            ),
            style: style,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
