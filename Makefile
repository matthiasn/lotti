OS := $(shell uname -s)
FLUTTER_CMD :=

ifeq ($(OS), Darwin)
	FLUTTER_CMD := fvm flutter
else
	FLUTTER_CMD := flutter
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
	dart run test/tool/analyze_test_timings.dart reports/tests.json $(THRESH)

.PHONY: junit_upload
junit_upload:
	dart pub global activate junitreport
	dart pub global run junitreport:tojunit --input TEST-report.jsonl --output junit.xml
	./.buildkite/junit_upload.sh

.PHONY: integration_test
integration_test:
	 flutter test integration_test

.PHONY: clean
clean:
	$(FLUTTER_CMD) clean

.PHONY: deps
deps:
	$(FLUTTER_CMD) pub get

.PHONY: enable_arb_tools
enable_arb_tools:
	dart pub global activate arb_utils

.PHONY: sort_arb_files
sort_arb_files: enable_arb_tools
	find lib/l10n/ -type f -exec dart pub global run arb_utils:sort -i {} \;

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
	dart run build_runner build --delete-conflicting-outputs

.PHONY: watch
watch: l10n
	dart run build_runner watch --delete-conflicting-outputs

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
	dart run flutter_native_splash:create

.PHONY: icons
icons:
	dart run flutter_launcher_icons:main

.PHONY: clean_test
clean_test: clean deps build_runner l10n test
