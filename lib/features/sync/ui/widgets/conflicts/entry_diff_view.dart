import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Renders an [EntryDiff] as a scannable field-by-field list — the core of the
/// "never a blind choice" guarantee. Each differing field shows both sides
/// ("this device" / "from sync"); text fields get inline word-level
/// highlighting, scalars get localized values, and the [EntryField.other]
/// catch-all is surfaced explicitly so nothing is hidden.
class EntryDiffView extends StatelessWidget {
  const EntryDiffView({required this.diff, super.key});

  final EntryDiff diff;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in diff.fields) ...[
          _FieldDiffRow(field: field),
          SizedBox(height: tokens.spacing.step3),
        ],
        if (diff.identicalFieldCount > 0)
          Text(
            messages.conflictDiffUnchanged(diff.identicalFieldCount),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
      ],
    );
  }
}

class _FieldDiffRow extends StatelessWidget {
  const _FieldDiffRow({required this.field});

  final FieldDiff field;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.step3),
      decoration: BoxDecoration(
        color: colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflictFieldLabel(field.field, messages),
            style: tokens.typography.styles.others.overline.copyWith(
              color: colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          if (field.field == EntryField.other)
            Text(
              messages.conflictFieldOtherDescription,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: colors.text.mediumEmphasis,
              ),
            )
          else ...[
            _SideValue(
              side: messages.conflictSideThisDevice,
              accent: colors.conflict.local.color,
              child: _valueContent(context, ConflictWhich.local),
            ),
            SizedBox(height: tokens.spacing.step2),
            _SideValue(
              side: messages.conflictSideFromSync,
              accent: colors.conflict.remote.color,
              child: _valueContent(context, ConflictWhich.remote),
            ),
          ],
        ],
      ),
    );
  }

  Widget _valueContent(BuildContext context, ConflictWhich which) {
    final wordDiff = field.wordDiff;
    if (_isTextField(field.field) && wordDiff != null) {
      return _WordDiffText(
        segments: which == ConflictWhich.local
            ? wordDiff.local
            : wordDiff.remote,
      );
    }
    final raw = which == ConflictWhich.local
        ? field.localValue
        : field.remoteValue;
    return Text(
      _displayValue(context, field.field, raw),
      style: context.designTokens.typography.styles.body.bodyMedium.copyWith(
        color: context.designTokens.colors.text.highEmphasis,
      ),
    );
  }
}

/// Which side of the conflict a value belongs to (UI-only; the domain enum is
/// `ConflictSide`, kept separate so this widget has no dependency on it).
enum ConflictWhich { local, remote }

class _SideValue extends StatelessWidget {
  const _SideValue({
    required this.side,
    required this.accent,
    required this.child,
  });

  final String side;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: tokens.spacing.step1,
          height: tokens.spacing.step4,
          margin: EdgeInsets.only(top: tokens.spacing.step1 / 2),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(tokens.radii.xs),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                side,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: accent,
                ),
              ),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// Word-level diff renderer that mirrors the conflict cards' inline pills,
/// reusing the `colors.diff.*` token group.
class _WordDiffText extends StatelessWidget {
  const _WordDiffText({required this.segments});

  final List<TitleDiffSegment> segments;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final base = tokens.typography.styles.body.bodyMedium.copyWith(
      color: colors.text.highEmphasis,
    );
    if (segments.isEmpty) {
      return Text(context.messages.conflictValueAbsent, style: base);
    }
    final spans = <InlineSpan>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' '));
      spans.add(_span(segments[i], tokens, base));
    }
    return Text.rich(TextSpan(children: spans), style: base);
  }

  InlineSpan _span(TitleDiffSegment seg, DsTokens tokens, TextStyle base) {
    final colors = tokens.colors;
    switch (seg.kind) {
      case TitleDiffKind.common:
        return TextSpan(text: seg.text);
      case TitleDiffKind.added:
        return _pill(
          seg.text,
          colors.diff.added.surface,
          colors.diff.added.color,
          tokens,
          base,
        );
      case TitleDiffKind.removed:
        return _pill(
          seg.text,
          colors.diff.removed.surface,
          colors.diff.removed.color,
          tokens,
          base,
          strikethrough: true,
        );
      case TitleDiffKind.replaced:
        return _pill(
          seg.text,
          colors.diff.replaced.surface,
          colors.diff.replaced.color,
          tokens,
          base,
        );
    }
  }

  InlineSpan _pill(
    String text,
    Color background,
    Color foreground,
    DsTokens tokens,
    TextStyle base, {
    bool strikethrough = false,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step2,
          vertical: tokens.spacing.step1 / 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(tokens.radii.xs),
        ),
        child: Text(
          text,
          style: base.copyWith(
            color: foreground,
            decoration: strikethrough ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

bool _isTextField(EntryField field) =>
    field == EntryField.title || field == EntryField.body;

/// Localized display label for a conflict field, shared by the diff view and
/// the combine toggles.
String conflictFieldLabel(EntryField field, AppLocalizations messages) {
  return switch (field) {
    EntryField.title => messages.conflictFieldTitle,
    EntryField.body => messages.conflictFieldBody,
    EntryField.category => messages.conflictFieldCategory,
    EntryField.dateFrom => messages.conflictFieldStart,
    EntryField.dateTo => messages.conflictFieldEnd,
    EntryField.starred => messages.conflictFieldStarred,
    EntryField.private => messages.conflictFieldPrivate,
    EntryField.flag => messages.conflictFieldFlag,
    EntryField.audioDuration => messages.conflictFieldDuration,
    EntryField.other => messages.conflictFieldOther,
  };
}

/// Localizes/formats the canonical value strings the diff engine emits.
String _displayValue(BuildContext context, EntryField field, String? raw) {
  final messages = context.messages;
  if (raw == null || raw.isEmpty) return messages.conflictValueAbsent;
  switch (field) {
    case EntryField.starred:
    case EntryField.private:
      return raw == 'true'
          ? messages.conflictValueYes
          : messages.conflictValueNo;
    case EntryField.flag:
      return switch (raw) {
        'import' => messages.conflictFlagImport,
        'followUpNeeded' => messages.conflictFlagFollowUp,
        _ => messages.conflictFlagNone,
      };
    case EntryField.dateFrom:
    case EntryField.dateTo:
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      final locale = Localizations.localeOf(context).toString();
      return DateFormat.yMd(locale).add_jm().format(parsed);
    case EntryField.title:
    case EntryField.body:
    case EntryField.category:
    case EntryField.audioDuration:
    case EntryField.other:
      return raw;
  }
}
