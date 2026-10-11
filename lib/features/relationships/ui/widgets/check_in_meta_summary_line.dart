import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_meta.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/check_in_interaction_icon.dart';
import 'package:material_ui/material_ui.dart';

/// A saved check-in's facts under its title, in the task header's grammar
/// ([TaskMetaSummaryLine]): one wrapping lane of square-cornered read-outs —
/// how you connected, when, for how long, how it felt — each opening its own
/// picker on a tap, then what it was about as one tag, as a task folds its
/// labels into one. A value not set yet is an offer instead: the muted,
/// fully-rounded pill a task uses for *Set category*. The lane ends where a
/// task's ends, on its one lever — here *Edit check-in*, the sheet that
/// holds everything no read-out edits.
///
/// The composer keeps `CheckInContextChips`: there the chips are the form's
/// levers, and the round pill with its chevron is the lever grammar.
class CheckInMetaSummaryLine extends StatelessWidget {
  const CheckInMetaSummaryLine({
    required this.type,
    required this.startedLabel,
    required this.duration,
    required this.onPickType,
    required this.onPickStart,
    required this.onPickDuration,
    required this.onPickSentiment,
    required this.onEdit,
    this.sentiment,
    this.topics = const [],
    this.enabled = true,
    this.leverLabel,
    this.leverIcon = LottiIcons.edit,
    this.leverKey = const ValueKey('check-in-detail-edit'),
    this.leverExpanded,
    super.key,
  });

  final CheckInInteractionType type;

  /// The day and the time, as the started chip says it.
  final String startedLabel;

  /// How long it lasted; zero or less is "not set".
  final Duration duration;
  final CheckInSentiment? sentiment;
  final List<String> topics;
  final VoidCallback onPickType;
  final VoidCallback onPickStart;
  final VoidCallback onPickDuration;
  final VoidCallback onPickSentiment;

  /// Opens the edit sheet — from the closing lever and the topics tag.
  final VoidCallback onEdit;

  /// False while a take is live: the facts stay readable, fade as one lane
  /// — the recorder's own inert treatment — and take no tap.
  final bool enabled;

  /// The closing lever's words — *Edit check-in* on the saved page, where it
  /// opens the edit sheet; the form names its details fold instead.
  final String? leverLabel;
  final IconData leverIcon;
  final Key leverKey;

  /// Whether what the lever folds is open, where it is a disclosure (the
  /// form's details) — told to a screen reader, which cannot see the
  /// chevron turn; null where the lever opens a sheet.
  final bool? leverExpanded;

  /// How many topics spell out before the rest fold into "+N" — the task
  /// labels tag's own count.
  static const int maxNamedTopics = TaskMetaSummaryLine.maxNamedLabels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final typeLabel = checkInInteractionLabel(context, type);
    final hasDuration = duration > Duration.zero;
    final durationLabel = hasDuration
        ? checkInDurationLabel(context, duration)
        : messages.checkInDurationChip;
    VoidCallback? live(VoidCallback onTap) => enabled ? onTap : null;

    // The task lane's own rhythm: tags step2 apart, tighter than their own
    // step3 inset, so the lane reads as one cluster. No run gap of its own:
    // each tag's full touch target already sets wrapped rows apart.
    final lane = Wrap(
      key: const ValueKey('check-in-meta-line'),
      spacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Fact(
          key: const ValueKey('check-in-type'),
          semanticsLabel: messages.checkInTypeChipSemantics(typeLabel),
          icon: checkInInteractionIcon(type),
          label: typeLabel,
          emphasised: true,
          onTap: live(onPickType),
        ),
        _Fact(
          key: const ValueKey('check-in-started'),
          semanticsLabel: messages.checkInTimeChipSemantics(startedLabel),
          icon: LottiIcons.today,
          label: startedLabel,
          emphasised: true,
          onTap: live(onPickStart),
        ),
        if (hasDuration)
          _Fact(
            key: const ValueKey('check-in-duration'),
            semanticsLabel: messages.checkInDurationChipSemantics(
              durationLabel,
            ),
            icon: LottiIcons.timer,
            label: durationLabel,
            emphasised: true,
            onTap: live(onPickDuration),
          )
        else
          _Offer(
            key: const ValueKey('check-in-duration'),
            semanticsLabel: messages.checkInDurationChipSemantics(
              durationLabel,
            ),
            icon: LottiIcons.timer,
            label: durationLabel,
            onTap: live(onPickDuration),
          ),
        if (sentiment case final sentiment?)
          _SentimentFact(
            sentiment: sentiment,
            onTap: live(onPickSentiment),
          )
        else
          _Offer(
            key: const ValueKey('check-in-sentiment-chip'),
            semanticsLabel: messages.checkInSentimentLabel,
            icon: LottiIcons.moodNeutral,
            label: messages.checkInSentimentLabel,
            onTap: live(onPickSentiment),
          ),
        // What it was about, folded into one tag the way a task folds its
        // labels: a kind of its own beside the facts, and a door to the
        // sheet where topics change rather than a row of tags that look
        // tappable and are not.
        if (topics.isNotEmpty)
          _Fact(
            key: const ValueKey('check-in-topics-tag'),
            semanticsLabel:
                '${messages.checkInTopicsLabel}: ${topics.join(', ')}',
            icon: LottiIcons.label,
            label: _topicsLabel(context),
            onTap: live(onEdit),
          ),
        // The lane's one lever, where a task's *Details* sits: the dashed,
        // fully-rounded pill, so a fact and a control never look alike.
        _Offer(
          key: leverKey,
          semanticsLabel: leverLabel ?? messages.checkInEditTitle,
          icon: leverIcon,
          label: leverLabel ?? messages.checkInEditTitle,
          onTap: live(onEdit),
          expanded: leverExpanded,
        ),
      ],
    );
    // Held, the whole lane fades by the low ink's own alpha, as the
    // recorder's inert controls do: a shade change on each tag's text was
    // too faint to read as "not now".
    return AnimatedOpacity(
      key: const ValueKey('check-in-meta-line-hold'),
      opacity: enabled ? 1 : tokens.colors.text.lowEmphasis.a,
      duration: MotionDurations.short4,
      child: lane,
    );
  }

  String _topicsLabel(BuildContext context) {
    final named = topics.take(maxNamedTopics).join(', ');
    final more = topics.length - maxNamedTopics;
    return more > 0
        ? '$named ${context.messages.taskLabelsMoreCount(more)}'
        : named;
  }
}

/// One set fact: the task header's filled, bordered tag, its glyph at the
/// lane's glyph size, a tap opening the fact's picker.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.semanticsLabel,
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasised = false,
    super.key,
  });

  final String semanticsLabel;
  final IconData icon;
  final String label;

  /// Null while held.
  final VoidCallback? onTap;

  /// High-emphasis label — the facts a reader opens a check-in to see, as
  /// a task's status, due date and time are; the topics sit at medium.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final text = context.designTokens.colors.text;
    return _Tappable(
      semanticsLabel: semanticsLabel,
      onTap: onTap,
      child: DsPill(
        variant: DsPillVariant.filled,
        shape: DsPillShape.tag,
        bordered: true,
        label: label,
        labelColor: emphasised ? text.highEmphasis : text.mediumEmphasis,
        leading: Icon(
          icon,
          size: kTaskChipGlyphSize,
          color: text.mediumEmphasis,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// How it felt: the tinted tag in the sentiment's own colour, as the person
/// page's check-in row paints it, led — as a task's tinted status is — by
/// a glyph in that colour, so the feeling reads by more than its tint and
/// the face says what the word rates.
class _SentimentFact extends StatelessWidget {
  const _SentimentFact({required this.sentiment, required this.onTap});

  final CheckInSentiment sentiment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = checkInSentimentLabel(context, sentiment);
    final accent = sentimentColor(tokens, sentiment);
    final glyph = sentimentGlyph(sentiment);
    return _Tappable(
      key: const ValueKey('check-in-sentiment-chip'),
      semanticsLabel: '${context.messages.checkInMoreCaptionFeeling}: $label',
      onTap: onTap,
      child: DsPill(
        variant: DsPillVariant.tinted,
        shape: DsPillShape.tag,
        color: accent,
        // The accent is the tint and the glyph; as text on its own tint it
        // falls short of contrast, so the label keeps the high ink — the
        // task status tag's rule.
        labelColor: tokens.colors.text.highEmphasis,
        label: label,
        leading: Icon(glyph, size: kTaskChipGlyphSize, color: accent),
        onTap: onTap,
      ),
    );
  }
}

/// An offer or a lever: the task lane's muted, dashed, fully-rounded pill.
class _Offer extends StatelessWidget {
  const _Offer({
    required this.semanticsLabel,
    required this.icon,
    required this.label,
    required this.onTap,
    this.expanded,
    super.key,
  });

  final String semanticsLabel;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Whether what this offer folds is open; null where it is no
  /// disclosure.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final ink = context.designTokens.colors.text.mediumEmphasis;
    return _Tappable(
      semanticsLabel: semanticsLabel,
      onTap: onTap,
      expanded: expanded,
      child: DsPill(
        variant: DsPillVariant.muted,
        label: label,
        labelColor: ink,
        leading: Icon(icon, size: kTaskChipGlyphSize, color: ink),
        onTap: onTap,
      ),
    );
  }
}

/// Announces a read-out as the one button it is, by what it holds, and
/// gives its 28px pill the full touch target around it
/// (`kMinInteractiveDimension`), as `DsChoicePills` does: the pill's own
/// ink covers its face, this catches the rest of the target above and
/// below it.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
    this.expanded,
    super.key,
  });

  final String semanticsLabel;
  final VoidCallback? onTap;
  final Widget child;
  final bool? expanded;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    expanded: expanded,
    enabled: onTap != null,
    label: semanticsLabel,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: kMinInteractiveDimension,
        ),
        child: Center(widthFactor: 1, child: child),
      ),
    ),
  );
}
