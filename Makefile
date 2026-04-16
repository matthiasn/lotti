OS := $(shell uname -s)
FLUTTER_CMD :=
DART_CMD :=

ifeq ($(OS), Darwin)
	FLUTTER_CMD := fvm flutter
	DART_CMD := fvm dart
else
	FLUTTER_CMD := flutter
	DART_CMD := dart
endif

IOS_ARCHIVE_PATH = ./build/ios/archive/Runner.xcarchive
IOS_EXPORT_PATH = ./build/ios/export
MACOS_ARCHIVE_PATH = ./build/macos/archive/Runner.xcarchive
MACOS_EXPORT_PATH = ./build/macos/export
LOTTI_VERSION := $(shell yq '.version' pubspec.yaml |  tr -d '"')
THRESH ?= 1000

.PHONY: test
test:
	$(FLUTTER_CMD) test --coverage

.PHONY: analyze
analyze:
	$(FLUTTER_CMD) analyze

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
	 $(FLUTTER_CMD) test integration_test

.PHONY: clean
clean:
	$(FLUTTER_CMD) clean

.PHONY: deps
deps:
	$(FLUTTER_CMD) pub get

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

.PHONY: fluttium_linux
fluttium_linux:
	fluttium test test_flows/habit_flow.yaml --reporter expanded

.PHONY: fluttium_production
fluttium_production:
	fluttium test test_flows/habit_flow.yaml --flavor production --target lib/main.dart

.PHONY: fluttium_docs
fluttium_docs:
	mkdir -p ~/github/lotti-docs/images/${LOTTI_VERSION}
	cp ./screenshots/* ~/github/lotti-docs/images/${LOTTI_VERSION}/
	cd ~/github/lotti-docs/ && git pull && git add . && git commit -m ${LOTTI_VERSION} && git push

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
	  echo "--- real FD count (excludes cwd/rtd/txt/mem) ---"; \
	  lsof -p "$$PID_VAL" | awk 'NR>1 && $$4 ~ /^[0-9]+[rwu]?$$/' | wc -l | awk '{print "total_real_fds="$$1}'; \
	  echo "--- grouped by type ---"; \
	  lsof -p "$$PID_VAL" | awk 'NR>1 && $$4 ~ /^[0-9]+[rwu]?$$/ {print $$5}' | sort | uniq -c | sort -rn; \
	} | tee "$$OUT"; \
	echo ""; \
	echo "Saved to $$OUT"
