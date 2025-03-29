import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/image_analysis.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_view.dart';

import '../../../../test_helper.dart';

void main() {
  const testId = 'test-image-id';
  const testAnalysis = 'This is a test image analysis result';

  testWidgets('renders empty state initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestApp(
        ProviderScope(
          overrides: [
            aiImageAnalysisControllerProvider(id: testId).overrideWith(
              () => FakeAiImageAnalysisController(initialState: '', id: testId),
            ),
          ],
          child: const AiImageAnalysisView(id: testId),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text(''), findsOneWidget);
  });

  testWidgets('displays analysis results', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestApp(
        ProviderScope(
          overrides: [
            aiImageAnalysisControllerProvider(id: testId).overrideWith(
              () => FakeAiImageAnalysisController(
                initialState: testAnalysis,
                id: testId,
              ),
            ),
          ],
          child: const AiImageAnalysisView(id: testId),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text(testAnalysis), findsOneWidget);
  });
}

class FakeAiImageAnalysisController extends AutoDisposeNotifier<String>
    implements AiImageAnalysisController {
  FakeAiImageAnalysisController({
    required this.initialState,
    required this.id,
  });

  final String initialState;

  @override
  String build({String? id}) => initialState;

  @override
  Future<void> analyzeImage() async {}

  @override
  Future<String> getImage(dynamic image) async => '';

  @override
  String id;
}
