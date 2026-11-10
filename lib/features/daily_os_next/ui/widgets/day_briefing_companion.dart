import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_briefing.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
import 'package:lotti/features/design_system/theme/sizing_tokens.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
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
/// no model call), written as of the tap; she only speaks them. What a tap
/// does — and when she is shown at all — is [DayBriefingVoice]; while she
/// cannot speak this takes no room.
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
    final voice = DayBriefingVoice.watch(
      context,
      ref,
      draft: draft,
      hasPlan: hasPlan,
    );
    if (voice == null) return const SizedBox.shrink();

    // Her failure toast is registered here, once: the briefing strip shares
    // her voice but is only tappable while she is shown.
    listenForPlaybackFailure(ref, context, sourceIdFor(draft.dayDate));
    final messages = context.messages;
    final label = voice.active
        ? messages.dailyOsNextBriefingStopTooltip
        : messages.dailyOsNextBriefingPlayTooltip;

    return Tooltip(
      message: label,
      // The tooltip names her for screen readers; a label here as well would
      // be read twice.
      child: Semantics(
        button: true,
        excludeSemantics: true,
        child: InkResponse(
          onTap: voice.toggle,
          radius: ControlSizes.avatar / 2,
          child: SizedBox.square(
            dimension: ControlSizes.avatar,
            child: CompanionSpeaker(
              key: const ValueKey('dayBriefingCompanion'),
              sourceId: sourceIdFor(draft.dayDate),
              framing: CompanionFraming.bust,
            ),
          ),
        ),
      ),
    );
  }
}

/// The companion's briefing voice for one day: what a tap on her — or on
/// the day's briefing strip — does.
///
/// [watch] returns null while she cannot speak (`enable_companion` or the
/// read-aloud flag is off, or there is no voice), and then nothing offers the
/// tap. Otherwise [toggle] stops her while she is preparing or speaking this
/// day's briefing ([active]), and else briefs the day: whatever else is
/// speaking stops first, and the words are written as of the tap.
///
/// Her voice is the Daily OS planner's: the read-aloud model of the profile
/// its setup resolves to, in the app's language, else the on-device voice.
/// The words go to that cloud voice only on a tap.
@immutable
class DayBriefingVoice {
  const DayBriefingVoice._({required this.active, required this.toggle});

  /// Whether she is preparing or speaking this day's briefing.
  final bool active;

  /// Stops her when [active]; otherwise briefs the day.
  final VoidCallback toggle;

  static DayBriefingVoice? watch(
    BuildContext context,
    WidgetRef ref, {
    required DraftPlan draft,
    required bool hasPlan,
  }) {
    final companionEnabled =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
    final ttsEnabled =
        ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ?? false;
    final cloudRoute = TtsCloudRoute.fromProfile(
      ref
          .watch(agentResolvedSetupProvider(dailyOsPlannerAgentId))
          .value
          ?.profile,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final hasVoice =
        cloudRoute != null || ref.watch(ttsEngineProvider).isSupported;
    if (!companionEnabled || !ttsEnabled || !hasVoice) return null;

    final sourceId = DayBriefingCompanion.sourceIdFor(draft.dayDate);
    // The next block's task name, watched now so the spoken briefing names
    // it as the strip and the agenda do.
    final upcoming = DayBriefing.of(
      draft: draft,
      hasPlan: hasPlan,
      now: clock.now(),
    ).next;
    final upcomingTitle = watchLiveTaskMetadata(ref, upcoming?.taskId).title;
    final active = ref.watch(
      ttsPlaybackControllerProvider.select((s) => s.isActiveFor(sourceId)),
    );
    final notifier = ref.read(ttsPlaybackControllerProvider.notifier);

    // The voice speaks one utterance at a time and ignores `speak` while
    // another is preparing or playing — another day's briefing, or a task
    // summary. A tap takes the voice over: whatever is speaking stops first.
    Future<void> brief() async {
      final briefing = DayBriefing.of(
        draft: draft,
        hasPlan: hasPlan,
        now: clock.now(),
      );
      // The block watched at the last build is still next unless one has
      // started since; then the newly-next one's live title is read now, so
      // she never names it by a title it has since outgrown.
      final next = briefing.next;
      final nextTitle = next?.id == upcoming?.id
          ? upcomingTitle
          : await readLiveTaskTitle(ref, next?.taskId);
      if (!context.mounted) return;
      final text = composeDayBriefing(
        context.messages,
        briefing,
        (moment) => formatClock(context, moment),
        nextTitle: nextTitle,
      );
      if (ref.read(ttsPlaybackControllerProvider).isBusy) {
        await notifier.stop();
      }
      if (!context.mounted) return;
      await notifier.speak(
        sourceId: sourceId,
        text: text,
        cloudRoute: cloudRoute,
        confirmModelDownload: (model) =>
            confirmTtsModelDownload(context, model),
      );
    }

    // Nothing waits on the voice: speak and stop settle their own failures
    // in the playback state, which the companion's toast reads, so their
    // futures are dropped on purpose.
    return DayBriefingVoice._(
      active: active,
      toggle: () {
        if (active) {
          notifier.stop(sourceId: sourceId).ignore();
          return;
        }
        brief().ignore();
      },
    );
  }
}

/// The briefing's opening, written: how many blocks are planned and what
/// comes next (or that nothing is left today). Without a plan, the
/// invitation to check in. The briefing strip shows this, and the spoken
/// [composeDayBriefing] begins with it, so the two never disagree.
/// [nextTitle], when given, names the next block — its task's live name, the
/// one its agenda row leads with — in place of the block's own title.
String composeDayHeadline(
  AppLocalizations messages,
  DayBriefing briefing,
  String Function(DateTime moment) clockLabel, {
  String? nextTitle,
}) {
  if (!briefing.hasPlan) return messages.dailyOsNextBriefingNoPlan;
  final next = briefing.next;
  return [
    messages.dailyOsNextBriefingBlockCount(briefing.blockCount),
    if (next != null)
      _withoutDoubledStop(
        messages.dailyOsNextBriefingNext(
          clockLabel(next.start),
          nextTitle ?? next.title,
        ),
      )
    else if (briefing.nothingLeftToday)
      messages.dailyOsNextBriefingNothingLeft,
  ].join(' ');
}

/// [sentence] without the full stop a template adds after a title that
/// already ends its own sentence: "…: Is a penguin a passenger?" rather than
/// "…passenger?.".
String _withoutDoubledStop(String sentence) => sentence.replaceFirstMapped(
  RegExp(r'([?!.…])\.$'),
  (match) => match.group(1)!,
);

/// The spoken briefing for [briefing] in [messages]' language: how many
/// blocks are planned, what comes next (or that nothing is left today), the
/// longest block, and the time still free. Without a plan, only the
/// invitation to check in. [clockLabel] spells a time of day; [nextTitle]
/// is as in [composeDayHeadline].
String composeDayBriefing(
  AppLocalizations messages,
  DayBriefing briefing,
  String Function(DateTime moment) clockLabel, {
  String? nextTitle,
}) {
  final headline = composeDayHeadline(
    messages,
    briefing,
    clockLabel,
    nextTitle: nextTitle,
  );
  if (!briefing.hasPlan) return headline;
  final longest = briefing.longest;
  return [
    headline,
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
