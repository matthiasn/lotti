import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/profile_selector.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

import '../../../test_helper.dart';
import '../test_utils.dart';

class _FakeInferenceProfileController extends InferenceProfileController {
  _FakeInferenceProfileController(this._profiles);

  final List<AiConfig> _profiles;

  @override
  Stream<List<AiConfig>> build() => Stream.value(_profiles);
}

Widget _buildSubject({
  required String? selectedProfileId,
  required ValueChanged<String?> onProfileSelected,
  required List<AiConfig> profiles,
}) {
  return RiverpodWidgetTestBench(
    overrides: [
      inferenceProfileControllerProvider.overrideWith(
        () => _FakeInferenceProfileController(profiles),
      ),
    ],
    child: ProfileSelector(
      selectedProfileId: selectedProfileId,
      onProfileSelected: onProfileSelected,
    ),
  );
}

Widget _buildSettingsField({
  required String? selectedProfileId,
  required ValueChanged<String?> onProfileSelected,
  required List<AiConfig> profiles,
  String? hintText,
}) {
  return RiverpodWidgetTestBench(
    overrides: [
      inferenceProfileControllerProvider.overrideWith(
        () => _FakeInferenceProfileController(profiles),
      ),
    ],
    child: SettingsProfilePickerField(
      selectedProfileId: selectedProfileId,
      onProfileSelected: onProfileSelected,
      hintText: hintText,
    ),
  );
}

/// Hosts the settings field on a NESTED navigator (mirroring the app, where
/// the category-details page lives on a nested Beamer navigator below the root
/// navigator). At the default phone width the selection sheet is pushed onto
/// the root navigator, so a page-context pop would unwind this nested page
/// instead of the sheet. The `category-details-marker` proves whether the page
/// survived selecting a profile.
Widget _buildNestedNavigatorSettingsField({
  required ValueChanged<String?> onProfileSelected,
  required List<AiConfig> profiles,
}) {
  return RiverpodWidgetTestBench(
    overrides: [
      inferenceProfileControllerProvider.overrideWith(
        () => _FakeInferenceProfileController(profiles),
      ),
    ],
    child: Navigator(
      onGenerateInitialRoutes: (navigator, initialRoute) => [
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(child: Text('settings-list-page')),
          ),
        ),
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('category-details-marker'),
                  SettingsProfilePickerField(
                    selectedProfileId: null,
                    onProfileSelected: onProfileSelected,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('shows placeholder when no profile selected', (tester) async {
    final profile = testInferenceProfile();

    await tester.pumpWidget(
      _buildSubject(
        selectedProfileId: null,
        onProfileSelected: (_) {},
        profiles: [profile],
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ProfileSelector));
    expect(
      find.text(context.messages.inferenceProfileSelectProfile),
      findsOneWidget,
    );
    expect(find.text(profile.name), findsNothing);
  });

  testWidgets('shows selected profile name when profileId matches', (
    tester,
  ) async {
    final profile = testInferenceProfile(
      id: 'profile-abc',
      name: 'My Profile',
    );

    await tester.pumpWidget(
      _buildSubject(
        selectedProfileId: 'profile-abc',
        onProfileSelected: (_) {},
        profiles: [profile],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
  });

  testWidgets('shows clear button when profile is selected', (tester) async {
    final profile = testInferenceProfile(id: 'p-1');
    String? clearedTo = 'not-cleared';

    await tester.pumpWidget(
      _buildSubject(
        selectedProfileId: 'p-1',
        onProfileSelected: (id) => clearedTo = id,
        profiles: [profile],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(clearedTo, isNull);
  });

  testWidgets('opens picker and selecting a profile calls callback', (
    tester,
  ) async {
    final profileA = testInferenceProfile(id: 'p-a', name: 'Alpha');
    final profileB = testInferenceProfile(id: 'p-b', name: 'Beta');
    String? selectedId;

    await tester.pumpWidget(
      _buildSubject(
        selectedProfileId: null,
        onProfileSelected: (id) => selectedId = id,
        profiles: [profileA, profileB],
      ),
    );
    await tester.pumpAndSettle();

    // Tap the InputDecorator to open the picker.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Both profiles should be visible in the picker.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // Select Beta.
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(selectedId, 'p-b');
  });

  testWidgets('shows check icon for the currently selected profile', (
    tester,
  ) async {
    final profile = testInferenceProfile(id: 'p-1', name: 'Selected One');

    await tester.pumpWidget(
      _buildSubject(
        selectedProfileId: 'p-1',
        onProfileSelected: (_) {},
        profiles: [profile],
      ),
    );
    await tester.pumpAndSettle();

    // Open picker.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('shows desktop icon for desktopOnly profiles', (tester) async {
    final profile = testInferenceProfile(
      id: 'p-desk',
      name: 'Desktop Only',
      desktopOnly: true,
    );

    await tester.pumpWidget(
      _buildSubject(
        selectedProfileId: null,
        onProfileSelected: (_) {},
        profiles: [profile],
      ),
    );
    await tester.pumpAndSettle();

    // Open picker.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
  });

  testWidgets('disabled when no profiles available', (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        selectedProfileId: null,
        onProfileSelected: (_) {},
        profiles: [],
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ProfileSelector));
    expect(
      find.text(context.messages.inferenceProfileSelectProfile),
      findsOneWidget,
    );
    // The dropdown arrow is still visible but InkWell.onTap is null.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  group('SettingsProfilePickerField', () {
    testWidgets('shows label and default hint when nothing is selected', (
      tester,
    ) async {
      final profile = testInferenceProfile();

      await tester.pumpWidget(
        _buildSettingsField(
          selectedProfileId: null,
          onProfileSelected: (_) {},
          profiles: [profile],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byType(SettingsProfilePickerField),
      );
      expect(
        find.text(context.messages.agentDefaultProfileLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.inferenceProfileSelectProfile),
        findsOneWidget,
      );
      expect(find.text(profile.name), findsNothing);
    });

    testWidgets('shows a custom hint when provided', (tester) async {
      await tester.pumpWidget(
        _buildSettingsField(
          selectedProfileId: null,
          onProfileSelected: (_) {},
          profiles: [testInferenceProfile()],
          hintText: 'Select a profile',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select a profile'), findsOneWidget);
    });

    testWidgets('shows the selected profile name', (tester) async {
      final profile = testInferenceProfile(
        id: 'profile-abc',
        name: 'My Profile',
      );

      await tester.pumpWidget(
        _buildSettingsField(
          selectedProfileId: 'profile-abc',
          onProfileSelected: (_) {},
          profiles: [profile],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Profile'), findsOneWidget);
    });

    testWidgets('clear affordance resets the selection to null', (
      tester,
    ) async {
      final profile = testInferenceProfile(id: 'p-1');
      String? clearedTo = 'not-cleared';

      await tester.pumpWidget(
        _buildSettingsField(
          selectedProfileId: 'p-1',
          onProfileSelected: (id) => clearedTo = id,
          profiles: [profile],
        ),
      );
      await tester.pumpAndSettle();

      // The kit field renders the clear affordance as a close icon.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(clearedTo, isNull);
    });

    testWidgets('dangling selection stays enabled and can be cleared', (
      tester,
    ) async {
      String? clearedTo = 'not-cleared';

      await tester.pumpWidget(
        _buildSettingsField(
          selectedProfileId: 'missing-profile',
          onProfileSelected: (id) => clearedTo = id,
          profiles: [],
        ),
      );
      await tester.pump();

      final context = tester.element(
        find.byType(SettingsProfilePickerField),
      );
      final field = tester.widget<SettingsPickerField>(
        find.byType(SettingsPickerField),
      );
      expect(field.enabled, isTrue);
      expect(
        find.text(context.messages.inferenceProfileUnavailable),
        findsOneWidget,
      );
      expect(find.text('missing-profile'), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(clearedTo, isNull);
    });

    testWidgets('opens picker and selecting a profile calls callback', (
      tester,
    ) async {
      final profileA = testInferenceProfile(id: 'p-a', name: 'Alpha');
      final profileB = testInferenceProfile(id: 'p-b', name: 'Beta');
      String? selectedId;

      await tester.pumpWidget(
        _buildSettingsField(
          selectedProfileId: null,
          onProfileSelected: (id) => selectedId = id,
          profiles: [profileA, profileB],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(selectedId, 'p-b');
    });

    testWidgets('inert when no profiles available — tap opens no modal', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSettingsField(
          selectedProfileId: null,
          onProfileSelected: (_) {},
          profiles: [],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byType(SettingsProfilePickerField),
      );
      // The field label renders exactly once; opening the modal would add
      // a second occurrence as the modal title.
      expect(
        find.text(context.messages.agentDefaultProfileLabel),
        findsOneWidget,
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentDefaultProfileLabel),
        findsOneWidget,
      );
    });
  });

  group('mobile nested-navigator regression', () {
    testWidgets(
      'selecting a profile keeps the category page and reports the callback '
      '(does not pop the page)',
      (tester) async {
        final profileA = testInferenceProfile(id: 'p-a', name: 'Alpha');
        final profileB = testInferenceProfile(id: 'p-b', name: 'Beta');
        String? selectedId;

        await tester.pumpWidget(
          _buildNestedNavigatorSettingsField(
            onProfileSelected: (id) => selectedId = id,
            profiles: [profileA, profileB],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('category-details-marker'), findsOneWidget);

        // Open the picker sheet (pushed onto the root navigator at phone width).
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);

        // Select a profile.
        await tester.tap(find.text('Beta'));
        await tester.pumpAndSettle();

        // The selection was reported …
        expect(selectedId, 'p-b');
        // … the sheet closed …
        expect(find.text('Alpha'), findsNothing);
        // … and, crucially, the category-details page is still on screen: the
        // pop dismissed the sheet, not the page (the reported mobile bug).
        expect(find.text('category-details-marker'), findsOneWidget);
        expect(find.text('settings-list-page'), findsNothing);
      },
    );
  });
}
