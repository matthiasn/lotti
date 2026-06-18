import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';

/// Right-side overlay that opens the focused graph node's FULL details — the
/// app's real [TaskForm] (tasks) or [EntryDetailsWidget] (any other entry),
/// rendered at a narrow width so it reads like the mobile detail view. Rendered
/// above the navigational inspector; [onClose] dismisses it.
///
/// This is integration glue around the app's own detail widgets (which carry
/// their own tests); only the load/error/empty shells live here.
class EntryDetailSidebar extends ConsumerWidget {
  const EntryDetailSidebar({
    required this.entryId,
    required this.onClose,
    required this.tokens,
    super.key,
  });

  final String entryId;
  final VoidCallback onClose;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(entryControllerProvider(id: entryId));
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.4),
            blurRadius: 48,
            spreadRadius: -8,
            offset: const Offset(-16, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level01.withValues(alpha: 0.94),
              borderRadius: radius,
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onClose: onClose, tokens: tokens),
                Divider(color: tokens.colors.decorative.level01, height: 1),
                Expanded(
                  child: state.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, _) => _Message(
                      text: "Couldn't load this entry",
                      tokens: tokens,
                    ),
                    data: (entryState) {
                      final item = entryState?.entry;
                      if (item == null) {
                        return _Message(
                          text: 'Entry not found',
                          tokens: tokens,
                        );
                      }
                      return _DetailBody(item: item, entryId: entryId);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose, required this.tokens});

  final VoidCallback onClose;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.cardPadding,
        tokens.spacing.step3,
        tokens.spacing.step3,
        tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Text(
            'DETAILS',
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          const Spacer(),
          Material(
            color: tokens.colors.background.level02.withValues(alpha: 0.7),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onClose,
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step2),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.tokens});

  final String text;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}

/// Hosts the app's real detail widget for [item]. Kept tiny and isolated so the
/// heavy, already-tested widgets it embeds are the only thing here that the
/// unit suite can't reasonably exercise.
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.item, required this.entryId});

  final JournalEntity item;
  final String entryId;

  @override
  Widget build(BuildContext context) {
    // coverage:ignore-start
    return SingleChildScrollView(
      child: item is Task
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: TaskForm(taskId: entryId),
            )
          : EntryDetailsWidget(itemId: entryId, showAiEntry: true),
    );
    // coverage:ignore-end
  }
}
