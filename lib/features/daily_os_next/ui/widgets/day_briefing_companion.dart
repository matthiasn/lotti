import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_briefing.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/design_system/theme/sizing_tokens.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/features/tts/ui/tts_model_download_prompt.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// The companion in the Day header: tap her and she briefs the day.
///
/// The words are Daily OS's ([composeDayBriefing], from the plan alone, with
/// no model call), written as of the tap; she only speaks them. A tap while
/// she is preparing or speaking stops her; a tap while anything else is
/// speaking stops that and briefs instead. She is shown only while
/// `enable_companion` and the read-aloud flag are both on and the device has
/// a voice; otherwise this takes no room.
class DayBriefingCompanion extends ConsumerWidget {
  const DayBriefingCompanion({
    required this.draft,
    required this.hasPlan,
    super.key,
  });

  final DraftPlan draft;
  final bool hasPlan;

  /// The utterance id of [day]'s briefing: one per day, so stepping to
  /// another day never animates her for the last day's words.
  static String sourceIdFor(DateTime day) =>
      'day-briefing:${DateFormat('yyyy-MM-dd').format(day)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companionEnabled =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
    final ttsEnabled =
        ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ?? false;
    final engineSupported = ref.watch(ttsEngineProvider).isSupported;
    if (!companionEnabled || !ttsEnabled || !engineSupported) {
      return const SizedBox.shrink();
    }

    final sourceId = sourceIdFor(draft.dayDate);
    final active = ref.watch(
      ttsPlaybackControllerProvider.select((s) => s.isActiveFor(sourceId)),
    );
    final notifier = ref.read(ttsPlaybackControllerProvider.notifier);
    final messages = context.messages;

    listenForPlaybackFailure(ref, context, sourceId);
    final label = active
        ? messages.dailyOsNextBriefingStopTooltip
        : messages.dailyOsNextBriefingPlayTooltip;

    // The voice speaks one utterance at a time and ignores `speak` while
    // another is preparing or playing — another day's briefing, or a task
    // summary. A tap on her takes the voice over: whatever is speaking stops
    // first. The words are written before that wait, as of the tap.
    Future<void> brief() async {
      final text = composeDayBriefing(
        messages,
        DayBriefing.of(draft: draft, hasPlan: hasPlan, now: clock.now()),
        (moment) => formatClock(context, moment),
      );
      if (ref.read(ttsPlaybackControllerProvider).isBusy) {
        await notifier.stop();
      }
      if (!context.mounted) return;
      await notifier.speak(
        sourceId: sourceId,
        text: text,
        confirmModelDownload: (model) =>
            confirmTtsModelDownload(context, model),
      );
    }

    // Nothing waits on the voice: speak and stop settle their own failures
    // in the playback state, which the toast above reads, so their futures
    // are dropped on purpose.
    void onTap() {
      if (active) {
        notifier.stop(sourceId: sourceId).ignore();
        return;
      }
      brief().ignore();
    }

    return Tooltip(
      message: label,
      // The tooltip names her for screen readers; a label here as well would
      // be read twice.
      child: Semantics(
        button: true,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: ControlSizes.avatar / 2,
          child: SizedBox.square(
            dimension: ControlSizes.avatar,
            child: CompanionSpeaker(
              key: const ValueKey('dayBriefingCompanion'),
              sourceId: sourceId,
              framing: CompanionFraming.bust,
            ),
          ),
        ),
      ),
    );
  }
}

/// The spoken briefing for [briefing] in [messages]' language: how many
/// blocks are planned, what comes next (or that nothing is left today), the
/// longest block, and the time still free. Without a plan, only the
/// invitation to check in. [clockLabel] spells a time of day.
String composeDayBriefing(
  AppLocalizations messages,
  DayBriefing briefing,
  String Function(DateTime moment) clockLabel,
) {
  if (!briefing.hasPlan) return messages.dailyOsNextBriefingNoPlan;
  final next = briefing.next;
  final longest = briefing.longest;
  return [
    messages.dailyOsNextBriefingBlockCount(briefing.blockCount),
    if (next != null)
      messages.dailyOsNextBriefingNext(clockLabel(next.start), next.title)
    else if (briefing.nothingLeftToday)
      messages.dailyOsNextBriefingNothingLeft,
    if (longest != null)
      messages.dailyOsNextBriefingLongest(
        longest.title,
        _duration(messages, longest.duration.inMinutes),
      ),
    if (briefing.freeMinutes > 0)
      messages.dailyOsNextBriefingFree(
        _duration(messages, briefing.freeMinutes),
      )
    else
      messages.dailyOsNextBriefingFullyBooked,
  ].join(' ');
}

/// [minutes] as words to be spoken: "45 minutes", "2 hours", "1 hour and 30
/// minutes".
String _duration(AppLocalizations messages, int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return messages.dailyOsNextBriefingMinutes(rest);
  if (rest == 0) return messages.dailyOsNextBriefingHours(hours);
  return messages.dailyOsNextBriefingHoursAndMinutes(
    messages.dailyOsNextBriefingHours(hours),
    messages.dailyOsNextBriefingMinutes(rest),
  );
}
