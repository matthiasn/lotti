IOS_ARCHIVE_PATH = ./build/ios/archive/Runner.xcarchive
IOS_EXPORT_PATH = ./build/ios/export
MACOS_ARCHIVE_PATH = ./build/macos/archive/Runner.xcarchive
MACOS_EXPORT_PATH = ./build/macos/export
LOTTI_VERSION := $(shell yq '.version' pubspec.yaml |  tr -d '"')

.PHONY: test
test:
	flutter test --coverage

.PHONY: junit
junit:
	flutter test --coverage --reporter json > TEST-report.jsonl
	dart pub global activate junitreport
	dart pub global run junitreport:tojunit --input TEST-report.jsonl --output junit.xml
	./.buildkite/junit_upload.sh

.PHONY: integration_test
integration_test:
	 flutter test integration_test

.PHONY: clean
clean:
	flutter clean

.PHONY: deps
deps:
	flutter pub get

.PHONY: enable_arb_tools
enable_arb_tools:
	dart pub global activate arb_utils

.PHONY: sort_arb_files
sort_arb_files: enable_arb_tools
	find lib/l10n/ -type f -exec dart pub global run arb_utils:sort -i {} \;

.PHONY: l10n
l10n: sort_arb_files
	flutter gen-l10n
	@echo "Missing translations:"
	@cat missing_translations.txt

.PHONY: doctor
doctor:
	flutter doctor

.PHONY: coverage_report
coverage_report:
	lcov --remove coverage/lcov.info 'lib/classes/*.g.dart' 'lib/database/*.g.dart' 'lib/routes/router.gr.dart' -o coverage/new_lcov.info
	genhtml coverage/new_lcov.info -o coverage --no-function-coverage
	open coverage/index.html

.PHONY: coverage
coverage: test coverage_report

.PHONY: check-null-safety
check-null-safety:
	flutter pub outdated --mode=null-safety

.PHONY: build_runner
build_runner: l10n
	flutter pub run build_runner build --delete-conflicting-outputs

.PHONY: watch
watch: l10n
	flutter pub run build_runner watch --delete-conflicting-outputs

.PHONY: migrate_db
migrate_db:
	@dart pub get
	@echo "Running database migration..."
	@tput setaf 1
	@echo "Rename drift_schema_v_REPLACE_ME.json when done!!!"
	@tput sgr0
	dart run drift_dev schema dump lib/database/database.dart drift_schemas/drift_schema_v_REPLACE_ME.json

.PHONY: bundle
bundle:
	flutter build bundle

#######################################

.PHONY: ios_build_ipa
ios_build_ipa:
	flutter build ipa

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
	flutter build macos

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
	flutter build appbundle

.PHONY: linux_build
linux_build:
	flutter build linux

.PHONY: linux
linux: clean_test linux_build

.PHONY: windows
windows: clean_test
	flutter build windows

.PHONY: tag_push
tag_push:
	git tag ${LOTTI_VERSION}
	git push origin ${LOTTI_VERSION}

.PHONY: all
all: ios macos

.PHONY: find_unused
find_unused:
	flutter pub run dart_code_metrics:metrics check-unused-files lib

.PHONY: sentry_symbols
sentry_symbols:
	flutter packages pub run sentry_dart_plugin

.PHONY: splash
splash:
	flutter pub run flutter_native_splash:create

.PHONY: icons
icons:
	flutter pub run flutter_launcher_icons:main

.PHONY: viz
viz:
	dart pub global run dcdg -o classes.viz.puml -s lib/classes/
	PLANTUML_LIMIT_SIZE=12000 plantuml classes.viz.puml
	open classes.viz.png

.PHONY: clean_test
clean_test: clean deps l10n build_runner test

.PHONY: clean_integration_test
clean_integration_test: clean deps build_runner integration_test
