#!/usr/bin/env python3
"""
Download Gemma 3n models for local inference.

Usage:
    python download_model.py          # Downloads E2B (default)
    python download_model.py E4B      # Downloads E4B variant
    python download_model.py both     # Downloads both variants
"""

import os
import sys
import argparse
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print("Error: Required packages not installed.")
    print("Please run: pip install huggingface_hub tqdm")
    sys.exit(1)


def download_model(variant="E2B", token=None, revision=None):
    """Download a specific Gemma 3n model variant.

    Args:
        variant: Model variant ('E2B' or 'E4B')
        token: Optional HuggingFace token
        revision: Optional revision/commit hash for security (defaults to 'main')
    """

    # Construct model ID
    model_id = f"google/gemma-3n-{variant}-it"

    # Use provided revision or environment variable or default to 'main' for security
    if not revision:
        model_key = model_id.replace("/", "_").replace("-", "_").upper()
        env_key = f"{model_key}_REVISION"
        revision = os.environ.get(env_key) or os.environ.get("GEMMA_MODEL_REVISION", "main")

    # Setup paths (matching the server's expected location)
    cache_dir = os.path.expanduser("~/.cache/gemma-local/models")
    local_dir = os.path.join(cache_dir, model_id.replace("/", "--"))

    print(f"\n📦 Downloading {model_id}...")
    print(f"📂 Destination: {local_dir}")
    print(f"🔒 Revision: {revision} (pinned for security)")

    # Check if already exists
    if os.path.exists(local_dir) and any(Path(local_dir).glob("*.safetensors")):
        print(f"✅ Model {model_id} already downloaded!")
        return local_dir

    try:
        # Download the model
        print("⏳ This may take a while depending on your internet speed...")
        print(f"   Model size: {'~5.4GB' if variant == 'E2B' else '~9.2GB'}")

        path = snapshot_download(  # nosec B615 - revision pinned to main branch
            repo_id=model_id,
            revision=revision,  # Pin to specific revision for security
            cache_dir=cache_dir,
            local_dir=local_dir,
            local_dir_use_symlinks=False,
            resume_download=True,
            token=token,  # Optional HuggingFace token
            ignore_patterns=["*.md", "*.txt"],  # Skip unnecessary files
        )

        print(f"✅ Successfully downloaded {model_id}")
        print(f"📍 Location: {path}")
        return path

    except Exception as e:
        print(f"❌ Failed to download {model_id}")
        print(f"   Error: {e}")

        if "401" in str(e) or "403" in str(e):
            print("\n💡 Tip: This model might require authentication.")
            print("   1. Create a HuggingFace account at https://huggingface.co")
            print("   2. Get your token from https://huggingface.co/settings/tokens")
            print("   3. Run: python download_model.py --token YOUR_TOKEN")

        return None


def main():
    parser = argparse.ArgumentParser(
        description="Download Gemma 3n models for local inference",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python download_model.py              # Download E2B (smaller, faster)
  python download_model.py E4B          # Download E4B (larger, better quality)
  python download_model.py both         # Download both variants
  python download_model.py --token xyz  # Use HuggingFace token if needed
        """,
    )

    parser.add_argument(
        "variant",
        nargs="?",
        default="E2B",
        choices=["E2B", "E4B", "both"],
        help="Model variant to download (default: E2B)",
    )

    parser.add_argument("--token", help="HuggingFace API token (if required for model access)", default=None)

    parser.add_argument(
        "--revision",
        help="Specific model revision/commit hash for security (default: main)",
        default=None,
    )

    args = parser.parse_args()

    print("🎯 Gemma 3n Model Downloader")
    print("=" * 40)

    # Determine which models to download
    variants_to_download = []
    if args.variant.lower() == "both":
        variants_to_download = ["E2B", "E4B"]
    else:
        variants_to_download = [args.variant.upper()]

    # Download each variant
    success_count = 0
    for variant in variants_to_download:
        result = download_model(variant, args.token, args.revision)
        if result:
            success_count += 1

    # Summary
    print("\n" + "=" * 40)
    if success_count == len(variants_to_download):
        print("✅ All models downloaded successfully!")
        print("\n🚀 You can now start the server with:")
        print("   ./start_server.sh                    # For E2B")
        print("   GEMMA_MODEL_VARIANT=E4B ./start_server.sh  # For E4B")
    else:
        print(f"⚠️  Downloaded {success_count}/{len(variants_to_download)} models")
        print("\nIf download failed, check:")
        print("  1. Internet connection")
        print("  2. Disk space (E2B: ~5.4GB, E4B: ~9.2GB)")
        print("  3. HuggingFace access (some models need authentication)")


if __name__ == "__main__":
    main()
