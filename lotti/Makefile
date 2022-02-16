.PHONY: test
test:
	flutter test --coverage

.PHONY: integration_test
integration_test:
	 flutter test integration_test

.PHONY: clean
clean:
	flutter clean

.PHONY: deps
deps:
	flutter pub get

.PHONY: doctor
doctor:
	flutter doctor

.PHONY: coverage
coverage: test
	genhtml coverage/lcov.info -o coverage
	open coverage/index.html

.PHONY: check-null-safety
check-null-safety:
	flutter pub outdated --mode=null-safety

.PHONY: build_runner
build_runner:
	flutter pub run build_runner build --delete-conflicting-outputs

.PHONY: watch
watch:
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

.PHONY: ipa
ipa: clean_test
	flutter build ipa
	open ./build/ios/archive/Runner.xcarchive

.PHONY: macos
macos: clean_test
	flutter build macos
	open ./build/macos/Build/Products/Release/

.PHONY: linux
linux: clean_test
	flutter build linux

.PHONY: windows
windows: clean_test
	flutter build windows

.PHONY: all
all: ipa macos

.PHONY: find_unused
find_unused:
	flutter pub run dart_code_metrics:metrics check-unused-files lib

.PHONY: sentry_symbols
sentry_symbols:
	flutter packages pub run sentry_dart_plugin

.PHONY: splash
splash:
	flutter pub run flutter_native_splash:create

.PHONY: viz
viz:
	dart pub global run dcdg -o classes.viz.puml -s lib/classes/
	PLANTUML_LIMIT_SIZE=12000 plantuml classes.viz.puml
	open classes.viz.png

.PHONY: clean_test
clean_test: clean deps build_runner test

.PHONY: clean_integration_test
clean_integration_test: clean deps build_runner integration_test
