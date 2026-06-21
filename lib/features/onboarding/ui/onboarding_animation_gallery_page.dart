import 'package:flutter/material.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';

/// Debug-only live gallery for comparing the candidate welcome animations and
/// previewing the connect page. Reached from Settings → Advanced → Maintenance.
///
/// Tap a style chip to swap the welcome hero in place (animating), or open the
/// connect page to see its aurora backdrop. This is the in-app "test and
/// choose" selector; production uses the single chosen style.
class OnboardingAnimationGalleryPage extends StatefulWidget {
  const OnboardingAnimationGalleryPage({super.key});

  @override
  State<OnboardingAnimationGalleryPage> createState() =>
      _OnboardingAnimationGalleryPageState();
}

class _OnboardingAnimationGalleryPageState
    extends State<OnboardingAnimationGalleryPage> {
  OnboardingHeroStyle _style = OnboardingHeroStyle.constellation;
  bool _showConnect = false;

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
                    selected: !_showConnect && _style == style,
                    onSelected: (_) => setState(() {
                      _style = style;
                      _showConnect = false;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Connect page'),
                  selected: _showConnect,
                  onSelected: (value) => setState(() => _showConnect = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _showConnect
                      ? OnboardingConnectPanel(
                          onBack: () => setState(() => _showConnect = false),
                          onSelect: (_) {},
                        )
                      : OnboardingHeroPanel(
                          heroStyle: _style,
                          onConnect: () => setState(() => _showConnect = true),
                          onSkip: () {},
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
