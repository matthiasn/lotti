# AI Proxy Testing & Integration Guide

## Part 1: Test the AI Proxy Service Standalone

### Step 1: Add Your Gemini API Key

Edit the `.env` file and add your key:

```bash
cd /Users/gbj/StudioProjects/lotti/services/ai-proxy-service
nano .env
```

Add this line (replace with your actual key):
```
GEMINI_API_KEY=AIzaSyABC123YourActualKeyHere
```

Or use your existing environment variable:
```bash
# If you already have GEMINI_API_KEY exported
echo "GEMINI_API_KEY=$GEMINI_API_KEY" > .env
echo "PORT=8002" >> .env
echo "LOG_LEVEL=INFO" >> .env
```

### Step 2: Install Dependencies

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Step 3: Start the Service

```bash
# Run the service
python -m uvicorn src.main:app --host 0.0.0.0 --port 8002

# Or use the Makefile
make run
```

You should see:
```
INFO - Starting AI Proxy Service...
INFO - AI Proxy Service started successfully
INFO - Uvicorn running on http://0.0.0.0:8002
```

### Step 4: Test It (In a New Terminal)

```bash
# Test 1: Health check
curl http://localhost:8002/health

# Expected: {"status":"healthy"}
```

```bash
# Test 2: Chat completion
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-pro",
    "messages": [
      {"role": "user", "content": "Say hello and tell me your name!"}
    ],
    "user_id": "test@example.com"
  }'

# Expected: You'll get an AI response + billing will be logged
```

### Step 5: Check the Logs

In the terminal where the service is running, you should see:
```
💰 BILLING | User: test@example.com | Model: gemini-pro |
Tokens: 15 input + 25 output = 40 total | Cost: $0.000015 USD
```

### Step 6: Run Automated Tests

```bash
# Using the test script
python test_proxy.py

# Or run the test suite
make test
```

---

## Part 2: Integrate with Lotti Flutter App

Good news! Lotti already supports OpenAI-compatible APIs through the `CloudInferenceRepository`.

### Option A: Use as OpenAI Provider

In the Lotti app settings:

1. Go to **AI Settings** (or wherever you configure AI providers)
2. Add a new **OpenAI** provider with these settings:
   - **Base URL**: `http://localhost:8002/v1`
   - **API Key**: `dummy` (the proxy ignores this)
   - **Model**: `gpt-4` or `gemini-pro`

The proxy will:
- Ignore the dummy API key
- Use its own real Gemini key (from .env)
- Map `gpt-4` → `gemini-1.5-pro`
- Return responses in OpenAI format

### Option B: Code Integration

If you want to create a dedicated provider, here's how:

**File: `lib/features/ai/repository/ai_proxy_inference_repository.dart`**

```dart
import 'package:openai_dart/openai_dart.dart';

class AiProxyInferenceRepository {
  AiProxyInferenceRepository({
    required this.baseUrl,
    this.apiKey = 'dummy', // Proxy ignores this
  });

  final String baseUrl;
  final String apiKey;

  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    String? systemMessage,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    String? userId,
  }) async* {
    // Create OpenAI client pointing to our proxy
    final client = OpenAIClient(
      apiKey: apiKey,
      baseUrl: baseUrl,
    );

    final messages = <ChatCompletionMessage>[
      if (systemMessage != null)
        ChatCompletionMessage.system(content: systemMessage),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(prompt),
      ),
    ];

    final request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model),
      messages: messages,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      stream: true,
      tools: tools,
    );

    final stream = client.createChatCompletionStream(request: request);

    await for (final response in stream) {
      yield response;
    }
  }
}
```

**Then in your provider setup:**

```dart
final aiProxyProvider = Provider((ref) {
  return AiProxyInferenceRepository(
    baseUrl: 'http://localhost:8002/v1',
    apiKey: 'dummy',
  );
});
```

---

## Part 3: Testing the Full Integration

### Test 1: Lotti → AI Proxy → Gemini

1. Start the AI Proxy service:
   ```bash
   cd services/ai-proxy-service
   source venv/bin/activate
   make run
   ```

2. Start Lotti:
   ```bash
   flutter run
   ```

3. In Lotti, use any AI feature (e.g., "Summarize this journal entry")

4. Watch the AI Proxy logs - you should see:
   ```
   INFO - Chat completion request received
   💰 BILLING | User: your-user-id | Cost: $0.000025 USD
   INFO - Chat completion successful
   ```

### Test 2: Model Mapping

Try these models in Lotti:
- `gpt-4` → proxied to `gemini-1.5-pro`
- `gpt-3.5-turbo` → proxied to `gemini-1.5-flash`
- `gemini-pro` → proxied to `gemini-1.5-pro`

All should work seamlessly!

---

## Troubleshooting

### "GEMINI_API_KEY environment variable is required"

Make sure you added the key to `.env`:
```bash
cat .env | grep GEMINI_API_KEY
```

Should output:
```
GEMINI_API_KEY=AIzaSy...
```

### "Connection refused" from Lotti

Make sure the AI Proxy is running:
```bash
curl http://localhost:8002/health
```

If it fails, start the service:
```bash
cd services/ai-proxy-service
make run
```

### CORS Errors

If Lotti runs on a different origin, update `.env`:
```
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost:YOUR_PORT
```

Then restart the service.

### No Billing Logs

Check that you're passing `user_id` in the request:
```json
{
  "model": "gemini-pro",
  "messages": [...],
  "user_id": "your-email@example.com"  // ← Make sure this is included
}
```

---

## What's Next?

### Phase 2: Integrate with Credits Service

Once tested, uncomment the TODO in `billing_service.py:67-79` to actually bill users via the Credits Service:

```python
# Call credits service to bill the user
async with httpx.AsyncClient() as client:
    response = await client.post(
        f"http://localhost:8001/api/v1/bill",
        json={
            "user_id": metadata.user_id,
            "amount": float(metadata.estimated_cost_usd),
            "description": f"{metadata.model} - {metadata.total_tokens} tokens",
        },
    )
```

This will:
1. Check user has enough balance
2. Deduct from their TigerBeetle account
3. Return 402 Payment Required if insufficient funds

---

## Docker Deployment (Optional)

```bash
# Build and run with Docker
cd services/ai-proxy-service
make docker-build
make docker-up

# View logs
make docker-logs

# Stop
make docker-down
```

The service will run on port 8002.
