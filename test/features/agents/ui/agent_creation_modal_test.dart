import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_creation_modal.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../test_helper.dart';
import '../test_utils.dart';

class _FakeInferenceProfileController extends InferenceProfileController {
  _FakeInferenceProfileController(this._profiles);

  final List<AiConfig> _profiles;

  @override
  Stream<List<AiConfig>> build() => Stream.value(_profiles);
}

/// Pumps a minimal widget that shows the modal when a button is tapped.
/// Returns the result via the [resultNotifier].
Widget _buildSubject({
  required List<AiConfig> profiles,
  required ValueNotifier<AgentCreationResult?> resultNotifier,
  List<Override>? extraOverrides,
  int templateCount = 2,
}) {
  final templates = List.generate(
    templateCount,
    (i) => makeTestTemplate(
      id: 'tpl-$i',
      agentId: 'tpl-$i',
      displayName: 'Template $i',
    ),
  );

  return RiverpodWidgetTestBench(
    overrides: [
      inferenceProfileControllerProvider.overrideWith(
        () => _FakeInferenceProfileController(profiles),
      ),
      ...?extraOverrides,
    ],
    child: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          final result = await AgentCreationModal.show(
            context: context,
            templates: templates,
          );
          resultNotifier.value = result;
        },
        child: const Text('Open Modal'),
      ),
    ),
  );
}

void main() {
  testWidgets('two templates shows template selection page first',
      (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final profile = testInferenceProfile();

    await tester.pumpWidget(
      _buildSubject(
        profiles: [profile],
        resultNotifier: resultNotifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));

    // Page 0: template selection is shown.
    expect(
      find.text(context.messages.agentTemplateSelectTitle),
      findsOneWidget,
    );
    expect(find.text('Template 0'), findsOneWidget);
    expect(find.text('Template 1'), findsOneWidget);
  });

  testWidgets('single template auto-skips to profile page', (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final profile = testInferenceProfile(name: 'Fast Flash');

    await tester.pumpWidget(
      _buildSubject(
        profiles: [profile],
        resultNotifier: resultNotifier,
        templateCount: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));

    // Profile page is shown directly (skipped template page).
    expect(
      find.text(context.messages.inferenceProfilesTitle),
      findsOneWidget,
    );
    expect(find.text('Fast Flash'), findsOneWidget);
  });

  testWidgets('selecting template then profile returns correct result',
      (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final profile = testInferenceProfile(id: 'prof-x', name: 'Pro X');

    await tester.pumpWidget(
      _buildSubject(
        profiles: [profile],
        resultNotifier: resultNotifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Select Template 0.
    await tester.tap(find.text('Template 0'));
    await tester.pumpAndSettle();

    // Select profile.
    await tester.tap(find.text('Pro X'));
    await tester.pumpAndSettle();

    expect(resultNotifier.value, isNotNull);
    expect(resultNotifier.value!.templateId, 'tpl-0');
    expect(resultNotifier.value!.profileId, 'prof-x');
  });

  testWidgets('single template + profile selection returns correct result',
      (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final profile = testInferenceProfile(id: 'solo-prof', name: 'Solo');

    await tester.pumpWidget(
      _buildSubject(
        profiles: [profile],
        resultNotifier: resultNotifier,
        templateCount: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Directly on profile page; select profile.
    await tester.tap(find.text('Solo'));
    await tester.pumpAndSettle();

    expect(resultNotifier.value, isNotNull);
    expect(resultNotifier.value!.templateId, 'tpl-0');
    expect(resultNotifier.value!.profileId, 'solo-prof');
  });

  testWidgets('shows empty message when no profiles available', (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);

    await tester.pumpWidget(
      _buildSubject(
        profiles: [],
        resultNotifier: resultNotifier,
        templateCount: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));
    expect(
      find.text(context.messages.inferenceProfilesEmpty),
      findsOneWidget,
    );
  });

  testWidgets('template page shows model IDs as subtitles', (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final profile = testInferenceProfile();

    await tester.pumpWidget(
      _buildSubject(
        profiles: [profile],
        resultNotifier: resultNotifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Templates have modelId 'models/gemini-3-flash-preview' as default.
    expect(
      find.text('models/gemini-3-flash-preview'),
      findsNWidgets(2),
    );
  });

  testWidgets('profile page shows thinking model ID as subtitle',
      (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final profile = testInferenceProfile(
      name: 'Test Prof',
      thinkingModelId: 'gemini-2.5-pro',
    );

    await tester.pumpWidget(
      _buildSubject(
        profiles: [profile],
        resultNotifier: resultNotifier,
        templateCount: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    expect(find.text('Test Prof'), findsOneWidget);
    expect(find.text('gemini-2.5-pro'), findsOneWidget);
  });
}
