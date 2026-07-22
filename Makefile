OS := $(shell uname -s)
FLUTTER_CMD :=
DART_CMD :=
VERY_GOOD_CMD :=

ifeq ($(OS), Darwin)
	FLUTTER_CMD := fvm flutter
	DART_CMD := fvm dart
	VERY_GOOD_CMD := fvm dart pub global run very_good_cli:very_good
else
	FLUTTER_CMD := flutter
	DART_CMD := dart
	VERY_GOOD_CMD := dart pub global run very_good_cli:very_good
endif

IOS_ARCHIVE_PATH = ./build/ios/archive/Runner.xcarchive
IOS_EXPORT_PATH = ./build/ios/export
MACOS_ARCHIVE_PATH = ./build/macos/archive/Runner.xcarchive
MACOS_EXPORT_PATH = ./build/macos/export
LOTTI_VERSION := $(shell yq '.version' pubspec.yaml |  tr -d '"')
THRESH ?= 1000
LOTTI_DOCS_DIR ?= $(abspath ../lotti-docs)
MANUAL_VERSION ?= development
MANUAL_LOCALES ?= en de fr it es cs nl ro pt da sv
MANUAL_CAPTURE_DIR ?= $(LOTTI_DOCS_DIR)/manual/.staging/$(MANUAL_VERSION)
MANUAL_MEDIA_DIR ?= $(LOTTI_DOCS_DIR)/manual/screenshots

.PHONY: test
test:
	$(VERY_GOOD_CMD) test --coverage

.PHONY: test_standard
test_standard:
	rm -rf coverage
	$(VERY_GOOD_CMD) test --coverage --exclude-tags glados

.PHONY: test_glados
test_glados:
	rm -rf coverage
	$(VERY_GOOD_CMD) test --coverage --tags glados

.PHONY: analyze
analyze:
	FLUTTER="$(FLUTTER_CMD)" DART="$(DART_CMD)" ./tool/analyze.sh

.PHONY: junit_test
junit_test:
	$(FLUTTER_CMD) test --coverage --reporter json > TEST-report.jsonl

.PHONY: slow_boundaries
slow_boundaries: deps
	@mkdir -p reports
	$(FLUTTER_CMD) test -r json --file-reporter json:reports/tests.json
	$(DART_CMD) run test/tool/analyze_test_timings.dart reports/tests.json $(THRESH)

.PHONY: junit_upload
junit_upload:
	$(DART_CMD) pub global activate junitreport
	$(DART_CMD) pub global run junitreport:tojunit --input TEST-report.jsonl --output junit.xml
	./.buildkite/junit_upload.sh

.PHONY: integration_test
integration_test:
	 $(FLUTTER_CMD) test integration_test --exclude-tags tutorial-video

.PHONY: clean
clean:
	$(FLUTTER_CMD) clean

.PHONY: deps
deps:
	$(FLUTTER_CMD) pub get

.PHONY: check_flatpak_foreign_deps
check_flatpak_foreign_deps: deps
	python3 flatpak/check_foreign_deps.py

.PHONY: sort_arb_files
sort_arb_files:
	find lib/l10n/ -type f -name '*.arb' -exec $(DART_CMD) run arb_utils sort -i {} \;

.PHONY: l10n
l10n: deps
	$(FLUTTER_CMD) gen-l10n
	@echo "Missing translations:"
	@cat missing_translations.txt

.PHONY: doctor
doctor:
	$(FLUTTER_CMD) doctor

.PHONY: coverage_report
coverage_report:
	lcov --remove coverage/lcov.info 'lib/classes/*.g.dart' 'lib/database/*.g.dart' 'lib/l10n/*.dart' -o coverage/new_lcov.info
	genhtml coverage/new_lcov.info -o coverage --no-function-coverage
	open coverage/index.html

.PHONY: coverage
coverage: test coverage_report

.PHONY: coverage_standard
coverage_standard: test_standard coverage_report

.PHONY: coverage_glados
coverage_glados: test_glados coverage_report

.PHONY: build_runner
build_runner: deps
	$(DART_CMD) run build_runner build --delete-conflicting-outputs

.PHONY: design_system_import
design_system_import: deps
	$(DART_CMD) run tool/design_system/generate_tokens.dart
	$(DART_CMD) format lib/features/design_system/theme/generated/design_tokens.g.dart

.PHONY: watch
watch: l10n
	$(DART_CMD) run build_runner watch --delete-conflicting-outputs

.PHONY: activate_fluttium
activate_fluttium:
	$(FLUTTER_CMD) pub global activate fluttium_cli

.PHONY: activate_very_good
activate_very_good:
	$(DART_CMD) pub global activate very_good_cli

.PHONY: fluttium_linux
fluttium_linux:
	fluttium test test_flows/habit_flow.yaml --reporter expanded

.PHONY: fluttium_production
fluttium_production:
	fluttium test test_flows/habit_flow.yaml --flavor production --target lib/main.dart

.PHONY: fluttium_docs
fluttium_docs: manual_screenshots
	@echo "fluttium_docs is deprecated; generated manual media is ready in $(MANUAL_MEDIA_DIR)."

.PHONY: manual_deps
manual_deps:
	npm --prefix docs-site ci

.PHONY: manual_start
manual_start:
	npm --prefix docs-site start

.PHONY: manual_build
manual_build:
	npm --prefix docs-site run build

.PHONY: manual_serve
manual_serve:
	npm --prefix docs-site run serve

.PHONY: manual_check
manual_check:
	npm --prefix docs-site run check

.PHONY: manual_check_media
manual_check_media:
	npm --prefix docs-site run validate -- --media-root "$(MANUAL_MEDIA_DIR)" --version "$(MANUAL_VERSION)"

.PHONY: manual_screenshots
manual_screenshots: manual_deps
	@set -e; for locale in $(MANUAL_LOCALES); do \
		$(MAKE) manual_screenshots_locale \
			MANUAL_LOCALE="$$locale" \
			MANUAL_CAPTURE_DIR="$(MANUAL_CAPTURE_DIR)/$$locale"; \
	done
	npm --prefix docs-site run manifest -- --capture-dir "$(MANUAL_CAPTURE_DIR)" --output-root "$(MANUAL_MEDIA_DIR)" --version "$(MANUAL_VERSION)" --locales "$(MANUAL_LOCALES)"
	$(MAKE) manual_check_media MANUAL_VERSION="$(MANUAL_VERSION)" LOTTI_DOCS_DIR="$(LOTTI_DOCS_DIR)"

.PHONY: manual_screenshots_locale
manual_screenshots_locale:
	mkdir -p "$(MANUAL_CAPTURE_DIR)"
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/settings/ui/settings_home_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/daily_os_next/ui/pages/day_planning_modal_screenshots_test.dart --name '^(mini|desktop) (capture captured|captured|reconcile) — (dark|light)$$'
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/daily_os_next/ui/pages/day_page_screenshots_test.dart --name '^((mini|desktop) (agenda|timeline)|(pro|desktop) timeline arrange mode) — (dark|light)$$'
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/daily_os_next/ui/pages/day_page_screenshots_test.dart --name '^manual daily OS'
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/daily_os_next/ui/pages/daily_os_settings_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/settings/ui/settings_definitions_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/pages/create/create_measurement_dialog_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/settings/ui/settings_preferences_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/tasks/ui/widgets/task_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/projects/ui/pages/projects_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/events/ui/pages/events_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/journal/ui/pages/journal_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/insights/ui/time_analysis_screenshots_test.dart --name 'manual'
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/habits/ui/habits_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/speech/ui/widgets/recording/audio_recording_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/settings/ui/settings_advanced_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/whats_new/ui/whats_new_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/onboarding/ui/onboarding_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/ai/ui/settings/ai_settings_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/agents/ui/agents_manual_screenshots_test.dart
	LOTTI_MANUAL_LOCALE="$(MANUAL_LOCALE)" LOTTI_SCREENSHOT_DIR="$(MANUAL_CAPTURE_DIR)" fvm flutter test test/features/sync/ui/sync_manual_screenshots_test.dart

.PHONY: manual_screenshots_macos
manual_screenshots_macos:
	mkdir -p "$(LOTTI_DOCS_DIR)/manual/legacy/${LOTTI_VERSION}/macos"
	LOTTI_SCREENSHOT_DIR="$(LOTTI_DOCS_DIR)/manual/legacy/${LOTTI_VERSION}/macos" fvm flutter drive -d macos --driver=test_driver/manual_screenshots_driver.dart --target=integration_test/manual_screenshots_test.dart --dart-define=LOTTI_SCREENSHOT_DIR="$(LOTTI_DOCS_DIR)/manual/legacy/${LOTTI_VERSION}/macos"

.PHONY: manual_screenshots_linux
manual_screenshots_linux:
	mkdir -p "$(LOTTI_DOCS_DIR)/manual/legacy/${LOTTI_VERSION}/linux"
	LOTTI_SCREENSHOT_DIR="$(LOTTI_DOCS_DIR)/manual/legacy/${LOTTI_VERSION}/linux" fvm flutter drive -d linux --driver=test_driver/manual_screenshots_driver.dart --target=integration_test/manual_screenshots_test.dart --dart-define=LOTTI_SCREENSHOT_DIR="$(LOTTI_DOCS_DIR)/manual/legacy/${LOTTI_VERSION}/linux"

.PHONY: bundle
bundle:
	$(FLUTTER_CMD) build bundle

.PHONY: widgetbook_macos_build
widgetbook_macos_build:
	bash tool/widgetbook/build_macos_bundle.sh

.PHONY: widgetbook_macos_upload
widgetbook_macos_upload:
	bash tool/widgetbook/build_macos_bundle.sh --skip-build --upload-release

.PHONY: widgetbook_macos_publish
widgetbook_macos_publish:
	bash tool/widgetbook/build_macos_bundle.sh --upload-release

#######################################

.PHONY: ios_build_ipa
ios_build_ipa:
	$(FLUTTER_CMD) build ipa

.PHONY: ios_build
ios_build: clean_test ios_build_ipa

.PHONY: ios_fastlane_beta
ios_fastlane_beta:
	cd ios && fastlane beta && cd ..

.PHONY: ios_fastlane_build
ios_fastlane_build:
	cd ios && fastlane do_build && cd ..

.PHONY: ios_fastlane_upload
ios_fastlane_upload:
	cd ios && fastlane do_upload && cd ..

.PHONY: ios_fastlane_match
ios_fastlane_match:
	cd ios && fastlane match --generate_apple_certs false && cd ..

.PHONY: ios_open
ios_open:
	open $(IOS_ARCHIVE_PATH)

.PHONY: ipa
ipa: ios_build
	xcodebuild -exportArchive -archivePath $(IOS_ARCHIVE_PATH) \
               -exportOptionsPlist ./ios/Runner/exportOptions.plist \
               -exportPath $(IOS_EXPORT_PATH) \
               -allowProvisioningUpdates

.PHONY: ios_upload
ios_upload:
	@xcrun altool --upload-app --type ios -f $(IOS_EXPORT_PATH)/Lotti.ipa \
                  -u $(APPLEID) -p $(LOTTI_APPSTORE_CONNECT)

.PHONY: ios
ios: ios_build ios_fastlane_build ios_fastlane_upload

.PHONY: macos_build_flutter
macos_build_flutter:
	$(FLUTTER_CMD) build macos

.PHONY: releases
releases: android_build_release macos_build_flutter ios_build_ipa

.PHONY: macos_build
macos_build: clean_test macos_build_flutter

.PHONY: macos_archive
macos_archive:
	xcodebuild -workspace ./macos/Runner.xcworkspace \
               -config Release -scheme Runner \
               -archivePath $(MACOS_ARCHIVE_PATH) archive

.PHONY: macos_pkg
macos_pkg:
	xcodebuild -exportArchive -archivePath $(MACOS_ARCHIVE_PATH) \
               -exportOptionsPlist ./macos/Runner/exportOptions.plist \
               -exportPath $(MACOS_EXPORT_PATH) \
               -allowProvisioningUpdates

.PHONY: macos_upload
macos_upload:
	@xcrun altool --upload-app --type macos -f $(MACOS_EXPORT_PATH)/Lotti.pkg \
                  -u $(APPLEID) -p $(LOTTI_APPSTORE_CONNECT)

.PHONY: macos_open
macos_open: macos_build macos_archive
	open $(MACOS_ARCHIVE_PATH)

.PHONY: macos_fastlane_build
macos_fastlane_build:
	cd macos && fastlane do_build && cd ..

.PHONY: macos_fastlane_upload
macos_fastlane_upload:
	cd macos && fastlane do_upload && cd ..

.PHONY: macos_fastlane_match
macos_fastlane_match:
	cd macos && fastlane match --generate_apple_certs false && cd ..

.PHONY: macos_fastlane_export
macos_fastlane_export:
	cd macos && fastlane do_package && cd ..

.PHONY: macos
macos: macos_build macos_fastlane_build macos_fastlane_upload macos_fastlane_export

.PHONY: macos_export
macos_export: macos_build macos_fastlane_export

.PHONY: macos_testflight_cli
macos_testflight_cli: macos_build macos_archive macos_pkg macos_upload

.PHONY: macos_cli
macos_cli: macos_build macos_archive macos_pkg macos_upload

.PHONY: macos_local
macos_local: macos_build
	open ./build/macos/Build/Products/Release/

.PHONY: android_build
android_build:
	$(FLUTTER_CMD) build appbundle

.PHONY: android_build_release
android_build_release:
	$(FLUTTER_CMD) build appbundle --release

.PHONY: linux_build
linux_build:
	$(FLUTTER_CMD) build linux

.PHONY: linux
linux: l10n test linux_build

.PHONY: windows
windows: clean_test
	$(FLUTTER_CMD) build windows

.PHONY: tag_push
tag_push:
	git tag ${LOTTI_VERSION}
	git push origin ${LOTTI_VERSION}

.PHONY: all
all: ios macos

.PHONY: splash
splash:
	$(DART_CMD) run flutter_native_splash:create

.PHONY: icons
icons:
	dart run flutter_launcher_icons:main

.PHONY: clean_test
clean_test: clean deps build_runner l10n test

# Capture a file descriptor diagnostic snapshot of the running Lotti process.
# Writes to tmp/fd/fd-<timestamp>.txt and prints to stdout. Compare snapshots
# over time to spot monotonic FD growth (a leak) vs a stable working set.
# Override the PID if auto-detection picks the wrong process:
#   make fd_snapshot PID=12345
.PHONY: fd_snapshot
fd_snapshot:
	@mkdir -p tmp/fd
	@PID_VAL="$${PID:-}"; \
	if [ -z "$$PID_VAL" ]; then PID_VAL=$$(pgrep -x Lotti 2>/dev/null | head -n1); fi; \
	if [ -z "$$PID_VAL" ]; then PID_VAL=$$(pgrep -x lotti 2>/dev/null | head -n1); fi; \
	if [ -z "$$PID_VAL" ]; then \
	  echo "No running Lotti process found."; \
	  echo "Launch Lotti, or pass an explicit PID: make fd_snapshot PID=<pid>"; \
	  exit 1; \
	fi; \
	TS=$$(date +%Y-%m-%d-%H%M%S); \
	OUT="tmp/fd/fd-$$TS.txt"; \
	{ \
	  echo "=== Lotti FD snapshot $$TS pid=$$PID_VAL ==="; \
	  if command -v launchctl >/dev/null 2>&1; then \
	    echo "--- launchctl limit maxfiles ---"; \
	    launchctl limit maxfiles 2>/dev/null || true; \
	  fi; \
	  if command -v sysctl >/dev/null 2>&1; then \
	    echo "--- sysctl ---"; \
	    sysctl kern.maxfiles kern.maxfilesperproc 2>/dev/null || true; \
	  fi; \
	  if [ -r "/proc/$$PID_VAL/limits" ]; then \
	    echo "--- /proc/$$PID_VAL/limits (Max open files) ---"; \
	    grep "Max open files" "/proc/$$PID_VAL/limits" || true; \
	  fi; \
	  LSOF_TMP=$$(mktemp -t lotti-fd-snapshot 2>/dev/null || mktemp); \
	  lsof -p "$$PID_VAL" >"$$LSOF_TMP" 2>/dev/null || true; \
	  echo "--- real FD count (excludes cwd/rtd/txt/mem) ---"; \
	  awk 'NR>1 && $$4 ~ /^[0-9]+[A-Za-z]*$$/' "$$LSOF_TMP" | wc -l | awk '{print "total_real_fds="$$1}'; \
	  echo "--- grouped by type ---"; \
	  awk 'NR>1 && $$4 ~ /^[0-9]+[A-Za-z]*$$/ {print $$5}' "$$LSOF_TMP" | sort | uniq -c | sort -rn; \
	  rm -f "$$LSOF_TMP"; \
	} | tee "$$OUT"; \
	echo ""; \
	echo "Saved to $$OUT"

# --- Tutorial videos (tools/tutorial_videos) --------------------------------
# Full pipeline for one locale: TTS pre-pass -> real app under Xvfb driven by
# flutter drive (virtual mic + screen capture) -> OpenMontage composition.
# Requires: .env with GEMINI_API_KEY/MELIOUS_API_KEY/MELIOUS_BASE_URL, and a
# pinned ../OpenMontage checkout (see tools/tutorial_videos/config/openmontage.pin).
TUTORIAL_SCENARIO ?= create_task_from_audio
TUTORIAL_LOCALE ?= en
TUTORIAL_LOCALES ?= en de

.PHONY: tutorial_video
tutorial_video:
	cd tools/tutorial_videos && python3 -m tutorial_videos build \
	  --scenario $(TUTORIAL_SCENARIO) --locale $(TUTORIAL_LOCALE)

.PHONY: tutorial_videos_all
tutorial_videos_all:
	for locale in $(TUTORIAL_LOCALES); do \
	  $(MAKE) tutorial_video TUTORIAL_LOCALE=$$locale || exit 1; \
	done

# Uploads an already-built MP4 to Cloudflare R2 and prints its public URL.
# Requires .env with R2_ACCOUNT_ID/R2_ACCESS_KEY_ID/R2_SECRET_ACCESS_KEY/
# R2_BUCKET_NAME/R2_PUBLIC_BASE_URL, and `pip install boto3`.
.PHONY: tutorial_video_publish
tutorial_video_publish:
	cd tools/tutorial_videos && python3 -m tutorial_videos publish \
	  --scenario $(TUTORIAL_SCENARIO) --locale $(TUTORIAL_LOCALE)
