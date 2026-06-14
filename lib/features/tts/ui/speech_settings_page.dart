import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/tts/ui/speech_settings_body.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mobile / legacy wrapper for the Speech settings. Keeps the
/// `SliverBoxAdapterPage` chrome and delegates content to
/// [SpeechSettingsBody], so the desktop Settings-v2 detail pane can host the
/// same body without the sliver chrome.
class SpeechSettingsPage extends StatelessWidget {
  const SpeechSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsSpeechTitle,
      showBackButton: true,
      child: const SpeechSettingsBody(),
    );
  }
}
