import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Offers to log a check-in after the user comes back from a call or message
/// they started in Lotti (plan v2 phase 7 item 5, ADR 0041 D4).
///
/// Deliberately an inline card rather than a dialog. The user has just
/// returned from a conversation and may want to do something else entirely;
/// a modal would demand an answer before they can reach the rest of the app,
/// while a card can simply be ignored. Declining leaves no trace — the marker
/// is dropped and nothing is written anywhere.
///
/// Renders nothing when there is no marker, when it has expired, or when the
/// person it names no longer resolves (deleted, or private while private
/// entries are hidden) — a prompt about a person the user cannot see would
/// leak the fact that they exist.
class PostInteractionPrompt extends ConsumerStatefulWidget {
  const PostInteractionPrompt({super.key});

  @override
  ConsumerState<PostInteractionPrompt> createState() =>
      _PostInteractionPromptState();
}

class _PostInteractionPromptState extends ConsumerState<PostInteractionPrompt>
    with WidgetsBindingObserver {
  PendingInteraction? _pending;
  String? _personName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Also on mount, not only on resume: the app may have been killed while
    // the user was in the dialer, in which case this is a cold start rather
    // than a resume and no lifecycle event will arrive.
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final pending = await ref.read(pendingInteractionStoreProvider).read();

    // Resolve the person through the repository rather than trusting the
    // marker: it holds an id written before the user left, and the person may
    // have been deleted or hidden since.
    final relationship = pending == null
        ? null
        : await ref
              .read(relationshipRepositoryProvider)
              .getRelationshipById(pending.relationshipId);

    if (!mounted) return;
    setState(() {
      _pending = relationship == null ? null : pending;
      _personName = relationship?.data.title;
    });
  }

  Future<void> _dismiss() async {
    await ref.read(pendingInteractionStoreProvider).clear();
    if (!mounted) return;
    setState(() {
      _pending = null;
      _personName = null;
    });
  }

  Future<void> _logCheckIn() async {
    final pending = _pending;
    if (pending == null) return;

    // Cleared before the sheet opens, not after it closes: the offer has been
    // taken up either way, and a user who opens the form and then backs out
    // should not be asked a second time.
    await _dismiss();
    if (!mounted) return;

    await showCheckInCaptureSheet(
      context: context,
      relationshipId: pending.relationshipId,
      prefilledInteractionType: pending.interactionType,
      prefilledTime: pending.startedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    final name = _personName;
    if (pending == null || name == null) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final messages = context.messages;

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spacing.sectionGap),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.relationshipPostCallTitle(name),
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              messages.relationshipPostCallBody,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.cardItemSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: tokens.spacing.step2,
              children: [
                DesignSystemButton(
                  label: messages.relationshipPostCallDismiss,
                  variant: DesignSystemButtonVariant.tertiary,
                  onPressed: () => unawaited(_dismiss()),
                ),
                DesignSystemButton(
                  label: messages.relationshipPostCallConfirm,
                  onPressed: () => unawaited(_logCheckIn()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
