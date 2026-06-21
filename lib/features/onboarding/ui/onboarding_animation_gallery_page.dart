import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';

enum _GalleryView { welcome, connect, apiKey }

/// Debug-only live gallery for comparing the candidate welcome animations and
/// previewing the connect + API-key steps. Reached from Settings → Advanced →
/// Maintenance. Tap a style chip to swap the welcome hero, or the step chips to
/// jump to a step; the in-panel buttons also navigate the real flow.
class OnboardingAnimationGalleryPage extends StatefulWidget {
  const OnboardingAnimationGalleryPage({super.key});

  @override
  State<OnboardingAnimationGalleryPage> createState() =>
      _OnboardingAnimationGalleryPageState();
}

class _OnboardingAnimationGalleryPageState
    extends State<OnboardingAnimationGalleryPage> {
  OnboardingHeroStyle _style = OnboardingHeroStyle.constellation;
  _GalleryView _view = _GalleryView.welcome;
  InferenceProviderType _type = InferenceProviderType.gemini;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        title: const Text('Onboarding animations'),
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final style in OnboardingHeroStyle.values)
                  ChoiceChip(
                    label: Text(style.label),
                    selected: _view == _GalleryView.welcome && _style == style,
                    onSelected: (_) => setState(() {
                      _style = style;
                      _view = _GalleryView.welcome;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Connect'),
                  selected: _view == _GalleryView.connect,
                  onSelected: (_) =>
                      setState(() => _view = _GalleryView.connect),
                ),
                ChoiceChip(
                  label: const Text('API key'),
                  selected: _view == _GalleryView.apiKey,
                  onSelected: (_) =>
                      setState(() => _view = _GalleryView.apiKey),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _buildPanel(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    switch (_view) {
      case _GalleryView.welcome:
        return OnboardingHeroPanel(
          heroStyle: _style,
          onConnect: () => setState(() => _view = _GalleryView.connect),
          onSkip: () {},
        );
      case _GalleryView.connect:
        return OnboardingConnectPanel(
          onBack: () => setState(() => _view = _GalleryView.welcome),
          onSelect: (type) => setState(() {
            _type = type;
            _view = _GalleryView.apiKey;
          }),
        );
      case _GalleryView.apiKey:
        return OnboardingApiKeyPanel(
          key: ValueKey('gallery-apikey-${_type.name}'),
          type: _type,
          onBack: () => setState(() => _view = _GalleryView.connect),
          onConnected: () => setState(() => _view = _GalleryView.welcome),
        );
    }
  }
}
