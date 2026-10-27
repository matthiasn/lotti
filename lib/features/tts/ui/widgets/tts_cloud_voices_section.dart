import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/state/cloud_voice_settings_providers.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/features/tts/ui/widgets/tts_source_play_button.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:material_ui/material_ui.dart';

/// Source id prefix of the test utterances played from Speech settings.
const String cloudVoiceTestSourcePrefix = 'speech-settings-voice-';

/// The Cloud voices section of Speech settings: for each provider a profile
/// reads aloud with, one row per language its catalog covers — the voice
/// that speaks it, and a control that plays a sample sentence in that voice.
///
/// Without any such profile it says where a cloud voice comes from instead,
/// so nobody looks for a missing read-aloud control.
class TtsCloudVoicesSection extends ConsumerWidget {
  const TtsCloudVoicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    // The previous value is kept while profiles reload, so a sync never
    // swaps the rows for a spinner.
    final services = ref.watch(cloudVoiceServicesProvider).value ?? const [];
    return SettingsFormSection(
      title: messages.speechSettingsCloudVoicesLabel,
      description: services.isEmpty
          ? messages.speechSettingsCloudVoicesNone
          : messages.speechSettingsCloudVoicesDescription,
      children: [
        for (final service in services)
          _ServiceVoices(service: service, showName: services.length > 1),
      ],
    );
  }
}

class _ServiceVoices extends ConsumerWidget {
  const _ServiceVoices({required this.service, required this.showName});

  final CloudVoiceService service;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final catalog = ref.watch(voxtralVoiceCatalogProvider(service.provider));
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: tokens.spacing.step4,
        children: [
          if (showName) Text(service.provider.name, style: caption),
          switch (catalog) {
            AsyncValue(:final value?) => _LanguageRows(
              service: service,
              catalog: value,
            ),
            AsyncValue(hasError: true) => Text(
              messages.speechSettingsCloudVoicesUnavailable,
              style: caption,
            ),
            _ => Center(
              child: DesignSystemSpinner(
                size: IconSizes.m,
                semanticsLabel: messages.speechSettingsCloudVoicesLoading,
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _LanguageRows extends ConsumerWidget {
  const _LanguageRows({required this.service, required this.catalog});

  final CloudVoiceService service;
  final VoxtralVoiceCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final chosen = ref.watch(
      ttsSettingsControllerProvider.select((s) => s.cloudVoiceByLanguage),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tokens.spacing.step3,
      children: [
        for (final language in catalog.languageCodes)
          _LanguageRow(
            service: service,
            catalog: catalog,
            language: language,
            chosenVoiceId: chosen[language],
          ),
      ],
    );
  }
}

class _LanguageRow extends ConsumerWidget {
  const _LanguageRow({
    required this.service,
    required this.catalog,
    required this.language,
    required this.chosenVoiceId,
  });

  final CloudVoiceService service;
  final VoxtralVoiceCatalog catalog;
  final String language;
  final String? chosenVoiceId;

  /// The sample sentence in [language], from that language's own catalog;
  /// `null` for a language the app does not ship, which gets no test.
  static String? sampleFor(String language) {
    final supported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == language,
    );
    return supported
        ? lookupAppLocalizations(
            Locale(language),
          ).speechSettingsCloudVoiceSample
        : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final voices = catalog.forLanguage(language);
    final defaultVoice = catalog.resolve(languageCode: language);
    final chosen = chosenVoiceId == null ? null : catalog.byId(chosenVoiceId!);
    final defaultLabel = messages.speechSettingsCloudVoiceDefault(
      defaultVoice?.name ?? '',
    );
    final languageName =
        SupportedLanguage.fromCode(language)?.localizedName(context) ??
        language.toUpperCase();
    final sample = sampleFor(language);
    final sourceId = '$cloudVoiceTestSourcePrefix$language';
    listenForPlaybackFailure(ref, context, sourceId);
    return Row(
      spacing: tokens.spacing.step3,
      children: [
        Expanded(
          child: DesignSystemDropdown(
            label: languageName,
            inputLabel: chosen?.name ?? defaultLabel,
            items: [
              DesignSystemDropdownItem(
                id: '',
                label: defaultLabel,
                selected: chosen == null,
              ),
              for (final voice in voices)
                DesignSystemDropdownItem(
                  id: voice.id,
                  label: voice.name,
                  selected: voice.id == chosen?.id,
                ),
            ],
            onItemPressed: (item) => ref
                .read(ttsSettingsControllerProvider.notifier)
                .setCloudVoice(language, item.id.isEmpty ? null : item.id),
          ),
        ),
        if (sample != null)
          TtsSourcePlayButton(
            sourceId: sourceId,
            onPlay: (controller) => controller.speak(
              sourceId: sourceId,
              text: sample,
              cloudRoute: TtsCloudRoute(
                provider: service.provider,
                model: service.model,
                languageCode: language,
              ),
            ),
          ),
      ],
    );
  }
}
