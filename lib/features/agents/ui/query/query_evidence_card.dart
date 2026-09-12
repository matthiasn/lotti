import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A saved, verified passage. Current source metadata controls access and
/// historical-status labels; the stored text itself is never silently replaced.
class QueryEvidenceCard extends ConsumerStatefulWidget {
  const QueryEvidenceCard({
    required this.evidence,
    required this.number,
    required this.access,
    required this.onOpen,
    this.audioControls,
    super.key,
  });
  final QueryEvidence evidence;
  final int number;
  final QueryAccessSnapshot access;
  final ValueChanged<String> onOpen;
  final Widget? audioControls;

  @override
  ConsumerState<QueryEvidenceCard> createState() => _QueryEvidenceCardState();
}

class _QueryEvidenceCardState extends ConsumerState<QueryEvidenceCard> {
  bool _expanded = false;
  bool _surrounding = false;
  bool _restored = false;
  bool _copied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: ('query-evidence', widget.key));
    if (saved is (bool, bool)) {
      _expanded = saved.$1;
      _surrounding = saved.$2;
    }
  }

  void _toggle({bool surrounding = false}) {
    setState(() {
      if (surrounding) {
        _surrounding = !_surrounding;
      } else {
        _expanded = !_expanded;
      }
    });
    PageStorage.maybeOf(context)?.writeState(
      context,
      (_expanded, _surrounding),
      identifier: ('query-evidence', widget.key),
    );
  }

  Future<void> _copy() async {
    final evidence = widget.evidence;
    final current = await ref.read(querySourceAccessProvider).load([
      evidence.source.id,
    ]);
    if (!mounted || !current.allowsReference(evidence.source)) return;
    await Clipboard.setData(ClipboardData(text: evidence.quote));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _open() async {
    final source = widget.evidence.source;
    final current = await ref.read(querySourceAccessProvider).load([source.id]);
    final entry = current.entries[source.id];
    if (!mounted || entry == null || !current.allowsEntry(entry)) return;
    widget.onOpen(source.id);
  }

  @override
  Widget build(BuildContext context) {
    final evidence = widget.evidence;
    if (!widget.access.allowsReference(evidence.source) ||
        !evidence.hasValidPassage) {
      return const SizedBox.shrink();
    }
    final current = widget.access.entries[evidence.source.id]!;
    final deleted = current.meta.deletedAt != null;
    final moved = current.meta.categoryId != evidence.source.categoryId;
    final changed =
        !deleted &&
        QuerySourceDocument.fromEntry(current)?.fingerprint !=
            evidence.fingerprint;
    final tokens = context.designTokens;
    final messages = context.messages;
    final body = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final transcript = evidence.textVersion.startsWith('transcript:');
    return Container(
      margin: EdgeInsets.only(top: tokens.spacing.step3),
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: '[${widget.number}]',
                child: DsPill(
                  variant: DsPillVariant.tinted,
                  color: tokens.colors.interactive.enabled,
                  label: '${widget.number}',
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: evidence.label,
                        children: [
                          TextSpan(
                            text:
                                ' · ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(evidence.sourceDate)}',
                            style: caption,
                          ),
                        ],
                      ),
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    if (evidence.kind == QuerySourceKind.recording)
                      Text(
                        transcript
                            ? '${messages.queryRecordings} · ${evidence.textVersion.split(':').skip(1).take(2).join(' / ')}'
                            : messages.queryRecordings,
                        style: caption,
                      ),
                    if (evidence.affiliations.isNotEmpty)
                      Text(evidence.affiliations.join(' · '), style: caption),
                  ],
                ),
              ),
            ],
          ),
          if (evidence.outsideHome)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step3),
              child: Wrap(
                spacing: tokens.spacing.step3,
                runSpacing: tokens.spacing.step2,
                children: [
                  DesignSystemBadge.outlined(
                    label: messages.queryOtherProject,
                    tone: DesignSystemBadgeTone.neutral,
                  ),
                  if (evidence.relevance.isNotEmpty)
                    Text(evidence.relevance, style: caption),
                ],
              ),
            ),
          for (final status in [
            if (deleted) messages.querySourceDeleted,
            if (changed) messages.querySourceChanged,
            if (moved) messages.querySourceMoved,
          ])
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step2),
              child: Text(
                status,
                style: caption.copyWith(color: tokens.colors.alert.warning.ink),
              ),
            ),
          if (deleted || changed || moved)
            Text(messages.querySavedQuote, style: caption),
          if (evidence.summary.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step3),
              child: Text(evidence.summary, style: body),
            ),
          SizedBox(height: tokens.spacing.step2),
          if (widget.audioControls != null) widget.audioControls!,
          Semantics(
            expanded: _expanded,
            child: DesignSystemButton(
              label: _expanded
                  ? messages.queryHideExactText
                  : messages.queryExactText,
              leadingIcon: _expanded ? LottiIcons.collapse : LottiIcons.expand,
              onPressed: _toggle,
              variant: DesignSystemButtonVariant.tertiary,
              alignsLabelToLeadingEdge: true,
            ),
          ),
          if (_expanded) ...[
            SizedBox(height: tokens.spacing.step3),
            Text(messages.queryExactStoredText, style: caption),
            if (transcript)
              Text(messages.queryMachineTranscript, style: caption),
            SizedBox(height: tokens.spacing.step3),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(tokens.spacing.step4),
              decoration: BoxDecoration(
                color: tokens.colors.background.level02,
                border: BorderDirectional(
                  start: BorderSide(
                    color: tokens.colors.interactive.enabled,
                    width: BorderWidths.emphasis,
                  ),
                ),
                borderRadius: BorderRadius.circular(tokens.radii.m),
              ),
              child: SelectableText.rich(
                TextSpan(
                  style: body,
                  children: [
                    if (_surrounding)
                      TextSpan(
                        text: evidence.sourceText.substring(0, evidence.start),
                        style: body.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    if (!_surrounding && evidence.start > 0)
                      TextSpan(
                        text: '${messages.queryEarlierTextOmitted}\n',
                        style: caption,
                      ),
                    TextSpan(
                      text: evidence.quote,
                      style: body.copyWith(
                        backgroundColor: tokens.colors.surface.selected,
                      ),
                    ),
                    if (!_surrounding &&
                        evidence.end < evidence.sourceText.length)
                      TextSpan(
                        text: '\n${messages.queryLaterTextOmitted}',
                        style: caption,
                      ),
                    if (_surrounding)
                      TextSpan(
                        text: evidence.sourceText.substring(evidence.end),
                        style: body.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step2),
            Wrap(
              spacing: tokens.spacing.step2,
              runSpacing: tokens.spacing.step2,
              children: [
                if (evidence.start > 0 ||
                    evidence.end < evidence.sourceText.length)
                  DesignSystemButton(
                    label: _surrounding
                        ? messages.queryHideSurrounding
                        : messages.querySurroundingText,
                    onPressed: () => _toggle(surrounding: true),
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                  ),
                if (!deleted)
                  DesignSystemButton(
                    label: messages.queryOpenEntry,
                    leadingIcon: LottiIcons.openExternal,
                    onPressed: _open,
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                  ),
                DesignSystemButton(
                  label: _copied
                      ? messages.queryCopied
                      : messages.queryCopyQuote,
                  leadingIcon: LottiIcons.copy,
                  onPressed: _copy,
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.dense,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
