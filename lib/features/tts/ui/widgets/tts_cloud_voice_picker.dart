import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_samples.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/cloud_voice_settings_providers.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/features/tts/ui/widgets/tts_gender_filter.dart';
import 'package:lotti/features/tts/ui/widgets/tts_source_play_button.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_radio_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Source id prefix of the samples played from Speech settings.
const String cloudVoiceTestSourcePrefix = 'speech-settings-voice-';

/// The playback source of [voiceId]'s sample in [language].
String cloudVoiceSampleSourceId(String language, String voiceId) =>
    '$cloudVoiceTestSourcePrefix$language-$voiceId';

/// Speaks [language]'s sample sentence in [voiceId] on [service].
///
/// Whatever is speaking stops first: the voice keeps one utterance at a
/// time and ignores a new one while busy, so auditioning voice after voice
/// would otherwise leave the first still talking under the second's check.
Future<void> speakCloudVoiceSample(
  TtsPlaybackController controller, {
  required CloudVoiceService service,
  required String language,
  required String voiceId,
}) async {
  await controller.stop();
  await controller.speak(
    sourceId: cloudVoiceSampleSourceId(language, voiceId),
    text: cloudVoiceSample(language),
    cloudRoute: TtsCloudRoute(
      provider: service.provider,
      model: service.model,
      languageCode: language,
      voiceId: voiceId,
    ),
  );
}

/// Plays a voice's sample without picking it: a quiet speaker glyph at rest,
/// so a column of them reads as an affordance rather than a row of buttons,
/// and the full play/stop disc with its progress ring only while that sample
/// is preparing or playing.
class CloudVoicePreviewButton extends ConsumerWidget {
  const CloudVoicePreviewButton({
    required this.sourceId,
    required this.voiceName,
    required this.onPlay,
    this.quiet = false,
    super.key,
  });

  final String sourceId;

  /// Names the voice in the tooltip and to assistive technology.
  final String voiceName;
  final void Function(TtsPlaybackController controller) onPlay;

  /// The resting glyph in the low-emphasis ink, for rows that should not
  /// compete with the user's own (the languages below the seam).
  final bool quiet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(ttsPlaybackControllerProvider);
    final active =
        playback.isActiveFor(sourceId) &&
        (playback.status == TtsPlaybackStatus.synthesizing ||
            playback.status == TtsPlaybackStatus.downloadingModel ||
            playback.status == TtsPlaybackStatus.playing);
    if (active) {
      return TtsSourcePlayButton(sourceId: sourceId, onPlay: onPlay);
    }
    final tokens = context.designTokens;
    final label = context.messages.speechSettingsCloudVoiceListen(voiceName);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          radius: DsAiDiscButton.hitSize / 2,
          onTap: () => onPlay(ref.read(ttsPlaybackControllerProvider.notifier)),
          child: SizedBox.square(
            dimension: DsAiDiscButton.hitSize,
            child: Icon(
              LottiIcons.volume,
              size: IconSizes.m,
              color: quiet
                  ? tokens.colors.text.lowEmphasis
                  : tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the sheet that picks [language]'s cloud voice from [catalog].
///
/// A tap in the sheet both auditions and picks, so a sheet that closes on a
/// different voice than it opened with says so, with an Undo back to the
/// voice it opened with.
Future<void> showCloudVoicePicker(
  BuildContext context,
  WidgetRef ref, {
  required CloudVoiceService service,
  required VoxtralVoiceCatalog catalog,
  required String language,
  required String languageName,
}) async {
  final settings = ref.read(ttsSettingsControllerProvider.notifier);
  String? pick() =>
      ref.read(ttsSettingsControllerProvider).cloudVoiceByLanguage[language];
  final before = pick();
  await ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.speechSettingsCloudVoiceSheetTitle(languageName),
    padding: EdgeInsets.only(
      top: context.designTokens.spacing.step3,
      bottom: context.designTokens.spacing.step8,
    ),
    builder: (_) => CloudVoicePicker(
      service: service,
      catalog: catalog,
      language: language,
    ),
  );
  if (!context.mounted) return;
  final after = pick();
  if (after == before) return;
  final voice = catalog.resolve(
    languageCode: language,
    preferredVoiceId: after,
  );
  if (voice == null) return;
  context.showToast(
    tone: DesignSystemToastTone.success,
    title: context.messages.speechSettingsCloudVoiceChanged(
      languageName,
      voice.name,
    ),
    replaceCurrent: true,
    // Long enough to read, decide and reach the Undo.
    duration: const Duration(seconds: 8),
    action: ToastAction(
      label: context.messages.designSystemUndoLabel,
      onPressed: () => settings.setCloudVoice(language, before),
    ),
  );
}

/// The voices of one language, with a Female | Male filter once there are
/// more than [genderFilterThreshold] of both.
///
/// The default voice leads, above the filter, and the voice that was in
/// effect when the sheet opened follows it: going back to either is always
/// one visible tap, whatever was tried since. A tap on a voice picks it and
/// plays the sample in it — one gesture, stated in a line above the list —
/// and the sheet stays open; the picked voice carries the control that
/// replays or stops it.
/// Picking the language's default voice clears the choice rather than
/// pinning it, so the language keeps following the default if the catalog
/// changes.
class CloudVoicePicker extends ConsumerStatefulWidget {
  const CloudVoicePicker({
    required this.service,
    required this.catalog,
    required this.language,
    super.key,
  });

  final CloudVoiceService service;
  final VoxtralVoiceCatalog catalog;
  final String language;

  /// A list this long or shorter is read whole; longer, and splitting it by
  /// gender halves what has to be scanned.
  static const int genderFilterThreshold = 8;

  @override
  ConsumerState<CloudVoicePicker> createState() => _CloudVoicePickerState();
}

class _CloudVoicePickerState extends ConsumerState<CloudVoicePicker> {
  String? _gender;

  /// The user's own pick when the sheet opened, kept above the filter.
  late final String? _openedWith = ref
      .read(ttsSettingsControllerProvider)
      .cloudVoiceByLanguage[widget.language];

  static String? _genderOf(VoxtralVoice voice) =>
      voice.gender?.trim().toLowerCase();

  void _pick(VoxtralVoice voice, VoxtralVoice? defaultVoice) {
    ref
        .read(ttsSettingsControllerProvider.notifier)
        .setCloudVoice(
          widget.language,
          voice.id == defaultVoice?.id ? null : voice.id,
        );
    speakCloudVoiceSample(
      ref.read(ttsPlaybackControllerProvider.notifier),
      service: widget.service,
      language: widget.language,
      voiceId: voice.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final chosenId = ref.watch(
      ttsSettingsControllerProvider.select(
        (s) => s.cloudVoiceByLanguage[widget.language],
      ),
    );
    final voices = widget.catalog.forLanguage(widget.language);
    final defaultVoice = widget.catalog.resolve(languageCode: widget.language);
    final selected = widget.catalog.resolve(
      languageCode: widget.language,
      preferredVoiceId: chosenId,
    );
    final filtered =
        voices.length > CloudVoicePicker.genderFilterThreshold &&
        voices.any((v) => _genderOf(v) == 'female') &&
        voices.any((v) => _genderOf(v) == 'male');
    // Opens on the selected voice's gender, so the check mark is in view.
    final gender =
        _gender ?? (selected == null ? null : _genderOf(selected)) ?? 'female';
    final pinned = [
      ?defaultVoice,
      if (_openedWith != null && _openedWith != defaultVoice?.id)
        ?widget.catalog.byId(_openedWith),
    ];
    // A voice the API gives no female or male gender has no tab of its
    // own: it stays in the list under either, so it is always reachable.
    bool passesFilter(VoxtralVoice voice) {
      final own = _genderOf(voice);
      return !filtered || own == gender || (own != 'female' && own != 'male');
    }

    final shown = [
      for (final voice in voices)
        if (!pinned.contains(voice) && passesFilter(voice)) voice,
    ];

    Widget option(
      VoxtralVoice voice, {
      bool pinnedRow = false,
      bool groupEnd = false,
    }) => _VoiceOption(
      key: ValueKey(voice.id),
      service: widget.service,
      language: widget.language,
      voice: voice,
      selected: voice.id == selected?.id,
      isDefault: voice.id == defaultVoice?.id,
      // "Previous" only once it is: while the voice the sheet opened with
      // is still the one in use, it is the user's pick, as on the page.
      openedWith: pinnedRow && voice.id == _openedWith,
      groupEnd: groupEnd,
      // Pinned rows sit above the filter, so they say their gender.
      showGender: !filtered || pinnedRow,
      onPick: () => _pick(voice, defaultVoice),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Close under the title, apart from the voices: it belongs to the
          // sheet's header.
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step2,
            tokens.spacing.step5,
            tokens.spacing.step4,
          ),
          child: Text(
            messages.speechSettingsCloudVoicePickerHint,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        // The last pinned voice carries the group's edge, flush with it.
        for (final (i, voice) in pinned.indexed)
          option(
            voice,
            pinnedRow: true,
            groupEnd: i == pinned.length - 1 && shown.isNotEmpty,
          ),
        // The pinned group ends before the filter starts, never touching it.
        if (shown.isNotEmpty) SizedBox(height: tokens.spacing.step3),
        // A pick the filter hides is still named, so the voice in use is
        // never out of sight.
        if (selected != null &&
            !pinned.contains(selected) &&
            !shown.contains(selected))
          Padding(
            padding: EdgeInsets.only(
              left: tokens.spacing.step5,
              top: tokens.spacing.step3,
              right: tokens.spacing.step5,
            ),
            child: Text(
              messages.speechSettingsCloudVoiceInUse(selected.name),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        // The filter sits with the list it filters.
        if (filtered)
          TtsGenderFilter<String>(
            selected: gender,
            female: 'female',
            male: 'male',
            onChanged: (value) => setState(() => _gender = value),
          ),
        for (final voice in shown) option(voice),
      ],
    );
  }
}

class _VoiceOption extends ConsumerWidget {
  const _VoiceOption({
    required this.service,
    required this.language,
    required this.voice,
    required this.selected,
    required this.isDefault,
    required this.openedWith,
    required this.groupEnd,
    required this.showGender,
    required this.onPick,
    super.key,
  });

  final CloudVoiceService service;
  final String language;
  final VoxtralVoice voice;
  final bool selected;
  final bool isDefault;

  /// The user's pick when the sheet opened, pinned for a one-tap revert.
  final bool openedWith;

  /// The last pinned row, whose rule ends the pinned group.
  final bool groupEnd;
  final bool showGender;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final sourceId = cloudVoiceSampleSourceId(language, voice.id);
    listenForPlaybackFailure(ref, context, sourceId);
    final gender = switch (voice.gender?.trim().toLowerCase()) {
      'female' => messages.speechVoiceGenderFemale,
      'male' => messages.speechVoiceGenderMale,
      _ => null,
    };
    return TtsVoiceRadioRow(
      title: voice.name,
      selected: selected,
      onTap: onPick,
      // Gender and mood tags in one ink. Under the filter the gender is
      // left out — the filter says it — and a row without tags is one line.
      caption: [
        if (showGender && gender != null) TextSpan(text: gender),
        if (showGender && gender != null && voice.tags.isNotEmpty)
          const TextSpan(text: ' · '),
        if (voice.tags.isNotEmpty) TextSpan(text: voice.tags.join(', ')),
      ],
      // A word, not a pill: an outlined tag in a tappable row reads as a
      // button of its own.
      fullWidthDivider: groupEnd,
      tag: isDefault || openedWith
          ? Text(
              isDefault
                  ? messages.speechSettingsCloudVoiceDefaultTag
                  : selected
                  ? messages.speechSettingsCloudVoiceChosenTag
                  : messages.speechSettingsCloudVoicePreviousTag,
              // One ink per meaning: the user's pick is bright, the way
              // back medium, the default a quiet attribute.
              style: tokens.typography.styles.others.caption.copyWith(
                color: selected
                    ? (isDefault
                          ? tokens.colors.text.mediumEmphasis
                          : tokens.colors.text.highEmphasis)
                    : isDefault
                    ? tokens.colors.text.lowEmphasis
                    : tokens.colors.text.mediumEmphasis,
              ),
            )
          : null,
      // A tap already plays a voice; only the picked one keeps a control,
      // to play it again or stop it. Every row keeps the slot, so all rows
      // are one height and a pick never moves the list.
      trailing: selected
          ? CloudVoicePreviewButton(
              sourceId: sourceId,
              voiceName: voice.name,
              onPlay: (controller) => speakCloudVoiceSample(
                controller,
                service: service,
                language: language,
                voiceId: voice.id,
              ),
            )
          : const SizedBox.square(dimension: TapTargets.compact),
    );
  }
}
