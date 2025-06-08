# AI Features Test Utilities

This directory contains shared test utilities for AI feature tests to reduce code duplication and improve maintainability.

## Shared Test Utilities (`test_utils.dart`)

### Mock Classes
- `MockAiConfigRepository` - Shared mock for AI config repository
- `MockAiConfigByTypeController` - Shared mock for AI config controllers

### Test Data Factory (`AiTestDataFactory`)
Provides factory methods for creating consistent test data:
- `createTestProvider()` - Creates test inference providers
- `createTestModel()` - Creates test AI models  
- `createTestPrompt()` - Creates test AI prompts
- `createMixedTestConfigs()` - Creates a variety of test configurations

### Test Setup Utilities (`AiTestSetup`)
- `registerFallbackValues()` - Registers fallback values for mocktail
- `createTestApp()` - Creates MaterialApp with proper localization
- `createControllerOverrides()` - Creates provider overrides for controllers

### Test Widget Builders (`AiTestWidgets`)
- `createTestWidget()` - Standard test widget with AI config setup

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
