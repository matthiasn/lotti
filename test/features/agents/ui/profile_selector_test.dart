import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/profile_selector.dart';
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
      find.text(context.messages.inferenceProfileSelectModel),
      findsOneWidget,
    );
    expect(find.text(profile.name), findsNothing);
  });

  testWidgets('shows selected profile name when profileId matches',
      (tester) async {
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

    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(clearedTo, isNull);
  });

  testWidgets('opens picker and selecting a profile calls callback',
      (tester) async {
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

  testWidgets('shows check icon for the currently selected profile',
      (tester) async {
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
      find.text(context.messages.inferenceProfileSelectModel),
      findsOneWidget,
    );
    // The dropdown arrow is still visible but InkWell.onTap is null.
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });
}
