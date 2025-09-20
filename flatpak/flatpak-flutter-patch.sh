#!/bin/bash

# Patch flatpak-flutter to fix the UnboundLocalError

FLATPAK_FLUTTER_DIR="$1"

if [ -z "$FLATPAK_FLUTTER_DIR" ]; then
    FLATPAK_FLUTTER_DIR="./flatpak-flutter"
fi

if [ ! -f "$FLATPAK_FLUTTER_DIR/flutter_app_fetcher/flutter_app_fetcher.py" ]; then
    echo "Error: flatpak-flutter not found at $FLATPAK_FLUTTER_DIR"
    exit 1
fi

echo "Patching flatpak-flutter to fix UnboundLocalError..."

# Skip if already patched (presence of our initialization line)
if grep -q "tag = None  # Initialize tag" "$FLATPAK_FLUTTER_DIR/flutter_app_fetcher/flutter_app_fetcher.py"; then
  echo "Patch already applied; skipping."
  exit 0
fi

# Create a patch to initialize tag variable
cat > /tmp/flatpak-flutter.patch << 'EOF'
--- a/flutter_app_fetcher/flutter_app_fetcher.py
+++ b/flutter_app_fetcher/flutter_app_fetcher.py
@@ -99,6 +99,7 @@ def _process_sources(module, fetch_path: str, releases_path: str) -> Optional[s
     sources = module['sources']
     idxs = []
     repos = []
+    tag = None  # Initialize tag to avoid UnboundLocalError

     for idx, source in enumerate(sources):
         if 'type' in source:
@@ -131,7 +132,8 @@ def _process_sources(module, fetch_path: str, releases_path: str) -> Optional[s

     _fetch_repos(repos)

-    for patch in glob.glob(f'{releases_path}/{tag}/*.flutter.patch'):
+    # Only look for patches if we have a Flutter SDK tag
+    for patch in glob.glob(f'{releases_path}/{tag}/*.flutter.patch') if tag else []:
         shutil.copyfile(patch, Path(patch).name)

     for source in sources:
EOF

# Apply the patch
cd "$FLATPAK_FLUTTER_DIR"
# Apply forward-only to avoid reverse prompts
patch -p1 --forward < /tmp/flatpak-flutter.patch || echo "Patch may already be applied."

echo "Patch applied successfully!"
