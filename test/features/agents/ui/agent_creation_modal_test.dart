import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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

/// Controller that emits from a [StreamController], enabling dynamic updates.
class _DynamicInferenceProfileController extends InferenceProfileController {
  _DynamicInferenceProfileController(this._streamController);

  final StreamController<List<AiConfig>> _streamController;

  @override
  Stream<List<AiConfig>> build() => _streamController.stream;
}

/// Controller that never emits — keeps the provider in loading state.
class _LoadingInferenceProfileController extends InferenceProfileController {
  @override
  Stream<List<AiConfig>> build() => const Stream.empty();
}

/// Controller that emits an error — puts the provider in error state.
class _ErrorInferenceProfileController extends InferenceProfileController {
  @override
  Stream<List<AiConfig>> build() =>
      Stream.error(Exception('profile load failure'));
}

/// Pumps a minimal widget that shows the modal when a button is tapped.
/// Returns the result via the [resultNotifier].
Widget _buildSubject({
  required List<AiConfig> profiles,
  required ValueNotifier<AgentCreationResult?> resultNotifier,
  List<Override>? extraOverrides,
  int templateCount = 2,
  List<AgentTemplateEntity>? templates,
}) {
  final resolvedTemplates =
      templates ??
      List.generate(
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
            templates: resolvedTemplates,
          );
          resultNotifier.value = result;
        },
        child: const Text('Open Modal'),
      ),
    ),
  );
}

void main() {
  testWidgets('two templates shows template selection page first', (
    tester,
  ) async {
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

  testWidgets('day-agent templates use the localized day-agent label', (
    tester,
  ) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final templates = [
      makeTestTemplate(
        id: 'day-template',
        agentId: 'day-template',
        displayName: 'Shepherd',
        kind: AgentTemplateKind.dayAgent,
      ),
      makeTestTemplate(
        id: 'task-template',
        agentId: 'task-template',
        displayName: 'Task Agent',
      ),
    ];

    await tester.pumpWidget(
      _buildSubject(
        profiles: [testInferenceProfile()],
        resultNotifier: resultNotifier,
        templates: templates,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));
    expect(find.text('Shepherd'), findsOneWidget);
    expect(
      find.text(context.messages.agentTemplateKindDayAgent),
      findsOneWidget,
    );
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

  testWidgets('selecting template then profile returns correct result', (
    tester,
  ) async {
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

  testWidgets('single template + profile selection returns correct result', (
    tester,
  ) async {
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

  testWidgets('template page shows localized template kind subtitles', (
    tester,
  ) async {
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

    // Templates show localized kind labels as subtitle.
    expect(
      find.text(context.messages.agentTemplateKindTaskAgent),
      findsNWidgets(2),
    );
  });

  testWidgets('profile page shows thinking model ID as subtitle', (
    tester,
  ) async {
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

  testWidgets('returns null when templates list is empty', (tester) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);

    await tester.pumpWidget(
      _buildSubject(
        profiles: [testInferenceProfile()],
        resultNotifier: resultNotifier,
        templateCount: 0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Modal should not open; result stays null.
    expect(resultNotifier.value, isNull);
    // No modal title visible.
    final context = tester.element(find.byType(ElevatedButton));
    expect(
      find.text(context.messages.agentTemplateSelectTitle),
      findsNothing,
    );
  });

  testWidgets('back button on profile page returns to template page', (
    tester,
  ) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final profile = testInferenceProfile(name: 'Pro X');

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

    // Page 0: template selection.
    expect(
      find.text(context.messages.agentTemplateSelectTitle),
      findsOneWidget,
    );

    // Select template to go to profile page.
    await tester.tap(find.text('Template 0'));
    await tester.pumpAndSettle();

    // Page 1: profile selection.
    expect(
      find.text(context.messages.inferenceProfilesTitle),
      findsOneWidget,
    );

    // Tap back button to return to template page.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Back on template selection.
    expect(
      find.text(context.messages.agentTemplateSelectTitle),
      findsOneWidget,
    );
  });

  testWidgets(
    'hovering a template row turns the divider above it transparent',
    (tester) async {
      final resultNotifier = ValueNotifier<AgentCreationResult?>(null);

      await tester.pumpWidget(
        _buildSubject(
          profiles: [testInferenceProfile()],
          resultNotifier: resultNotifier,
          templateCount: 3,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Two dividers between three template rows.
      final dividersBefore = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividersBefore, hasLength(2));
      for (final d in dividersBefore) {
        expect(d.color, isNot(Colors.transparent));
      }

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Template 1')));
      await tester.pumpAndSettle();

      final dividersAfter = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividersAfter[0].color, Colors.transparent);
      expect(dividersAfter[1].color, Colors.transparent);
    },
  );

  testWidgets(
    'hovering a profile row turns the divider above it transparent',
    (tester) async {
      final resultNotifier = ValueNotifier<AgentCreationResult?>(null);

      await tester.pumpWidget(
        _buildSubject(
          profiles: [
            testInferenceProfile(id: 'p-0', name: 'Profile 0'),
            testInferenceProfile(id: 'p-1', name: 'Profile 1'),
            testInferenceProfile(id: 'p-2', name: 'Profile 2'),
          ],
          resultNotifier: resultNotifier,
          templateCount: 1,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Single template skips to profile page directly. Three profiles → 2
      // dividers, both opaque before hover.
      final dividersBefore = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividersBefore, hasLength(2));
      for (final d in dividersBefore) {
        expect(d.color, isNot(Colors.transparent));
      }

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Profile 1')));
      await tester.pumpAndSettle();

      final dividersAfter = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividersAfter[0].color, Colors.transparent);
      expect(dividersAfter[1].color, Colors.transparent);

      // Pointer leaves — dividers return to default color.
      await gesture.moveTo(const Offset(-100, -100));
      await tester.pumpAndSettle();

      final dividersFinal = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      for (final d in dividersFinal) {
        expect(d.color, isNot(Colors.transparent));
      }
    },
  );

  testWidgets('desktop-only profiles render the desktop trailing icon', (
    tester,
  ) async {
    final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
    final desktopProfile = testInferenceProfile(
      id: 'desk',
      name: 'Desktop Only',
      desktopOnly: true,
    );

    await tester.pumpWidget(
      _buildSubject(
        profiles: [desktopProfile],
        resultNotifier: resultNotifier,
        templateCount: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // The trailing widget for desktop-only profiles is the desktop_windows
    // icon — verifies the trailing branch in _ProfileList.
    expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
  });

  testWidgets(
    'templateImprover and projectAgent kinds show their localized labels',
    (tester) async {
      final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
      final templates = [
        makeTestTemplate(
          id: 'tpl-improver',
          agentId: 'tpl-improver',
          displayName: 'Improver Template',
          kind: AgentTemplateKind.templateImprover,
        ),
        makeTestTemplate(
          id: 'tpl-project',
          agentId: 'tpl-project',
          displayName: 'Project Template',
          kind: AgentTemplateKind.projectAgent,
        ),
      ];

      await tester.pumpWidget(
        _buildSubject(
          profiles: [testInferenceProfile()],
          resultNotifier: resultNotifier,
          templates: templates,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ElevatedButton));
      // Both localized kind labels must appear — covers the templateImprover
      // and projectAgent branches in _templateKindLabel (lines 157-160).
      expect(
        find.text(context.messages.agentTemplateKindImprover),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateKindProjectAgent),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'profile page shows loading spinner while profiles are loading',
    (tester) async {
      final resultNotifier = ValueNotifier<AgentCreationResult?>(null);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            inferenceProfileControllerProvider.overrideWith(
              _LoadingInferenceProfileController.new,
            ),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await AgentCreationModal.show(
                  context: context,
                  templates: [
                    makeTestTemplate(
                      id: 'tpl-0',
                      agentId: 'tpl-0',
                      displayName: 'Only Template',
                    ),
                  ],
                );
                resultNotifier.value = result;
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      // Pump enough frames to complete the modal's opening animation without
      // pumpAndSettle (the CircularProgressIndicator animates forever, so
      // pumpAndSettle would time out).
      await tester.pump(const Duration(seconds: 1));

      // Single template auto-skips to profile page; stream never emits →
      // AsyncLoading → CircularProgressIndicator (line 182).
      // The indicator may be inside an Offstage route wrapper while the
      // modal animation runs; skipOffstage:false ensures it is found.
      expect(
        find.byType(CircularProgressIndicator, skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'profile page shows error text when profile stream errors',
    (tester) async {
      final resultNotifier = ValueNotifier<AgentCreationResult?>(null);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            inferenceProfileControllerProvider.overrideWith(
              _ErrorInferenceProfileController.new,
            ),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await AgentCreationModal.show(
                  context: context,
                  templates: [
                    makeTestTemplate(
                      id: 'tpl-0',
                      agentId: 'tpl-0',
                      displayName: 'Only Template',
                    ),
                  ],
                );
                resultNotifier.value = result;
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ElevatedButton));
      // Stream emits an error → AsyncError → error text is shown (line 207).
      expect(find.text(context.messages.commonError), findsOneWidget);
    },
  );

  testWidgets(
    'hovering a template row and moving away clears the divider transparency',
    (tester) async {
      final resultNotifier = ValueNotifier<AgentCreationResult?>(null);

      await tester.pumpWidget(
        _buildSubject(
          profiles: [testInferenceProfile()],
          resultNotifier: resultNotifier,
          templateCount: 3,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);

      // Hover over Template 1 — dividers turn transparent.
      await gesture.moveTo(tester.getCenter(find.text('Template 1')));
      await tester.pumpAndSettle();

      final dividersHovered = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividersHovered[0].color, Colors.transparent);

      // Move pointer away — covers the hover-exit branch (_hoveredId = null,
      // lines 141-142) in _TemplateSelectionPageState.
      await gesture.moveTo(const Offset(-200, -200));
      await tester.pumpAndSettle();

      final dividersOut = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      for (final d in dividersOut) {
        expect(d.color, isNot(Colors.transparent));
      }
    },
  );

  testWidgets(
    '_ProfileListState.didUpdateWidget clears hoveredId when hovered profile '
    'disappears from the updated list',
    (tester) async {
      final resultNotifier = ValueNotifier<AgentCreationResult?>(null);
      final streamController = StreamController<List<AiConfig>>();
      addTearDown(streamController.close);

      // Seed the stream with two profiles so there is a divider.
      streamController.add([
        testInferenceProfile(id: 'p-a', name: 'Alpha'),
        testInferenceProfile(id: 'p-b', name: 'Beta'),
      ]);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            inferenceProfileControllerProvider.overrideWith(
              () => _DynamicInferenceProfileController(streamController),
            ),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await AgentCreationModal.show(
                  context: context,
                  templates: [
                    makeTestTemplate(
                      id: 'tpl-0',
                      agentId: 'tpl-0',
                      displayName: 'Only Template',
                    ),
                  ],
                );
                resultNotifier.value = result;
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Hover over 'Alpha' so _hoveredId = 'p-a'.
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Alpha')));
      await tester.pumpAndSettle();

      // Confirm hover is active — the only divider should be transparent.
      final dividersHovered = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividersHovered, hasLength(1));
      expect(dividersHovered[0].color, Colors.transparent);

      // Move pointer off-screen so no widget re-triggers hover when rebuilding.
      await gesture.moveTo(const Offset(-200, -200));
      await tester.pump();

      // Emit a new list that no longer contains 'Alpha' — triggers
      // didUpdateWidget (lines 213-218): _hoveredId ('p-a') is cleared
      // because it is absent from the new filtered list.
      streamController.add([
        testInferenceProfile(id: 'p-b', name: 'Beta'),
        testInferenceProfile(id: 'p-c', name: 'Gamma'),
      ]);
      await tester.pumpAndSettle();

      // 'Alpha' is gone; divider between Beta and Gamma must be opaque because
      // _hoveredId was cleared by didUpdateWidget.
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
      final dividersAfterUpdate = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividersAfterUpdate, hasLength(1));
      expect(dividersAfterUpdate[0].color, isNot(Colors.transparent));
    },
  );
}
