import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the composer describing [pending] — the channel, when it started
/// and the whole minutes since — or, with no marker, as an ordinary check-in
/// that starts from [fallbackInteractionType]. The offer below and the
/// person page's own *Log check-in* and *Dictate* all come through here, so
/// a call that was just placed is logged as that call whichever door the
/// user reaches for.
///
/// The elapsed time is measured to [openedAt] — the moment the user asked
/// for the composer, before any claim was cleared — because that is what the
/// offer quoted, and the form must agree with it.
Future<CheckInEntry?> showCheckInForInteraction({
  required BuildContext context,
  required String relationshipId,
  required DateTime openedAt,
  PendingInteraction? pending,
  CheckInInteractionType? fallbackInteractionType,
  bool startSpeaking = false,
}) {
  final elapsed = pending == null
      ? null
      : openedAt.difference(pending.startedAt);
  return showCheckInCaptureSheet(
    context: context,
    relationshipId: relationshipId,
    prefilledInteractionType:
        pending?.interactionType ?? fallbackInteractionType,
    prefilledTime: pending?.startedAt,
    prefilledDuration: elapsed == null
        ? null
        : Duration(minutes: elapsed.inMinutes),
    startSpeaking: startSpeaking,
  );
}

/// The one way into the composer for a person: claims a call or message just
/// placed to them ([PendingInteractionClaims.claimFor]) and opens the
/// composer describing it — or, with none, starting from
/// [fallbackInteractionType]. The offer's own answer and the page's *Log
/// check-in* and *Dictate* all come through here.
///
/// A composer closed without saving hands the claim back, so the offer
/// returns with the call it was about. The claims notifier is read before
/// the first await: the page may be gone by the time the sheet closes.
///
/// One opening per person at a time: a second tap on any of the doors while
/// the first is still claiming — the claim waits on the settings database —
/// would otherwise get no marker and stack a second, generic composer on the
/// first. It resolves to null and opens nothing.
Future<CheckInEntry?> openCheckInForPerson({
  required BuildContext context,
  required WidgetRef ref,
  required String relationshipId,
  CheckInInteractionType? fallbackInteractionType,
  bool startSpeaking = false,
}) async {
  final claims = ref.read(pendingInteractionClaimsProvider.notifier);
  if (!claims.beginOpening(relationshipId)) return null;
  try {
    // Read before the claim: clearing the marker can cross a minute
    // boundary, and the minutes the offer quoted are the ones the form must
    // show.
    final openedAt = clock.now();
    final pending = await claims.claimFor(relationshipId);
    if (!context.mounted) {
      if (pending != null) await claims.release(pending);
      return null;
    }
    final saved = await showCheckInForInteraction(
      context: context,
      relationshipId: relationshipId,
      openedAt: openedAt,
      pending: pending,
      fallbackInteractionType: fallbackInteractionType,
      startSpeaking: startSpeaking,
    );
    if (saved == null && pending != null) await claims.release(pending);
    return saved;
  } finally {
    claims.endOpening(relationshipId);
  }
}

/// Offers to log a check-in after the user comes back from a call or message
/// they started in Lotti (plan v2 phase 7 item 5, ADR 0041 D4) — the
/// highlighted state at the top of the Check-ins card (design 2026-09-06
/// Q6): it names its evidence — the channel, how long ago, when it started
/// and roughly how long it has been — so the offer reads as "log the call
/// you just had", not as a generic nudge.
///
/// Deliberately inline rather than a dialog. The user has just returned
/// from a conversation and may want to do something else entirely; a modal
/// would demand an answer before they can reach the rest of the app, while
/// a card can simply be ignored. Declining leaves no trace — the marker is
/// dropped and nothing is written anywhere.
///
/// Renders nothing when there is no marker, when it is about someone other
/// than [relationshipId] — a call to Anna is not something to log from Bo's
/// page, and accepting it there would open Anna's composer — when it has
/// expired, or when the person it names no longer resolves (deleted, or
/// private while private entries are hidden): a prompt about a person the
/// user cannot see would leak the fact that they exist.
///
/// [bottomGap] follows the offer and is part of it, so a page can seat it
/// between two sections without a gap appearing where there is no offer.
class PostInteractionPrompt extends ConsumerStatefulWidget {
  const PostInteractionPrompt({
    required this.relationshipId,
    this.bottomGap = 0,
    super.key,
  });

  /// The person whose page this is: the only one whose call it offers.
  final String relationshipId;

  final double bottomGap;

  /// The wash behind the offer: the interactive accent at the tint alpha
  /// over the card surface, the recipe every tone-tinted fill uses.
  static Color washColor(DsTokens tokens) => Color.alphaBlend(
    tokens.colors.interactive.enabled.withValues(alpha: SurfaceAlphas.tint),
    tokens.colors.background.level02,
  );

  @override
  ConsumerState<PostInteractionPrompt> createState() =>
      _PostInteractionPromptState();
}

class _PostInteractionPromptState extends ConsumerState<PostInteractionPrompt>
    with WidgetsBindingObserver {
  PendingInteraction? _pending;
  String? _personName;

  /// Which [_refresh] is the latest. Refreshes overlap — mount, resume and
  /// a claim through the page's own buttons can each start one while
  /// another is still resolving the person — and an older one finishing
  /// last would put back an offer the store no longer holds.
  int _refreshGeneration = 0;

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
  void didUpdateWidget(PostInteractionPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The desktop split keeps this state when the selected person changes:
    // the offer must be re-read for the person now on screen.
    if (oldWidget.relationshipId != widget.relationshipId) {
      unawaited(_refresh());
    }
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
    final generation = ++_refreshGeneration;
    final stored = await ref.read(pendingInteractionStoreProvider).read();
    final pending = stored?.relationshipId == widget.relationshipId
        ? stored
        : null;

    // Resolve the person through the repository rather than trusting the
    // marker: it holds an id written before the user left, and the person may
    // have been deleted or hidden since.
    final relationship = pending == null
        ? null
        : await ref
              .read(relationshipRepositoryProvider)
              .getRelationshipById(pending.relationshipId);

    if (!mounted || generation != _refreshGeneration) return;
    setState(() {
      _pending = relationship == null ? null : pending;
      _personName = relationship?.data.title;
    });
  }

  /// Whether this offer's answer is being acted on. Both buttons hold while
  /// it is: a Dismiss landing in the gap would clear a marker the claim
  /// already holds, and a second Yes would open a second composer.
  bool _busy = false;

  Future<void> _dismiss() async {
    if (_busy) return;
    // A refresh still resolving must not bring back what is being dismissed.
    _refreshGeneration++;
    await ref.read(pendingInteractionStoreProvider).clear();
    if (!mounted) return;
    setState(() {
      _pending = null;
      _personName = null;
    });
  }

  Future<void> _logCheckIn() async {
    if (_pending == null || _busy) return;
    setState(() => _busy = true);
    try {
      await openCheckInForPerson(
        context: context,
        ref: ref,
        relationshipId: widget.relationshipId,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The page's own Log check-in and Dictate take the marker up too; when
    // they do, this offer has been answered and must stop asking.
    ref.listen(
      pendingInteractionClaimsProvider,
      (_, _) => unawaited(_refresh()),
    );
    final pending = _pending;
    final name = _personName;
    if (pending == null || name == null) return const SizedBox.shrink();

    final messages = context.messages;
    // Whole minutes since the user left for the call: what the sheet will
    // prefill as the duration, so the offer and the form agree.
    final minutes = clock.now().difference(pending.startedAt).inMinutes;
    // Asked, not asserted: the marker proves the dialer or the mail app was
    // opened, not that anyone answered. The meta line under it carries when
    // and how long.
    final title = switch (pending.interactionType) {
      CheckInInteractionType.call => messages.relationshipPostCallAskCall(name),
      _ => messages.relationshipPostCallAskMessage(name),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomGap),
      child: _offer(context, pending: pending, title: title, minutes: minutes),
    );
  }

  Widget _offer(
    BuildContext context, {
    required PendingInteraction pending,
    required String title,
    required int minutes,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = tokens.colors.interactive.enabled;
    return Container(
      key: const ValueKey('person-post-call-offer'),
      decoration: BoxDecoration(
        color: PostInteractionPrompt.washColor(tokens),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(
          color: accent.withValues(alpha: SurfaceAlphas.washChip),
        ),
      ),
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: tokens.spacing.step8,
                height: tokens.spacing.step8,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: SurfaceAlphas.washChip),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  checkInInteractionIcon(pending.interactionType),
                  size: IconSizes.m,
                  color: accent,
                ),
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    Text(
                      messages.relationshipPostCallMeta(
                        relationshipTimeLabelOf(context, pending.startedAt),
                        minutes,
                      ),
                      key: const ValueKey('person-post-call-meta'),
                      style: relationshipTimestampStyle(
                        tokens,
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.cardItemSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: tokens.spacing.step2,
            children: [
              DesignSystemButton(
                label: messages.relationshipPostCallDismiss,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: _busy ? null : () => unawaited(_dismiss()),
              ),
              // Secondary: the page's bar already carries the one filled
              // *Log check-in*, which opens this same prefilled composer.
              DesignSystemButton(
                key: const ValueKey('person-post-call-yes'),
                label: messages.relationshipPostCallYes,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: _busy ? null : () => unawaited(_logCheckIn()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
