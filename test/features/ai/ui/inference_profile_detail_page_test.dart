import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';

import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';

class _FakeInferenceProfileController extends InferenceProfileController {
  @override
  Stream<List<AiConfig>> build() => const Stream.empty();
}

class _FakeAiConfigByTypeController extends AiConfigByTypeController {
  _FakeAiConfigByTypeController(this._data);

  final List<AiConfig> _data;

  @override
  Stream<List<AiConfig>> build() {
    return Stream.value(_data);
  }
}

void main() {
  group('InferenceProfileDetailPage', () {
    Widget buildSubject({
      required String profileId,
      required Future<AiConfig?> Function() resolveConfig,
    }) {
      return makeTestableWidgetNoScroll(
        InferenceProfileDetailPage(profileId: profileId),
        overrides: [
          aiConfigByIdProvider(profileId).overrideWith(
            (ref) async => resolveConfig(),
          ),
          // The form (mounted on the data branch) reads the model and
          // provider lists too; supply empty fakes so it can render.
          aiConfigByTypeControllerProvider(
            AiConfigType.model,
          ).overrideWith(() => _FakeAiConfigByTypeController(const [])),
          aiConfigByTypeControllerProvider(
            AiConfigType.inferenceProvider,
          ).overrideWith(() => _FakeAiConfigByTypeController(const [])),
          inferenceProfileControllerProvider.overrideWith(
            _FakeInferenceProfileController.new,
          ),
        ],
      );
    }

    testWidgets(
      'renders a CircularProgressIndicator while the profile future is '
      'still pending',
      (tester) async {
        final completer = Completer<AiConfig?>();
        await tester.pumpWidget(
          buildSubject(
            profileId: 'pending-id',
            resolveConfig: () => completer.future,
          ),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Resolve the future so pending-timer guards don't trip on
        // teardown.
        completer.complete(null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'renders the localised "not found" message when the resolved config '
      'is null (e.g. profile row deleted while the URL was still bookmarked)',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            profileId: 'missing-id',
            resolveConfig: () async => null,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Profile not found'), findsOneWidget);
      },
    );

    testWidgets(
      'renders the localised "not found" message when the resolved config '
      'is the wrong AiConfig subtype (defensive — Beamer should never '
      'route a non-profile id here, but the page must not crash if it does)',
      (tester) async {
        final wrongType =
            AiConfig.inferenceProvider(
                  id: 'wrong-id',
                  name: 'A provider',
                  baseUrl: 'https://example.com',
                  apiKey: '',
                  inferenceProviderType: InferenceProviderType.gemini,
                  createdAt: DateTime(2024, 3, 15),
                )
                as AiConfigInferenceProvider;
        await tester.pumpWidget(
          buildSubject(
            profileId: 'wrong-id',
            resolveConfig: () async => wrongType,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Profile not found'), findsOneWidget);
      },
    );

    testWidgets(
      'renders the localised load-error message (with the error string '
      'interpolated into the template) when the resolver future rejects',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            profileId: 'error-id',
            resolveConfig: () async => throw Exception('boom'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Could not load profile'),
          findsOneWidget,
        );
        // The error message must be substituted into the template,
        // not eaten by the .when error arm.
        expect(find.textContaining('boom'), findsOneWidget);
      },
    );

    testWidgets(
      'mounts InferenceProfileForm with the resolved profile when the '
      "config is a matching AiConfigInferenceProfile — the form's edit "
      'title (not the create title) confirms the existingProfile arg was '
      'forwarded down',
      (tester) async {
        final profile = testInferenceProfile(
          id: 'happy-id',
          name: 'Routed profile',
        );
        await tester.pumpWidget(
          buildSubject(
            profileId: 'happy-id',
            resolveConfig: () async => profile,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(InferenceProfileForm), findsOneWidget);
        expect(find.text('Edit Profile'), findsOneWidget);
      },
    );
  });
}
