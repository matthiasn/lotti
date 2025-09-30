# Gemma Integration Tests

This directory contains comprehensive integration tests for the Gemma 3n local AI transcription service integration with Lotti.

## Test Structure

### Core Integration Tests

1. **`transcription_flow_integration_test.dart`**
   - End-to-end transcription workflows
   - Audio processing with context prompts
   - Error handling and recovery
   - Timeout and retry mechanisms
   - Model validation and switching

2. **`service_discovery_integration_test.dart`**
   - Service health monitoring
   - Port scanning and discovery
   - Version compatibility detection
   - Resource constraint handling
   - Load balancing across instances

3. **`model_management_integration_test.dart`**
   - Model discovery and listing
   - Installation with progress tracking
   - Validation and integrity checks
   - Storage management and cleanup
   - Loading and unloading operations

### Test Infrastructure

- **`mock_gemma_service.dart`**: Controllable mock Gemma service
- **`test_audio_data.dart`**: Sample audio data and utilities

## Running the Tests

### Prerequisites

1. Flutter test environment set up
2. Mock HTTP dependencies available
3. Test data resources in place

### Running Individual Test Suites

```bash
# Run transcription flow tests
flutter test test/integration/gemma/transcription_flow_integration_test.dart

# Run service discovery tests
flutter test test/integration/gemma/service_discovery_integration_test.dart

# Run model management tests
flutter test test/integration/gemma/model_management_integration_test.dart
```

### Running All Gemma Integration Tests

```bash
flutter test test/integration/gemma/
```

## Test Scenarios Covered

### Transcription Workflows
- ✅ Successful audio transcription with context
- ✅ Model not found error → install dialog → retry
- ✅ Service unavailable error handling
- ✅ Timeout handling with graceful degradation
- ✅ Large file chunking and processing
- ✅ Model variant detection and validation
- ✅ Conversational context preservation
- ✅ Retry mechanisms with exponential backoff
- ✅ Malformed response handling

### Service Discovery
- ✅ Default port service detection
- ✅ Multi-port scanning for available services
- ✅ Version compatibility validation
- ✅ Continuous health monitoring
- ✅ Service restart detection
- ✅ Network connectivity issue handling
- ✅ Configuration and capability detection
- ✅ Load balancing across multiple instances

### Model Management
- ✅ Available model discovery from service
- ✅ Model metadata validation
- ✅ Installation with streaming progress
- ✅ Installation error handling and retry
- ✅ Model variant selection (E2B/E4B)
- ✅ Concurrent installation request handling
- ✅ Model integrity validation
- ✅ Corruption detection and remediation
- ✅ Loading and unloading operations
- ✅ Storage analytics and optimization
- ✅ Automatic cleanup of unused models

## Key Integration Points Tested

### Flutter → Python Service Communication
- HTTP API requests with proper headers
- SSE streaming for progress updates
- Error response parsing and handling
- Timeout configuration and enforcement

### UI Integration
- Model install dialog workflows
- Progress indicator updates
- Error state handling and display
- User interaction flows

### Data Flow Validation
- Audio data encoding and transmission
- Response parsing and validation
- Context preservation across requests
- State management during async operations

## Test Design Principles

### Realistic Scenarios
- Tests simulate real-world usage patterns
- Network conditions and failures included
- Resource constraints and limitations tested
- Concurrent operation handling validated

### Comprehensive Coverage
- Happy path and error conditions
- Edge cases and boundary conditions
- Performance under various loads
- Security and validation scenarios

### Maintainable Infrastructure
- Reusable mock services and utilities
- Clear test data organization
- Parameterized test cases where applicable
- Comprehensive documentation

## Known Limitations

### Current Test Gaps
1. **HTTP Client Injection**: Some widgets create their own HTTP clients, limiting mock control
2. **Real Service Integration**: Tests use mocks; consider adding tests with actual service
3. **Performance Testing**: Limited load testing of concurrent operations
4. **Security Testing**: Authentication and encryption testing needed

### Improvement Opportunities
1. **Dependency Injection**: Refactor widgets to accept HTTP clients as parameters
2. **Test Environment**: Set up CI with actual Gemma service instances
3. **Performance Metrics**: Add benchmarking and performance regression detection
4. **Documentation**: Expand test documentation with failure analysis guides

## Debugging Test Failures

### Common Issues
1. **Mock Setup**: Verify mock HTTP client configurations match expected calls
2. **Async Operations**: Ensure proper `pumpAndSettle()` usage for async widgets
3. **Provider Overrides**: Check that provider overrides are correctly configured
4. **Test Data**: Validate test audio data and expected responses

### Debugging Tips
1. Enable verbose test output: `flutter test --verbose`
2. Add debug prints in test setup and teardown
3. Use `tester.binding.transientCallbackCount` to verify async completion
4. Check mock verification failures for unexpected HTTP calls

## Contributing

### Adding New Tests
1. Follow existing test structure and naming conventions
2. Include both positive and negative test cases
3. Add appropriate test documentation
4. Update this README with new test scenarios

### Modifying Existing Tests
1. Ensure backward compatibility with existing test infrastructure
2. Update related tests if changing shared utilities
3. Maintain test isolation and independence
4. Document any breaking changes in test behavior