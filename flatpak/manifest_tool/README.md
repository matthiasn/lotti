# Manifest Tool

A Python utility suite for manipulating Flatpak manifests, specifically designed for preparing Flutter applications for Flathub submission.

## Overview

The `manifest_tool` is a collection of Python modules that automate the complex process of converting a Flutter application with network dependencies into a fully offline Flatpak build suitable for Flathub. It handles manifest manipulation, source bundling, dependency resolution, and various Flutter-specific requirements.

## Architecture

```
manifest_tool/
├── cli.py                 # Command-line interface
├── manifest.py            # Core manifest document handling
├── manifest_ops.py        # Basic manifest operations
├── manifest_ops_helpers.py # Helper functions for manifest ops
├── flutter_ops.py         # Flutter-specific operations
├── sources_ops.py         # Source manipulation operations
├── sources_ops_yaml.py    # YAML source generation
├── ci_ops.py             # CI/CD specific operations
├── build_utils.py        # Build utilities
├── update_manifest.py    # Legacy manifest update functions
├── utils.py              # General utilities
└── tests/                # Comprehensive test suite
```

## Installation

No installation required - the tool is designed to work with system Python 3:

```bash
# For development with tests:
cd flatpak
python3 -m venv .venv
source .venv/bin/activate
pip install pytest pyyaml
```

## Command-Line Interface

The tool provides a CLI with multiple subcommands:

```bash
python3 manifest_tool/cli.py <command> [options]
```

### Available Commands

#### Core Manifest Operations

**pin-commit**
```bash
python3 manifest_tool/cli.py pin-commit \
  --manifest input.yml \
  --commit abc123def \
  --output output.yml
```
Replaces `COMMIT_PLACEHOLDER` with actual commit hash.

**update-app-version**
```bash
python3 manifest_tool/cli.py update-app-version \
  --manifest input.yml \
  --version 1.0.0
```
Updates the application version in the manifest.

**update-release-info**
```bash
python3 manifest_tool/cli.py update-release-info \
  --manifest input.yml \
  --version 1.0.0 \
  --date 2025-01-28 \
  --commit abc123def
```
Updates version, date, and commit information.

#### Flutter-Specific Operations

**copy-flutter-sdk**
```bash
python3 manifest_tool/cli.py copy-flutter-sdk \
  --manifest input.yml \
  --work-dir ./work \
  --flutter-dir ./flutter
```
Copies Flutter SDK for offline use.

**ensure-offline-flutter**
```bash
python3 manifest_tool/cli.py ensure-offline-flutter \
  --manifest input.yml
```
Ensures Flutter build commands use offline flags:
- Adds `--offline` to `flutter pub get`
- Adds `--no-pub` to `flutter build`

**remove-network-from-build**
```bash
python3 manifest_tool/cli.py remove-network-from-build \
  --manifest input.yml
```
Removes `--share=network` from build arguments (Flathub requirement).

**ensure-rust-sdk-env**
```bash
python3 manifest_tool/cli.py ensure-rust-sdk-env \
  --manifest input.yml
```
Configures Rust SDK environment variables.

**remove-rustup-install**
```bash
python3 manifest_tool/cli.py remove-rustup-install \
  --manifest input.yml
```
Removes rustup installation from manifest (uses SDK extension instead).

#### Plugin Dependency Handlers

**add-media-kit-mimalloc-source**
```bash
python3 manifest_tool/cli.py add-media-kit-mimalloc-source \
  --manifest input.yml
```
Adds mimalloc source for media_kit_libs_linux plugin to prevent network download during build.

**add-sqlite3-source**
```bash
python3 manifest_tool/cli.py add-sqlite3-source \
  --manifest input.yml
```
Adds SQLite source for sqlite3_flutter_libs plugin for both x86_64 and aarch64.

#### Source Operations

**bundle-archive-sources**
```bash
python3 manifest_tool/cli.py bundle-archive-sources \
  --manifest input.yml \
  --output-dir ./output \
  --download-missing \
  --search-root ./.flatpak-builder/downloads
```
Bundles all archive and file sources locally:
- Downloads missing sources
- Updates manifest with local paths
- Verifies checksums
- Searches multiple cache locations

**make-yaml-source-from-git**
```bash
python3 manifest_tool/cli.py make-yaml-source-from-git \
  --repo-url https://github.com/user/repo \
  --ref-or-commit main \
  --output sources.yml
```
Creates YAML source definition from git repository.

**make-yaml-source-from-dir**
```bash
python3 manifest_tool/cli.py make-yaml-source-from-dir \
  --directory ./source \
  --output sources.yml
```
Creates YAML source definition from local directory.

#### CI/CD Operations

**remove-skip-ci-from-commit**
```bash
python3 manifest_tool/cli.py remove-skip-ci-from-commit \
  --manifest input.yml \
  --ref-name feature-branch
```
Removes CI skip markers and updates branch reference.

**bundle-app-archive**
```bash
python3 manifest_tool/cli.py bundle-app-archive \
  --manifest input.yml \
  --source-dir ./app \
  --output-dir ./output \
  --commit abc123def
```
Creates app source archive for offline build.

## Module Details

### manifest.py - Core Document Handling

```python
from manifest_tool.manifest import ManifestDocument

# Load manifest
doc = ManifestDocument.load("manifest.yml")

# Access data
modules = doc.ensure_modules()

# Check if changed
if doc.changed:
    doc.save("output.yml")
```

**Key Features:**
- Safe YAML loading/saving
- Change tracking
- Module management
- Validation helpers

### flutter_ops.py - Flutter Operations

Handles Flutter-specific requirements:

```python
from manifest_tool import flutter_ops

# Ensure offline build
result = flutter_ops.ensure_offline_flutter_build(doc)

# Add plugin dependencies
result = flutter_ops.add_media_kit_mimalloc_source(doc)
result = flutter_ops.add_sqlite3_source(doc)
```

**Operations:**
- Offline flag management
- Plugin dependency handling
- Flutter SDK configuration
- Build command modifications

### sources_ops.py - Source Management

```python
from manifest_tool import sources_ops

# Bundle sources for offline build
result = sources_ops.bundle_archive_and_file_sources(
    doc,
    output_dir=Path("output"),
    download_missing=True,
    search_roots=[Path(".cache")]
)
```

**Capabilities:**
- Download and cache sources
- Update manifest paths
- Checksum verification
- Multi-location search

### Operation Results

All operations return `OperationResult`:

```python
class OperationResult:
    changed: bool        # Whether manifest was modified
    messages: List[str]  # Operation details

# Usage
result = some_operation(doc)
if result.changed:
    print(f"Changes: {', '.join(result.messages)}")
```

## Testing

Comprehensive test suite with 121+ tests:

```bash
# Run all tests
python -m pytest manifest_tool/tests

# Run specific test file
python -m pytest manifest_tool/tests/test_flutter_ops.py

# Run with coverage
python -m pytest --cov=manifest_tool manifest_tool/tests

# Run specific test
python -m pytest manifest_tool/tests/test_flutter_ops.py::test_add_sqlite3_source -xvs
```

### Test Structure

```
tests/
├── conftest.py              # Shared fixtures
├── test_manifest.py         # Core manifest tests
├── test_manifest_ops.py     # Manifest operation tests
├── test_flutter_ops.py      # Flutter-specific tests
├── test_sources_ops.py      # Source operation tests
├── test_build_utils.py      # Build utility tests
├── test_cli.py             # CLI interface tests
└── test_integration.py      # Integration tests
```

### Writing Tests

```python
def test_new_operation(make_document):
    """Test description."""
    # Create test document
    doc = make_document()

    # Run operation
    result = my_operation(doc)

    # Assert results
    assert result.changed
    assert "expected message" in str(result.messages)

    # Verify idempotency
    result2 = my_operation(doc)
    assert not result2.changed
```

## Code Quality

### Complexity Requirements

All functions must maintain:
- Cyclomatic complexity < 10
- Clear single responsibility
- Comprehensive error handling

Check complexity:
```bash
cd flatpak
./check_complexity.sh
```

### Style Guide

- Use type hints where possible
- Document all public functions
- Follow PEP 8
- Keep functions focused and testable

## Real-World Usage

### In prepare_flathub_submission.sh

The tool is extensively used in the preparation script:

```bash
# Pin commit
python3 "$PYTHON_CLI" pin-commit \
  --manifest "$BASE_MANIFEST" \
  --commit "$COMMIT_HASH" \
  --output "$OUT_MANIFEST"

# Ensure offline build
python3 "$PYTHON_CLI" ensure-offline-flutter \
  --manifest "$OUT_MANIFEST"

# Remove network access
python3 "$PYTHON_CLI" remove-network-from-build \
  --manifest "$OUT_MANIFEST"

# Add plugin sources
python3 "$PYTHON_CLI" add-media-kit-mimalloc-source \
  --manifest "$OUT_MANIFEST"
python3 "$PYTHON_CLI" add-sqlite3-source \
  --manifest "$OUT_MANIFEST"

# Bundle sources
python3 "$PYTHON_CLI" bundle-archive-sources \
  --manifest "$OUT_MANIFEST" \
  --output-dir "$OUTPUT_DIR" \
  --download-missing
```

### In CI/CD Pipeline

Used in GitHub Actions workflow:

```yaml
- name: Prepare Flathub build
  run: |
    cd flatpak
    ./prepare_flathub_submission.sh

- name: Run manifest tests
  run: |
    cd flatpak
    python -m pytest manifest_tool/tests
```

## Common Patterns

### Adding a New Operation

1. Create function in appropriate module:
```python
# In flutter_ops.py
def my_new_operation(document: ManifestDocument) -> OperationResult:
    """Operation description."""
    changed = False
    messages = []

    # Modify manifest
    modules = document.ensure_modules()
    # ... operation logic ...

    if changed:
        document.mark_changed()
        return OperationResult(True, messages)

    return OperationResult.unchanged()
```

2. Register in CLI:
```python
# In cli.py
@cli.command("my-new-operation")
@click.option("--manifest", required=True)
def my_new_operation_cmd(manifest):
    """CLI command description."""
    doc = ManifestDocument.load(Path(manifest))
    result = flutter_ops.my_new_operation(doc)
    # ... handle result ...
```

3. Add test:
```python
# In test_flutter_ops.py
def test_my_new_operation(make_document):
    doc = make_document()
    result = flutter_ops.my_new_operation(doc)
    assert result.changed
    # ... more assertions ...
```

## Plugin Dependency Challenge

### Problem

Flutter plugins using CMake FetchContent violate Flathub's no-network policy:
- `media_kit_libs_linux` → downloads mimalloc
- `sqlite3_flutter_libs` → downloads SQLite

### Solution Architecture

```yaml
# Place files where CMake expects them:
- type: file
  only-arches: [x86_64]
  url: https://source.url/file.tar.gz
  sha256: <hash>
  dest: ./build/linux/x64/release/_deps/...
  dest-filename: expected-name.tar.gz
```

The tool:
1. Identifies plugins needing dependencies
2. Adds source entries to manifest
3. Places files at exact CMake FetchContent locations
4. Handles architecture-specific paths

## Troubleshooting

### Common Issues

**"FileNotFoundError: manifest.yml"**
- Check file path is correct
- Ensure running from correct directory

**"TypeError: manifest.modules must be a list"**
- Manifest structure is invalid
- Check YAML syntax

**Operation not changing manifest**
- Check if operation already applied
- Verify idempotency logic

**Source download failures**
- Check network connectivity
- Verify URLs are accessible
- Check cache directories

### Debug Mode

Enable verbose output:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

Or in CLI:
```bash
PYTHONPATH=. python3 -m manifest_tool.cli --verbose <command>
```

## Future Enhancements

### Planned Features

1. **Parallel source downloads** - Speed up bundling
2. **Dependency graph analysis** - Understand plugin requirements
3. **Manifest validation** - Catch issues early
4. **Source caching improvements** - Better cache management
5. **Plugin auto-detection** - Automatically handle new plugins

### Contributing

When adding new features:
1. Follow existing patterns
2. Add comprehensive tests
3. Update this README
4. Keep complexity low
5. Document thoroughly

## License

Part of the Lotti project. See main project for license details.