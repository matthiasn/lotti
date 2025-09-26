#!/usr/bin/env python3
"""
Simple script to run tests and show the modular architecture in action
"""

import subprocess
import sys
import os
from pathlib import Path


def run_command(cmd, description=""):
    """Run a command and print its output"""
    print(f"\n{'='*60}")
    print(f"Running: {description or ' '.join(cmd)}")
    print('='*60)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            cwd=Path(__file__).parent
        )
        print(result.stdout)
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Command failed with exit code {e.returncode}")
        print("STDOUT:")
        print(e.stdout)
        print("STDERR:")
        print(e.stderr)
        return False
    except FileNotFoundError:
        print(f"Command not found: {' '.join(cmd)}")
        return False


def main():
    """Main test runner"""
    print("Gemma Local Service - Modular Architecture Test Runner")
    print("=" * 60)

    # Check if we're in the right directory
    if not (Path.cwd() / 'src').exists():
        print("Error: Please run this script from the services/gemma-local directory")
        sys.exit(1)

    # Set up environment
    os.environ.setdefault('PYTHONPATH', str(Path.cwd()))
    os.environ.setdefault('GEMMA_CACHE_DIR', '/tmp/test-cache')
    os.environ.setdefault('LOG_LEVEL', 'DEBUG')

    tests_to_run = [
        # Code quality checks
        (['python', '-m', 'flake8', 'src', 'tests', '--count', '--max-line-length=127', '--extend-ignore=E203,W503'],
         "Running flake8 linting"),

        # Type checking (basic)
        (['python', '-c', 'print("Type checking placeholder - mypy would run here")'],
         "Type checking (placeholder)"),

        # Unit tests
        (['python', '-m', 'pytest', 'tests/unit', '-v', '--tb=short'],
         "Running unit tests"),

        # Integration tests
        (['python', '-m', 'pytest', 'tests/integration', '-v', '--tb=short'],
         "Running integration tests"),

        # Show test coverage
        (['python', '-m', 'pytest', 'tests/', '--cov=src', '--cov-report=term-missing', '--tb=short'],
         "Running all tests with coverage"),
    ]

    success_count = 0
    for cmd, description in tests_to_run:
        if run_command(cmd, description):
            success_count += 1
            print("✅ PASSED")
        else:
            print("❌ FAILED")

    print(f"\n{'='*60}")
    print(f"Test Summary: {success_count}/{len(tests_to_run)} test suites passed")
    print('='*60)

    if success_count == len(tests_to_run):
        print("🎉 All tests passed! The modular architecture is working correctly.")
        return 0
    else:
        print("⚠️ Some tests failed. Please check the output above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())