import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Full-text / vector search mode toggle shown under the logbook header when
/// the vector-search config flag is on, plus the in-flight spinner or timing
/// readout for the last vector query.
class LogbookSearchModeRow extends ConsumerWidget {
  const LogbookSearchModeRow({required this.state, super.key});

  final JournalPageState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );
    final tokens = context.designTokens;
    final captionStyle = tokens.typography.styles.others.caption;
    final iconSize = tokens.spacing.step5;

    return Row(
      children: [
        SegmentedButton<SearchMode>(
          selected: {state.searchMode},
          showSelectedIcon: false,
          onSelectionChanged: (selected) {
            controller.setSearchMode(selected.first);
          },
          segments: [
            ButtonSegment<SearchMode>(
              value: SearchMode.fullText,
              label: Text(
                context.messages.searchModeFullText,
                style: captionStyle,
              ),
              icon: Icon(Icons.text_fields, size: iconSize),
            ),
            ButtonSegment<SearchMode>(
              value: SearchMode.vector,
              label: Text(
                context.messages.searchModeVector,
                style: captionStyle,
              ),
              icon: Icon(Icons.hub_outlined, size: iconSize),
            ),
          ],
        ),
        SizedBox(width: tokens.spacing.step4),
        if (state.vectorSearchInFlight)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        else if (state.searchMode == SearchMode.vector &&
            state.vectorSearchElapsed != null)
          Expanded(
            child: Text(
              context.messages.vectorSearchTiming(
                state.vectorSearchElapsed!.inMilliseconds,
                state.vectorSearchResultCount,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: captionStyle.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
      ],
    );
  }
}
