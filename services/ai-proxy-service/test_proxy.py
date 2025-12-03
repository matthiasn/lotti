#!/usr/bin/env python3
"""Quick test script for the AI proxy service"""

import os
import httpx
import asyncio


async def test_health():
    """Test health endpoint"""
    print("\n🏥 Testing health endpoint...")
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get("http://localhost:8002/health")
            print(f"✅ Status: {response.status_code}")
            print(f"   Response: {response.json()}")
        except Exception as e:
            print(f"❌ Error: {e}")
            print("   Make sure the service is running: python -m uvicorn src.main:app --port 8002")


async def test_chat_completion():
    """Test chat completion endpoint"""
    print("\n💬 Testing chat completion...")
    api_key = os.getenv("API_KEYS", "").split(",")[0].strip()
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(
                "http://localhost:8002/v1/chat/completions",
                json={
                    "model": "gemini-pro",
                    "messages": [{"role": "user", "content": "Say 'Hello from AI Proxy!' and nothing else."}],
                    "temperature": 0.1,
                    "user_id": "test@example.com",
                },
                headers={"Authorization": f"Bearer {api_key}"},
            )
            print(f"✅ Status: {response.status_code}")

            if response.status_code == 200:
                data = response.json()
                print(f"   Model: {data['model']}")
                print(f"   Response: {data['choices'][0]['message']['content']}")
                print(f"   Usage: {data['usage']['total_tokens']} tokens")
            else:
                print(f"   Error: {response.text}")

        except Exception as e:
            print(f"❌ Error: {e}")


async def test_model_mapping():
    """Test that gpt-4 maps to gemini"""
    print("\n🔄 Testing model mapping (gpt-4 → gemini)...")
    api_key = os.getenv("API_KEYS", "").split(",")[0].strip()
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(
                "http://localhost:8002/v1/chat/completions",
                json={
                    "model": "gpt-4",  # Should map to gemini-1.5-pro
                    "messages": [{"role": "user", "content": "Say 'test' and nothing else."}],
                    "temperature": 0.1,
                    "user_id": "test@example.com",
                },
                headers={"Authorization": f"Bearer {api_key}"},
            )
            print(f"✅ Status: {response.status_code}")

            if response.status_code == 200:
                data = response.json()

                print("   Requested model: gpt-4")
                print(f"   Returned model: {data['model']}")
                print(f"   Response: {data['choices'][0]['message']['content']}")
            else:
                print(f"   Error: {response.text}")

        except Exception as e:
            print(f"❌ Error: {e}")


async def main():
    print("🧪 AI Proxy Service Test Suite")
    print("=" * 50)

    # Check if API keys are set
    gemini_key = os.getenv("GEMINI_API_KEY")
    auth_key = os.getenv("API_KEYS", "").split(",")[0].strip()

    if not gemini_key:
        print("\n⚠️  WARNING: GEMINI_API_KEY not found in environment")
        print("   Make sure to set it in .env file or export it")
        print("   Example: export GEMINI_API_KEY='your-key-here'")

    if not auth_key:
        print("\n⚠️  WARNING: API_KEYS not found in environment")
        print("   Make sure to set it in .env file or export it")
        print("   Example: export API_KEYS='your-auth-key-here'")

    # Run tests
    await test_health()

    if gemini_key and auth_key:
        await test_chat_completion()
        await test_model_mapping()
    else:
        print("\n⏭️  Skipping AI tests (missing GEMINI_API_KEY or API_KEYS)")

    print("\n" + "=" * 50)
    print("✅ Tests complete!")


if __name__ == "__main__":
    asyncio.run(main())
