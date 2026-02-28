import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/widgets/profile_card.dart';

import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  group('ProfileCard', () {
    testWidgets('displays profile name', (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'My Test Profile',
      );
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidget(
          ProfileCard(
            profile: profile,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Test Profile'), findsOneWidget);
      expect(tapped, isFalse);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      final profile = testInferenceProfile(id: 'p1', name: 'Tap Me');
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidget(
          ProfileCard(
            profile: profile,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows desktop-only chip when desktopOnly is true',
        (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Desktop Profile',
        desktopOnly: true,
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ProfileCard(profile: profile, onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Desktop Only'), findsOneWidget);
    });

    testWidgets('shows lock icon for default profiles', (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Default Profile',
        isDefault: true,
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ProfileCard(profile: profile, onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows thinking model slot', (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Full Profile',
        thinkingModelId: 'claude-4-sonnet',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ProfileCard(profile: profile, onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('claude-4-sonnet'), findsOneWidget);
    });

    testWidgets('shows all configured model slots', (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Multi Slot Profile',
        thinkingModelId: 'thinking-model',
        imageRecognitionModelId: 'vision-model',
        transcriptionModelId: 'audio-model',
        imageGenerationModelId: 'image-gen-model',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ProfileCard(profile: profile, onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('thinking-model'), findsOneWidget);
      expect(find.text('Image Recognition'), findsOneWidget);
      expect(find.text('vision-model'), findsOneWidget);
      expect(find.text('Transcription'), findsOneWidget);
      expect(find.text('audio-model'), findsOneWidget);
      expect(find.text('Image Generation'), findsOneWidget);
      expect(find.text('image-gen-model'), findsOneWidget);
    });

    testWidgets('hides optional slots when not configured', (tester) async {
      final profile = testInferenceProfile(
        id: 'p1',
        name: 'Minimal Profile',
        thinkingModelId: 'thinking-only',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ProfileCard(profile: profile, onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('Image Recognition'), findsNothing);
      expect(find.text('Transcription'), findsNothing);
      expect(find.text('Image Generation'), findsNothing);
    });
  });

  group('ProfileSlotRow', () {
    testWidgets('displays label and model ID', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const ProfileSlotRow(
            label: 'Thinking',
            modelId: 'claude-4-opus',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('claude-4-opus'), findsOneWidget);
    });
  });
}
