# AI Features Test Utilities

This directory contains shared test utilities for AI feature tests to reduce code duplication and improve maintainability.

## Shared Test Utilities (`test_utils.dart`)

### Mock Classes
- `MockAiConfigByTypeController` - Shared mock for AI config controllers (the only mock class defined in `test_utils.dart`)
- `MockAiConfigRepository` - Defined in `test/mocks/mocks.dart`; `test_utils.dart` only re-exports it for backward compatibility. New consumers should import it directly from `test/mocks/mocks.dart`.

### Test Ref Provider (`testRefProvider`)
- `testRefProvider` - A `Provider<Ref>` that returns the `Ref` it is built with. In Riverpod 3.x `Ref` is sealed and cannot be mocked, so tests obtain a real `Ref` by reading this provider from a `ProviderContainer`.

### Test Data Factory (`AiTestDataFactory`)
Provides factory methods for creating consistent test data:
- `createTestProvider()` - Creates test inference providers (`AiConfigInferenceProvider`)
- `createTestModel()` - Creates test AI models (`AiConfigModel`)
- `createTestPrompt()` - Creates test AI prompts (`AiConfigPrompt`)
- `createTestProfile()` - Creates test inference profiles (`AiConfigInferenceProfile`)
- `createTestSkill()` - Creates test skills (`AiConfigSkill`)
- `createMixedTestConfigs()` - Creates a variety of test configurations

### Test Setup Utilities (`AiTestSetup`)
- `registerFallbackValues()` - Registers fallback values for mocktail
- `createTestApp()` - Creates MaterialApp with proper localization
- `createControllerOverrides()` - Creates provider overrides for controllers

### Test Widget Builders (`AiTestWidgets`)
- `createTestWidget()` - Standard test widget with AI config setup

### Checklist Test Data Factory (`ChecklistTestDataFactory`)
Factory shared by the checklist function-handler tests
(`functions/lotti_checklist_update_handler_test.dart`,
`functions/lotti_batch_checklist_handler_test.dart`):
- `createTask()` - Creates a `Task` entity
- `createChecklistItem()` - Creates a `ChecklistItem` entity
- `createChecklistItemData()` - Creates `ChecklistItemData`
- `createToolCall()` - Creates a `ChatCompletionMessageToolCall`

## Usage Example

```dart
import '../../test_utils.dart';

void main() {
  group('My AI Test', () {
    setUpAll(() {
      AiTestSetup.registerFallbackValues();
    });

    testWidgets('test description', (WidgetTester tester) async {
      final testData = AiTestDataFactory.createMixedTestConfigs();
      
      await tester.pumpWidget(
        AiTestSetup.createTestApp(
          providerOverrides: AiTestSetup.createControllerOverrides(
            providers: testData.whereType<AiConfigInferenceProvider>().toList(),
          ),
          child: MyWidget(),
        ),
      );
      
      // Test assertions...
    });
  });
}
```

## Benefits
- Reduces code duplication across 25+ test files
- Provides consistent test data creation
- Simplifies test setup and teardown
- Centralizes mock class definitions
- Improves test maintainability

## Migration
Test files should gradually migrate to use these shared utilities instead of duplicating mock classes and test setup code.
