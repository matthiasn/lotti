import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/services/gemini_setup_prompt_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/gemini_setup_prompt_modal.dart';

/// A widget that automatically shows the Gemini setup prompt when appropriate.
///
/// Place this widget high in the widget tree (e.g., in HomePage or AppShell)
/// to trigger the prompt on app open.
///
/// The prompt will be shown if:
/// - No Gemini providers exist AND
/// - The user hasn't dismissed the prompt before
class GeminiSetupPromptTrigger extends ConsumerStatefulWidget {
  const GeminiSetupPromptTrigger({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<GeminiSetupPromptTrigger> createState() =>
      _GeminiSetupPromptTriggerState();
}

class _GeminiSetupPromptTriggerState
    extends ConsumerState<GeminiSetupPromptTrigger> {
  bool _hasShownPrompt = false;

  @override
  Widget build(BuildContext context) {
    // Watch the service and show prompt once after first successful load
    ref.watch(geminiSetupPromptServiceProvider).whenData((shouldShow) {
      if (shouldShow && !_hasShownPrompt) {
        _hasShownPrompt = true;
        // Use post-frame callback to avoid showing during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPromptModal();
        });
      }
    });

    return widget.child;
  }

  Future<void> _showPromptModal() async {
    if (!mounted) return;

    await GeminiSetupPromptModal.show(
      context,
      onSetUp: () {
        Navigator.of(context).pop();
        _navigateToGeminiSetup();
      },
      onDismiss: () {
        Navigator.of(context).pop();
        ref.read(geminiSetupPromptServiceProvider.notifier).dismissPrompt();
      },
    );
  }

  void _navigateToGeminiSetup() {
    // Navigate to AI Settings > Providers with Gemini pre-selected
    const AiSettingsNavigationService().navigateToCreateProvider(
      context,
      preselectedType: InferenceProviderType.gemini,
    );
  }
}
