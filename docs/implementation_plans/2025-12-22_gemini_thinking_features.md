# Gemini Thinking Features Implementation Plan

## Overview

Implement Gemini-specific thinking/reasoning features including thought summaries, thought signatures for multi-turn conversations, and usage statistics tracking. All changes must be modular and not break other providers.

**Target Models:** Gemini 3 Flash and Gemini 3 Pro 

---

## Current State Analysis

### What Works
- `GeminiThinkingConfig` exists with `thinkingBudget` and `includeThoughts` flags
- `gemini_inference_repository.dart` parses `thought: true` parts from Gemini responses
- Thoughts are wrapped in `<thinking>...</thinking>` tags during streaming
- "Thoughts" tab exists in UI (`ai_response_summary_modal.dart`)

### Critical Bug Found
**The thoughts extraction is broken!**
- Gemini repository emits: `<thinking>\n...\n</thinking>\n`
- `unified_ai_inference_repository.dart` looks for: `</think>` (line 805)
- This mismatch means Gemini thoughts are never extracted!

### Not Implemented
- Thought signatures (for multi-turn function calling)
- Usage statistics (`usageMetadata` parsing)
- `thoughts_token_count` tracking

---

## Implementation Plan

### Phase 1: Fix Thought Extraction (Bug Fix)

**Problem:** Gemini returns thoughts as separate parts with `thought: true` boolean, but the current code:
1. Wraps thoughts in `<thinking>` XML tags during streaming (`gemini_inference_repository.dart:244`)
2. Later tries to extract them using `</think>` tag mismatch (`unified_ai_inference_repository.dart:809`)

**Current Flow (Broken):**
```
Gemini API → thought: true part → wrap in <thinking> tags → emit as content delta → try to extract with </think> → FAIL
```

**Fix (Option A - For Now):**

**File:** `lib/features/ai/repository/unified_ai_inference_repository.dart`

Fix the tag mismatch to handle both `<thinking>` (Gemini) and `<think>` (OpenAI o1) formats:
```dart
// Check for both formats
if (response.contains('</thinking>')) {
  final match = RegExp(r'<thinking>\n?(.*?)\n?</thinking>\n?', dotAll: true).firstMatch(response);
  if (match != null) {
    thoughts = match.group(1) ?? '';
    cleanResponse = response.replaceFirst(match.group(0)!, '');
  }
} else if (response.contains('</think>')) {
  // OpenAI o1 format fallback
  final parts = response.split('</think>');
  if (parts.length == 2) {
    thoughts = parts[0].replaceFirst('<think>', '');
    cleanResponse = parts[1];
  }
}
```

**Future Improvement (Option B - Later):**
Pass thoughts as a separate field through the pipeline instead of embedding in content:
1. Don't wrap thoughts in XML tags in `gemini_inference_repository.dart`
2. Use a wrapper type that includes both content and thoughts fields
3. Accumulate thoughts separately from content in streaming consumer
4. Pass thoughts directly without XML extraction

---

### Phase 2: Add Usage Statistics Support

#### 2.1 Extend Data Model

**File:** `lib/classes/entity_definitions.dart`

Add new fields to `AiResponseData`:
```dart
@freezed
abstract class AiResponseData with _$AiResponseData {
  const factory AiResponseData({
    required String model,
    required String systemMessage,
    required String prompt,
    required String thoughts,
    required String response,
    String? promptId,
    List<AiActionItem>? suggestedActionItems,
    AiResponseType? type,
    double? temperature,
    // NEW: Usage statistics (nullable for backward compatibility)
    int? inputTokens,
    int? outputTokens,
    int? thoughtsTokens,  // Gemini-specific reasoning tokens
    int? cachedInputTokens,
  }) = _AiResponseData;
}
```

After modifying, run: `fvm dart run build_runner build --delete-conflicting-outputs`

#### 2.2 Parse Usage Metadata from Gemini Response

**File:** `lib/features/ai/repository/gemini_inference_repository.dart`

The Gemini response includes `usageMetadata` at the response level. Add parsing logic:
```dart
// In the response parsing, look for usageMetadata
if (responseBody['usageMetadata'] is Map<String, dynamic>) {
  final usage = responseBody['usageMetadata'] as Map<String, dynamic>;
  final promptTokens = usage['promptTokenCount'] as int?;
  final candidatesTokens = usage['candidatesTokenCount'] as int?;
  final thoughtsTokens = usage['thoughtsTokenCount'] as int?;
  final cachedTokens = usage['cachedContentTokenCount'] as int?;
  // Emit or store these values
}
```

#### 2.3 Create Usage Data Container

**File:** `lib/features/ai/model/inference_usage.dart` (NEW)

```dart
class InferenceUsage {
  const InferenceUsage({
    this.inputTokens,
    this.outputTokens,
    this.thoughtsTokens,
    this.cachedInputTokens,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? thoughtsTokens;
  final int? cachedInputTokens;

  int get totalTokens => (inputTokens ?? 0) + (outputTokens ?? 0);
}
```

#### 2.4 Propagate Usage Through the Stack

**Files to modify:**
1. `gemini_inference_repository.dart` - Parse and return usage
2. `cloud_inference_repository.dart` - Pass through usage
3. `unified_ai_inference_repository.dart` - Capture and save usage
4. `ai_input_repository.dart` - Include in `AiResponseEntry`

#### 2.5 Display Usage in UI

**File:** `lib/features/ai/ui/settings/ai_response_summary_modal.dart`

Add a "Usage" section to the modal showing token counts:
```dart
// In the Setup tab or as a new tab
if (aiResponse.data.inputTokens != null) {
  ListTile(
    title: Text('Token Usage'),
    subtitle: Text(
      'Input: ${aiResponse.data.inputTokens}, '
      'Output: ${aiResponse.data.outputTokens}, '
      'Thoughts: ${aiResponse.data.thoughtsTokens ?? "N/A"}'
    ),
  ),
}
```

---

### Phase 3: Thought Signatures for Multi-Turn Conversations

**Scope:** Full implementation for Gemini 3 Flash/Pro function calling.

According to Gemini documentation:
- First function call in each step must include `thought_signature`
- Signatures appear in `extra_content.google.thought_signature` (OpenAI-compat mode)
- Omitting signatures causes 400 validation errors for Gemini 3 models

#### 3.1 Create Thought Signature Data Model

**File:** `lib/features/ai/model/thought_signature.dart` (NEW)

```dart
/// Represents a thought signature from Gemini 3 models.
/// Required for multi-turn function calling to maintain reasoning context.
class ThoughtSignature {
  const ThoughtSignature({
    required this.signature,
    required this.toolCallId,
    this.turnIndex,
  });

  /// The encrypted signature string from Gemini
  final String signature;

  /// The tool call ID this signature is associated with
  final String toolCallId;

  /// Which turn in the conversation this belongs to
  final int? turnIndex;
}
```

#### 3.2 Capture Signatures from Gemini Responses

**File:** `lib/features/ai/repository/gemini_inference_repository.dart`

Modify function call parsing (around line 293-328) to extract signatures:

```dart
// In the function call extraction section
if (p['functionCall'] is Map<String, dynamic>) {
  final fc = p['functionCall'] as Map<String, dynamic>;
  final name = fc['name']?.toString() ?? '';
  final args = jsonEncode(fc['args'] ?? {});

  // NEW: Extract thought signature if present
  String? thoughtSignature;
  if (fc['thoughtSignature'] is String) {
    thoughtSignature = fc['thoughtSignature'] as String;
  }

  // Emit with signature attached (using extra field or custom extension)
  yield CreateChatCompletionStreamResponse(
    // ... existing code ...
    // Include signature in response metadata
  );
}
```

#### 3.3 Store Signatures in Conversation Manager

**File:** `lib/features/ai/conversation/conversation_manager.dart`

Add signature tracking:

```dart
class ConversationManager {
  final List<ChatCompletionMessage> _messages = [];

  // NEW: Track signatures for each assistant response with tool calls
  final Map<String, String> _thoughtSignatures = {}; // toolCallId -> signature

  void addAssistantMessageWithSignature({
    String? content,
    List<ChatCompletionMessageToolCall>? toolCalls,
    Map<String, String>? signatures, // NEW: toolCallId -> signature
  }) {
    if (signatures != null) {
      _thoughtSignatures.addAll(signatures);
    }
    // ... existing logic
  }

  /// Get signature for a specific tool call
  String? getSignatureForToolCall(String toolCallId) => _thoughtSignatures[toolCallId];

  /// Get all signatures for building subsequent requests
  Map<String, String> get allSignatures => Map.unmodifiable(_thoughtSignatures);
}
```

#### 3.4 Pass Signatures in Subsequent Requests

**File:** `lib/features/ai/repository/gemini_utils.dart`

Update `buildRequestBody()` to include signatures when replaying history:

```dart
static Map<String, dynamic> buildRequestBody({
  required String prompt,
  required double temperature,
  required GeminiThinkingConfig thinkingConfig,
  String? systemMessage,
  int? maxTokens,
  List<ChatCompletionTool>? tools,
  List<ChatCompletionMessage>? messages, // NEW: Full conversation history
  Map<String, String>? thoughtSignatures, // NEW: Signatures to include
}) {
  // When building contents array from messages...
  // For assistant messages with tool calls, include signatures:
  // {
  //   "role": "model",
  //   "parts": [{
  //     "functionCall": {
  //       "name": "...",
  //       "args": {...},
  //       "thoughtSignature": "<signature>" // Include if available
  //     }
  //   }]
  // }
}
```

#### 3.5 Update Conversation Repository

**File:** `lib/features/ai/conversation/conversation_repository.dart`

Capture signatures when processing responses (around lines 107-220):

```dart
// After accumulating tool calls, extract signatures
final signatures = <String, String>{};
for (final tc in toolCalls) {
  // Extract signature from response metadata if present
  if (tc.extraContent?.google?.thoughtSignature != null) {
    signatures[tc.id] = tc.extraContent!.google!.thoughtSignature!;
  }
}

manager.addAssistantMessageWithSignature(
  content: textBuffer.toString(),
  toolCalls: toolCalls,
  signatures: signatures,
);
```

#### 3.6 Integration Points Summary

| Step | File | Action |
|------|------|--------|
| 1 | `gemini_inference_repository.dart:293-328` | Extract `thoughtSignature` from function calls |
| 2 | `conversation_manager.dart:63-86` | Store signatures with assistant messages |
| 3 | `conversation_repository.dart:107-220` | Capture signatures during streaming |
| 4 | `gemini_utils.dart:81-133` | Include signatures in request body |
| 5 | `lotti_conversation_processor.dart:244` | Pass signatures through strategy processing |

---

## File Change Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/features/ai/repository/unified_ai_inference_repository.dart` | Modify | Fix `<thinking>` tag extraction |
| `lib/classes/entity_definitions.dart` | Modify | Add usage fields to `AiResponseData` |
| `lib/features/ai/model/inference_usage.dart` | Create | New usage data container |
| `lib/features/ai/model/thought_signature.dart` | Create | Thought signature model |
| `lib/features/ai/repository/gemini_inference_repository.dart` | Modify | Parse `usageMetadata` and `thoughtSignature` |
| `lib/features/ai/repository/gemini_utils.dart` | Modify | Include signatures in request body |
| `lib/features/ai/conversation/conversation_manager.dart` | Modify | Store thought signatures |
| `lib/features/ai/conversation/conversation_repository.dart` | Modify | Capture signatures from responses |
| `lib/features/ai/repository/cloud_inference_repository.dart` | Modify | Pass through usage data |
| `lib/features/ai/ui/settings/ai_response_summary_modal.dart` | Modify | Display usage stats |
| Associated test files | Modify | Update tests for new functionality |

---

## Implementation Order

1. **Phase 1:** Fix thought extraction bug (immediate win, enables Thoughts tab)
2. **Phase 2.1-2.3:** Add data models (usage + signatures)
3. **Phase 2.4-2.5:** Parse and propagate usage from Gemini
4. **Phase 3.1-3.3:** Capture and store thought signatures
5. **Phase 3.4-3.5:** Pass signatures in multi-turn requests
6. **UI:** Display usage stats in response modal

---

## Testing Strategy

1. Unit tests for thought extraction regex
2. Unit tests for usage metadata parsing
3. Integration tests with mock Gemini responses
4. Verify backward compatibility (old entries without usage fields still work)

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Breaking other providers | All Gemini-specific code isolated; usage fields nullable |
| Database migration | New fields are nullable, no migration needed |
| Build runner issues | Run regeneration after entity changes |
| Test failures | Update test expectations for new fields |

---

## Decisions Made

- **Thought signatures:** Full implementation for Gemini 3 Flash/Pro (required for multi-turn function calling)
- **Usage stats location:** Will be displayed in AI response modal
- **Backward compatibility:** All new fields are nullable
