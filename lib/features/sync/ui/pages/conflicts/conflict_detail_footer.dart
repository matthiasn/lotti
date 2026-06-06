part of 'conflict_detail_route.dart';

class _ConflictFooter extends StatelessWidget {
  const _ConflictFooter({
    required this.selected,
    required this.isStacked,
    required this.applyEnabled,
    required this.onApply,
    required this.onCancel,
    required this.onEditMerge,
  });

  final _Side? selected;
  final bool isStacked;
  final bool applyEnabled;
  final VoidCallback onApply;
  final VoidCallback onCancel;
  final VoidCallback onEditMerge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final helperColor = switch (selected) {
      _Side.local => colors.conflict.local.color,
      _Side.remote => colors.conflict.remote.color,
      null => colors.text.lowEmphasis,
    };
    final helperText = switch (selected) {
      _Side.local => messages.conflictFooterHelperLocalSelected,
      _Side.remote => messages.conflictFooterHelperRemoteSelected,
      null => messages.conflictFooterHelperPickASide,
    };
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Left slot is `Expanded` on both layouts so the buttons
              // own their intrinsic widths on the right and the helper
              // text / Edit-and-merge link absorbs the leftover width
              // (and ellipsizes on phone-width screens).
              Expanded(
                child: isStacked
                    ? _FooterEditMergeLink(onTap: onEditMerge)
                    : Text(
                        helperText,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: helperColor,
                        ),
                      ),
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                onPressed: onCancel,
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.conflictApplyButton,
                size: DesignSystemButtonSize.large,
                onPressed: applyEnabled ? onApply : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterEditMergeLink extends StatelessWidget {
  const _FooterEditMergeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
        child: Text(
          context.messages.conflictPickerEditMerge,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}

// --- Pure helpers (no Flutter context) -------------------------------------

String _firstLine(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  if (text != null && text.isNotEmpty) return text.split('\n').first;
  return entity.runtimeType.toString();
}

int _wordCount(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  if (text == null || text.isEmpty) return 0;
  return text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;
}

Duration? _audioDuration(JournalEntity entity) {
  return switch (entity) {
    JournalAudio(:final data) => data.duration,
    _ => null,
  };
}

int _maxCounter(VectorClock? clock) {
  if (clock == null || clock.vclock.isEmpty) return 0;
  return clock.vclock.values.reduce((a, b) => a > b ? a : b);
}

/// Locale-aware "when did this side last touch the entry" stamp shown
/// in the diff card header. Same-day conflicts render time-only (12h
/// or 24h depending on the locale); older conflicts get a short date
/// prefix so the user can tell e.g. yesterday's edit from today's.
String _formatHmsa(DateTime dt, String locale) {
  final now = DateTime.now();
  final isToday =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (isToday) return DateFormat.jms(locale).format(dt);
  return DateFormat.yMd(locale).add_jms().format(dt);
}

String _formatDuration(Duration duration) {
  final total = duration.inSeconds.abs();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}

String _formatTimeAgo(Duration delta, AppLocalizations messages) {
  // A future timestamp can happen on clock skew between sync peers;
  // floor at zero so we never render "0 days ago" for that case.
  final abs = delta.isNegative ? Duration.zero : delta;
  if (abs.inSeconds < 60) return messages.conflictBannerAgoJustNow;
  if (abs.inMinutes < 60) {
    return messages.conflictBannerAgoMinutes(abs.inMinutes);
  }
  if (abs.inHours < 48) {
    return messages.conflictBannerAgoHours(abs.inHours);
  }
  return messages.conflictBannerAgoDays(abs.inDays);
}

/// Maps the freezed sealed-type to a localized human label. Mirrors
/// the mapping used by the conflicts list view-model; pattern-matches
/// on the entity itself so the analyzer's `switch_on_type` lint stays
/// happy and a new entity type triggers a missing-case warning.
String _entityTypeLabel(JournalEntity entity, AppLocalizations messages) {
  return switch (entity) {
    Task() => messages.entryTypeLabelTask,
    JournalEntry() => messages.entryTypeLabelJournalEntry,
    JournalEvent() => messages.entryTypeLabelJournalEvent,
    JournalAudio() => messages.entryTypeLabelJournalAudio,
    JournalImage() => messages.entryTypeLabelJournalImage,
    MeasurementEntry() => messages.entryTypeLabelMeasurementEntry,
    SurveyEntry() => messages.entryTypeLabelSurveyEntry,
    WorkoutEntry() => messages.entryTypeLabelWorkoutEntry,
    HabitCompletionEntry() => messages.entryTypeLabelHabitCompletionEntry,
    QuantitativeEntry() => messages.entryTypeLabelQuantitativeEntry,
    Checklist() => messages.entryTypeLabelChecklist,
    ChecklistItem() => messages.entryTypeLabelChecklistItem,
    _ => entity.runtimeType.toString(),
  };
}

/// Walks a fixed set of metadata fields and returns a list of
/// localized labels for the ones that differ between the two sides.
/// "Title" is always added when titles differ — it's what the inline
/// diff in the cards is showing — so the banner subline reinforces it.
List<String> _differingFieldLabels(
  JournalEntity local,
  JournalEntity remote,
  AppLocalizations messages,
) {
  final fields = <String>[];
  if (_firstLine(local) != _firstLine(remote)) {
    fields.add(messages.conflictFieldTitle);
  }
  if (_wordCount(local) != _wordCount(remote)) {
    fields.add(messages.conflictFieldWordCount);
  }
  if (_audioDuration(local) != _audioDuration(remote)) {
    fields.add(messages.conflictFieldDuration);
  }
  if (local.meta.categoryId != remote.meta.categoryId) {
    fields.add(messages.conflictFieldCategory);
  }
  return fields;
}
